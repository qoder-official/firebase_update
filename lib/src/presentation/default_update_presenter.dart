import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/material.dart';

import '../config/firebase_update_config.dart';
import '../models/firebase_update_kind.dart';
import '../models/firebase_update_patch_notes_format.dart';
import '../models/firebase_update_state.dart';
import '../services/store_launcher.dart';
import 'firebase_update_presentation.dart';

class DefaultUpdatePresenter {
  DefaultUpdatePresenter({required StoreLauncher storeLauncher})
    : _storeLauncher = storeLauncher;

  final StoreLauncher _storeLauncher;
  FirebaseUpdateKind? _presentedKind;
  String? _skippedVersion;

  // ---------------------------------------------------------------------------
  // Concurrency guards
  // ---------------------------------------------------------------------------

  // Incremented each time presentation ownership changes (new state committed,
  // upToDate dismisses, reset called).  Any callback or Future that was
  // scheduled under an older generation silently aborts, preventing stale
  // operations from acting on superseded state — the core fix for rapid-fire
  // state bursts where multiple RC updates arrive before a frame is rendered.
  int _generation = 0;

  // True only while a dialog / sheet is actually on the navigator route stack.
  // Starts as true immediately before showDialog / showGeneralDialog is awaited
  // (the route is pushed synchronously by those calls before the first yield),
  // and is set back to false once the overlay Future resolves.
  //
  // Used to decide whether a forced pop() is safe: a pop() on a navigator that
  // holds only the app's main route would exit the app, so we only pop when
  // _isPresenting confirms that an overlay route is actually in the stack.
  bool _isPresenting = false;

  /// Clears all presenter-held state. Called on [FirebaseUpdate.initialize]
  /// and [FirebaseUpdate.debugReset] so each initialization cycle starts clean.
  void reset() {
    _generation++;
    _presentedKind = null;
    _isPresenting = false;
    _skippedVersion = null;
  }

  void presentIfNeeded({
    required FirebaseUpdateState state,
    required FirebaseUpdateConfig config,
    required GlobalKey<NavigatorState>? navigatorKey,
  }) {
    if (!config.enableDefaultPresentation || navigatorKey == null) {
      return;
    }

    if (state.kind == FirebaseUpdateKind.idle ||
        state.kind == FirebaseUpdateKind.upToDate) {
      if (state.kind == FirebaseUpdateKind.upToDate) {
        _generation++;
        _skippedVersion = null;
        // Dismiss any active overlay so the app returns to a usable state
        // when the server signals that no update or maintenance is needed.
        if (_isPresenting) {
          // The overlay is actually on the navigator — pop it.
          // pop() (not maybePop) is required because force-update and
          // maintenance dialogs use PopScope(canPop: false) and are
          // intentionally non-user-dismissable; only the presenter may
          // programmatically close them.
          _isPresenting = false;
          _presentedKind = null;
          final context =
              navigatorKey.currentContext ?? navigatorKey.currentState?.context;
          if (context != null) {
            Navigator.of(context, rootNavigator: true).pop();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final lateContext =
                  navigatorKey.currentContext ??
                  navigatorKey.currentState?.context;
              if (lateContext != null) {
                Navigator.of(lateContext, rootNavigator: true).pop();
              }
            });
          }
        } else {
          // Overlay was scheduled (Future pending) but not yet on screen —
          // the generation bump above is enough to cancel it.
          _presentedKind = null;
        }
      }
      return;
    }

    // Clear skip if a newer version is now being offered.
    if (state.kind == FirebaseUpdateKind.optionalUpdate &&
        _skippedVersion != null &&
        state.latestVersion != null &&
        state.latestVersion != _skippedVersion) {
      _skippedVersion = null;
    }

    // Suppress presentation if the user already dismissed this specific version.
    if (state.kind == FirebaseUpdateKind.optionalUpdate &&
        state.latestVersion != null &&
        state.latestVersion == _skippedVersion) {
      return;
    }

    if (_presentedKind == state.kind) {
      return;
    }

    final context =
        navigatorKey.currentContext ?? navigatorKey.currentState?.context;
    if (context == null) {
      // Navigator not ready yet — defer to the next frame.
      // The generation is NOT bumped here because no presentation has been
      // committed; the callback will re-enter and commit on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        presentIfNeeded(
          state: state,
          config: config,
          navigatorKey: navigatorKey,
        );
      });
      return;
    }

    if (_presentedKind != null) {
      if (_isPresenting) {
        // An overlay is actually on the navigator — pop it so the new one
        // can take its place.  pop() is intentional: see the upToDate branch
        // above for the rationale.
        Navigator.of(context, rootNavigator: true).pop();
        _isPresenting = false;
      }
      // Cancel the old scheduled Future (if it hasn't run yet) or prevent
      // the old overlay's completion logic from interfering.
      _generation++;
      _presentedKind = null;
      final gen = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_generation != gen) return; // superseded while waiting for frame
        presentIfNeeded(
          state: state,
          config: config,
          navigatorKey: navigatorKey,
        );
      });
      return;
    }

    // Commit this state as the sole active presentation.
    _generation++;
    _presentedKind = state.kind;
    final gen = _generation;
    unawaited(
      Future<void>(() async {
        // Abort if the context is gone or a newer state has taken over since
        // this Future was scheduled.
        if (!context.mounted || _generation != gen) {
          if (_generation == gen) _presentedKind = null;
          return;
        }

        // Mark the overlay as live.  showDialog / showGeneralDialog push the
        // route synchronously before their first internal yield, so by the time
        // any concurrent presentIfNeeded call runs, _isPresenting is already
        // true and the navigator has the overlay in its stack.
        _isPresenting = true;
        switch (state.kind) {
          case FirebaseUpdateKind.optionalUpdate:
            await _presentOptionalUpdate(context, state, config);
            break;
          case FirebaseUpdateKind.forceUpdate:
            await _presentForceUpdate(context, state, config);
            break;
          case FirebaseUpdateKind.maintenance:
            await _presentMaintenance(context, state, config);
            break;
          case FirebaseUpdateKind.idle:
          case FirebaseUpdateKind.upToDate:
            break;
        }
        _isPresenting = false;
      }),
    );
  }

  Future<void> _presentOptionalUpdate(
    BuildContext context,
    FirebaseUpdateState state,
    FirebaseUpdateConfig config,
  ) async {
    final versionBeingOffered = state.latestVersion;
    bool userSkipped = false;

    final labels = config.presentation.labels;
    final data = FirebaseUpdatePresentationData(
      title: state.title ?? labels.optionalUpdateTitle ?? 'Update available',
      state: state,
      isBlocking: false,
      primaryLabel: labels.updateNow ?? 'Update now',
      secondaryLabel: labels.later ?? 'Later',
      onPrimaryTap: () => _launchStore(
        context,
        packageName: config.packageName,
        fallbackUrl: _resolveStoreUrl(config),
      ),
    );

    if (config.resolvesOptionalUpdateAsBottomSheet) {
      await _showOptionalBottomSheet(
        context: context,
        config: config,
        data: data,
        onSkip: () {
          userSkipped = true;
        },
      );
    } else {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierColor: config.presentation.theme.barrierColor,
        builder: (dialogContext) {
          final dialogData = data.copyWith(
            onSecondaryTap: () {
              userSkipped = true;
              Navigator.of(dialogContext, rootNavigator: true).pop();
            },
          );
          return _BlurredModalWrapper(
            sigma: config.presentation.theme.dialogBackgroundBlurSigma,
            child:
                config.optionalUpdateWidget?.call(dialogContext, dialogData) ??
                _DefaultUpdateDialog(
                  data: dialogData,
                  theme: config.presentation.theme,
                  iconBuilder: config.presentation.iconBuilder,
                  alignment:
                      config.presentation.contentAlignment ??
                      FirebaseUpdateContentAlignment.center,
                  notesAlignment:
                      config.presentation.patchNotesAlignment ??
                      FirebaseUpdateContentAlignment.start,
                  typography: config.presentation.typography,
                  releaseNotesHeading:
                      config.presentation.labels.releaseNotesHeading ??
                      'Release notes',
                  readMoreLabel:
                      config.presentation.labels.readMore ?? 'Read more',
                  showLessLabel:
                      config.presentation.labels.showLess ?? 'Show less',
                ),
          );
        },
      );
    }

    if (userSkipped && versionBeingOffered != null) {
      _skippedVersion = versionBeingOffered;
    }
    _presentedKind = null;
  }

  Future<void> _presentForceUpdate(
    BuildContext context,
    FirebaseUpdateState state,
    FirebaseUpdateConfig config,
  ) async {
    final labels = config.presentation.labels;
    final data = FirebaseUpdatePresentationData(
      title: state.title ?? labels.forceUpdateTitle ?? 'Update required',
      state: state,
      isBlocking: true,
      primaryLabel: labels.updateNow ?? 'Update now',
      onPrimaryTap: () => _launchStore(
        context,
        packageName: config.packageName,
        fallbackUrl: _resolveStoreUrl(config),
      ),
    );

    if (config.useBottomSheetForForceUpdate) {
      await _showBlockingBottomSheet(
        context: context,
        config: config,
        data: data,
        customWidget: config.forceUpdateWidget,
      );
    } else {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: config.presentation.theme.barrierColor,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: _BlurredModalWrapper(
            sigma: config.presentation.theme.dialogBackgroundBlurSigma,
            child:
                config.forceUpdateWidget?.call(dialogContext, data) ??
                _DefaultUpdateDialog(
                  data: data,
                  theme: config.presentation.theme,
                  iconBuilder: config.presentation.iconBuilder,
                  alignment:
                      config.presentation.contentAlignment ??
                      FirebaseUpdateContentAlignment.center,
                  notesAlignment:
                      config.presentation.patchNotesAlignment ??
                      FirebaseUpdateContentAlignment.start,
                  typography: config.presentation.typography,
                  releaseNotesHeading:
                      config.presentation.labels.releaseNotesHeading ??
                      'Release notes',
                  readMoreLabel:
                      config.presentation.labels.readMore ?? 'Read more',
                  showLessLabel:
                      config.presentation.labels.showLess ?? 'Show less',
                ),
          ),
        ),
      );
    }

    _presentedKind = null;
  }

  Future<void> _showBlockingBottomSheet({
    required BuildContext context,
    required FirebaseUpdateConfig config,
    required FirebaseUpdatePresentationData data,
    required FirebaseUpdateViewBuilder? customWidget,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: config.presentation.theme.barrierColor ?? Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final child =
            customWidget?.call(dialogContext, data) ??
            _DefaultUpdateSheet(
              data: data,
              theme: config.presentation.theme,
              iconBuilder: config.presentation.iconBuilder,
              alignment:
                  config.presentation.contentAlignment ??
                  FirebaseUpdateContentAlignment.start,
              notesAlignment:
                  config.presentation.patchNotesAlignment ??
                  FirebaseUpdateContentAlignment.start,
              typography: config.presentation.typography,
              releaseNotesHeading:
                  config.presentation.labels.releaseNotesHeading ??
                  'Release notes',
              readMoreLabel:
                  config.presentation.labels.readMore ?? 'Read more',
              showLessLabel:
                  config.presentation.labels.showLess ?? 'Show less',
            );
        final blurSigma =
            config.presentation.theme.bottomSheetBackgroundBlurSigma ?? 0;

        return PopScope(
          canPop: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (blurSigma > 0)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blurSigma,
                        sigmaY: blurSigma,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Material(color: Colors.transparent, child: child)],
              ),
            ],
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _presentMaintenance(
    BuildContext context,
    FirebaseUpdateState state,
    FirebaseUpdateConfig config,
  ) async {
    final labels = config.presentation.labels;
    final data = FirebaseUpdatePresentationData(
      title:
          state.title ??
          state.maintenanceTitle ??
          labels.maintenanceTitle ??
          'Maintenance in progress',
      state: state,
      isBlocking: true,
      primaryLabel: labels.okay ?? 'Okay',
      onPrimaryTap: null,
    );

    if (config.useBottomSheetForMaintenance) {
      await _showBlockingBottomSheet(
        context: context,
        config: config,
        data: data,
        customWidget: config.maintenanceWidget,
      );
    } else {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: config.presentation.theme.barrierColor,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: _BlurredModalWrapper(
            sigma: config.presentation.theme.dialogBackgroundBlurSigma,
            child:
                config.maintenanceWidget?.call(dialogContext, data) ??
                _DefaultUpdateDialog(
                  data: data,
                  theme: config.presentation.theme,
                  iconBuilder: config.presentation.iconBuilder,
                  alignment:
                      config.presentation.contentAlignment ??
                      FirebaseUpdateContentAlignment.center,
                  notesAlignment:
                      config.presentation.patchNotesAlignment ??
                      FirebaseUpdateContentAlignment.start,
                  typography: config.presentation.typography,
                  releaseNotesHeading:
                      config.presentation.labels.releaseNotesHeading ??
                      'Release notes',
                  readMoreLabel:
                      config.presentation.labels.readMore ?? 'Read more',
                  showLessLabel:
                      config.presentation.labels.showLess ?? 'Show less',
                ),
          ),
        ),
      );
    }

    _presentedKind = null;
  }

  Future<void> _launchStore(
    BuildContext context, {
    String? packageName,
    String? fallbackUrl,
  }) async {
    final didLaunch = await _storeLauncher.launch(
      packageName: packageName,
      fallbackUrl: fallbackUrl,
    );
    if (!context.mounted) {
      return;
    }

    if (didLaunch) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Unable to open the update link right now.'),
      ),
    );
  }

  Future<void> _showOptionalBottomSheet({
    required BuildContext context,
    required FirebaseUpdateConfig config,
    required FirebaseUpdatePresentationData data,
    required VoidCallback onSkip,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: config.presentation.theme.barrierColor ?? Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final sheetData = data.copyWith(
          onSecondaryTap: () {
            onSkip();
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
        );
        final child =
            config.optionalUpdateWidget?.call(dialogContext, sheetData) ??
            _DefaultUpdateSheet(
              data: sheetData,
              theme: config.presentation.theme,
              iconBuilder: config.presentation.iconBuilder,
              alignment:
                  config.presentation.contentAlignment ??
                  FirebaseUpdateContentAlignment.start,
              notesAlignment:
                  config.presentation.patchNotesAlignment ??
                  FirebaseUpdateContentAlignment.start,
              typography: config.presentation.typography,
              releaseNotesHeading:
                  config.presentation.labels.releaseNotesHeading ??
                  'Release notes',
              readMoreLabel:
                  config.presentation.labels.readMore ?? 'Read more',
              showLessLabel:
                  config.presentation.labels.showLess ?? 'Show less',
            );
        final blurSigma =
            config.presentation.theme.bottomSheetBackgroundBlurSigma ?? 0;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (blurSigma > 0)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Material(color: Colors.transparent, child: child)],
            ),
          ],
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      },
    );
  }

  String? _resolveStoreUrl(FirebaseUpdateConfig config) {
    if (kIsWeb) return config.fallbackStoreUrls.web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return config.fallbackStoreUrls.android;
      case TargetPlatform.iOS:
        return config.fallbackStoreUrls.ios;
      case TargetPlatform.macOS:
        return config.fallbackStoreUrls.macos;
      case TargetPlatform.windows:
        return config.fallbackStoreUrls.windows;
      case TargetPlatform.linux:
        return config.fallbackStoreUrls.linux;
      case TargetPlatform.fuchsia:
        return null;
    }
  }
}

class _BlurredModalWrapper extends StatelessWidget {
  const _BlurredModalWrapper({required this.child, this.sigma});

  final Widget child;
  final double? sigma;

  @override
  Widget build(BuildContext context) {
    final blurSigma = sigma ?? 0;
    if (blurSigma <= 0) {
      return Center(child: child);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Center(child: child),
      ],
    );
  }
}

class _DefaultUpdateDialog extends StatelessWidget {
  const _DefaultUpdateDialog({
    required this.data,
    required this.theme,
    required this.alignment,
    required this.notesAlignment,
    required this.typography,
    required this.releaseNotesHeading,
    required this.readMoreLabel,
    required this.showLessLabel,
    this.iconBuilder,
  });

  final FirebaseUpdatePresentationData data;
  final FirebaseUpdatePresentationTheme theme;
  final FirebaseUpdateContentAlignment alignment;
  final FirebaseUpdateContentAlignment notesAlignment;
  final FirebaseUpdateTypography typography;
  final String releaseNotesHeading;
  final String readMoreLabel;
  final String showLessLabel;
  final FirebaseUpdateIconBuilder? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final visualTheme = _ResolvedPresentationTheme.from(context, theme);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: visualTheme.surfaceColor,
            borderRadius: theme.dialogBorderRadius,
            border: Border.all(color: visualTheme.outlineColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: theme.dialogBorderRadius,
            child: _DefaultUpdatePanel(
              data: data,
              theme: visualTheme,
              alignment: alignment,
              notesAlignment: notesAlignment,
              typography: typography,
              releaseNotesHeading: releaseNotesHeading,
              readMoreLabel: readMoreLabel,
              showLessLabel: showLessLabel,
              iconBuilder: iconBuilder,
              scrollable: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultUpdateSheet extends StatelessWidget {
  const _DefaultUpdateSheet({
    required this.data,
    required this.theme,
    required this.alignment,
    required this.notesAlignment,
    required this.typography,
    required this.releaseNotesHeading,
    required this.readMoreLabel,
    required this.showLessLabel,
    this.iconBuilder,
  });

  final FirebaseUpdatePresentationData data;
  final FirebaseUpdatePresentationTheme theme;
  final FirebaseUpdateContentAlignment alignment;
  final FirebaseUpdateContentAlignment notesAlignment;
  final FirebaseUpdateTypography typography;
  final String releaseNotesHeading;
  final String readMoreLabel;
  final String showLessLabel;
  final FirebaseUpdateIconBuilder? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final visualTheme = _ResolvedPresentationTheme.from(context, theme);
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.85),
        child: SizedBox(
          width: size.width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: visualTheme.surfaceColor,
              borderRadius: theme.sheetBorderRadius,
              border: Border.all(color: visualTheme.outlineColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: theme.sheetBorderRadius,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: visualTheme.outlineColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  _DefaultUpdatePanel(
                    data: data,
                    theme: visualTheme,
                    alignment: alignment,
                    notesAlignment: notesAlignment,
                    typography: typography,
                    releaseNotesHeading: releaseNotesHeading,
                    readMoreLabel: readMoreLabel,
                    showLessLabel: showLessLabel,
                    iconBuilder: iconBuilder,
                    scrollable: true,
                    extraBottomPadding: bottomInset,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultUpdatePanel extends StatelessWidget {
  const _DefaultUpdatePanel({
    required this.data,
    required this.theme,
    required this.alignment,
    required this.notesAlignment,
    required this.typography,
    required this.releaseNotesHeading,
    required this.readMoreLabel,
    required this.showLessLabel,
    this.iconBuilder,
    this.scrollable = false,
    this.extraBottomPadding = 0.0,
  });

  final FirebaseUpdatePresentationData data;
  final _ResolvedPresentationTheme theme;
  final FirebaseUpdateContentAlignment alignment;
  final FirebaseUpdateContentAlignment notesAlignment;
  final FirebaseUpdateTypography typography;
  final String releaseNotesHeading;
  final String readMoreLabel;
  final String showLessLabel;
  final FirebaseUpdateIconBuilder? iconBuilder;
  final bool scrollable;
  final double extraBottomPadding;

  Alignment get _iconAlignment {
    switch (alignment) {
      case FirebaseUpdateContentAlignment.start:
        return Alignment.centerLeft;
      case FirebaseUpdateContentAlignment.center:
        return Alignment.center;
      case FirebaseUpdateContentAlignment.end:
        return Alignment.centerRight;
    }
  }

  CrossAxisAlignment get _crossAxisAlignment {
    switch (alignment) {
      case FirebaseUpdateContentAlignment.start:
        return CrossAxisAlignment.start;
      case FirebaseUpdateContentAlignment.center:
        return CrossAxisAlignment.center;
      case FirebaseUpdateContentAlignment.end:
        return CrossAxisAlignment.end;
    }
  }

  TextAlign get _textAlign {
    switch (alignment) {
      case FirebaseUpdateContentAlignment.start:
        return TextAlign.start;
      case FirebaseUpdateContentAlignment.center:
        return TextAlign.center;
      case FirebaseUpdateContentAlignment.end:
        return TextAlign.end;
    }
  }

  CrossAxisAlignment get _notesAxisAlignment {
    switch (notesAlignment) {
      case FirebaseUpdateContentAlignment.start:
        return CrossAxisAlignment.start;
      case FirebaseUpdateContentAlignment.center:
        return CrossAxisAlignment.center;
      case FirebaseUpdateContentAlignment.end:
        return CrossAxisAlignment.end;
    }
  }

  TextAlign get _notesTextAlign {
    switch (notesAlignment) {
      case FirebaseUpdateContentAlignment.start:
        return TextAlign.start;
      case FirebaseUpdateContentAlignment.center:
        return TextAlign.center;
      case FirebaseUpdateContentAlignment.end:
        return TextAlign.end;
    }
  }

  Widget _buildContent(BuildContext context) {
    final state = data.state;
    final resolvedIcon = iconBuilder?.call(context, state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossAxisAlignment,
      children: [
        Align(
          alignment: _iconAlignment,
          child:
              resolvedIcon ??
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    state.kind == FirebaseUpdateKind.maintenance
                        ? Icons.construction_rounded
                        : Icons.system_update_alt_rounded,
                    color: theme.accentColor,
                  ),
                ),
              ),
        ),
        const SizedBox(height: 18),
        Text(
          data.title,
          textAlign: _textAlign,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: theme.contentColor,
            fontWeight: FontWeight.w800,
          ).merge(typography.titleStyle),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 10),
          Text(
            state.message!,
            textAlign: _textAlign,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: theme.contentColor.withValues(alpha: 0.86),
              height: 1.45,
            ).merge(typography.messageStyle),
          ),
        ],
        if (state.patchNotes != null && state.patchNotes!.isNotEmpty) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: _notesAxisAlignment,
              children: [
                Text(
                  releaseNotesHeading,
                  textAlign: _notesTextAlign,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: theme.contentColor,
                    fontWeight: FontWeight.w700,
                  ).merge(typography.releaseNotesHeadingStyle),
                ),
                const SizedBox(height: 8),
                _PatchNotesContent(
                  notes: state.patchNotes!,
                  format: state.patchNotesFormat,
                  alignment: notesAlignment,
                  readMoreLabel: readMoreLabel,
                  showLessLabel: showLessLabel,
                  readMoreColor: theme.accentColor,
                  readMoreStyleOverride: typography.readMoreStyle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.contentColor.withValues(alpha: 0.82),
                    height: 1.45,
                  ).merge(typography.patchNotesStyle),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (data.secondaryLabel != null && data.onSecondaryTap != null)
          Expanded(
            child: OutlinedButton(
              onPressed: data.onSecondaryTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.contentColor,
                side: BorderSide(color: theme.outlineColor),
                minimumSize: const Size.fromHeight(54),
                textStyle: typography.secondaryButtonStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(data.secondaryLabel!),
            ),
          ),
        if (data.secondaryLabel != null &&
            data.onSecondaryTap != null &&
            data.onPrimaryTap != null)
          const SizedBox(width: 12),
        if (data.onPrimaryTap != null)
          Expanded(
            child: FilledButton(
              onPressed: data.onPrimaryTap,
              style: FilledButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.accentForegroundColor,
                minimumSize: const Size.fromHeight(54),
                textStyle: typography.primaryButtonStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(data.primaryLabel),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (scrollable) {
      // Content scrolls; action buttons stay pinned at the bottom.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildContent(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: _buildActions(),
          ),
          if (extraBottomPadding > 0) SizedBox(height: extraBottomPadding),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: _crossAxisAlignment,
        children: [
          _buildContent(context),
          const SizedBox(height: 20),
          _buildActions(),
        ],
      ),
    );
  }
}

class _PatchNotesContent extends StatefulWidget {
  const _PatchNotesContent({
    required this.notes,
    required this.format,
    required this.alignment,
    this.style,
    this.readMoreColor,
    this.readMoreStyleOverride,
    this.readMoreLabel = 'Read more',
    this.showLessLabel = 'Show less',
  });

  final String notes;
  final FirebaseUpdatePatchNotesFormat format;
  final FirebaseUpdateContentAlignment alignment;
  final TextStyle? style;
  final Color? readMoreColor;

  /// Merged on top of the computed read-more base style (which is [style]
  /// with [readMoreColor] and semibold weight). Only non-null fields apply.
  final TextStyle? readMoreStyleOverride;

  final String readMoreLabel;
  final String showLessLabel;

  static const int _maxCollapsedLines = 5;
  static const double _htmlCollapsedMaxHeight = 120.0;

  @override
  State<_PatchNotesContent> createState() => _PatchNotesContentState();
}

class _PatchNotesContentState extends State<_PatchNotesContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle =
        widget.style ?? Theme.of(context).textTheme.bodyMedium;
    final readMoreStyle = resolvedStyle
        ?.copyWith(
          color: widget.readMoreColor ?? Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        )
        .merge(widget.readMoreStyleOverride);

    if (widget.format == FirebaseUpdatePatchNotesFormat.html) {
      return _buildHtml(resolvedStyle, readMoreStyle);
    }

    return _buildPlainText(resolvedStyle, readMoreStyle);
  }

  CrossAxisAlignment get _crossAxisAlignment {
    switch (widget.alignment) {
      case FirebaseUpdateContentAlignment.start:
        return CrossAxisAlignment.start;
      case FirebaseUpdateContentAlignment.center:
        return CrossAxisAlignment.center;
      case FirebaseUpdateContentAlignment.end:
        return CrossAxisAlignment.end;
    }
  }

  TextAlign get _textAlign {
    switch (widget.alignment) {
      case FirebaseUpdateContentAlignment.start:
        return TextAlign.start;
      case FirebaseUpdateContentAlignment.center:
        return TextAlign.center;
      case FirebaseUpdateContentAlignment.end:
        return TextAlign.end;
    }
  }

  Widget _buildPlainText(TextStyle? style, TextStyle? readMoreStyle) {
    final lines = widget.notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final needsToggle = lines.length > _PatchNotesContent._maxCollapsedLines;
    final visibleLines = (!_expanded && needsToggle)
        ? lines.take(_PatchNotesContent._maxCollapsedLines).toList()
        : lines;

    return Column(
      crossAxisAlignment: _crossAxisAlignment,
      children: [
        ...visibleLines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, textAlign: _textAlign, style: style),
          ),
        ),
        if (needsToggle)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? widget.showLessLabel : widget.readMoreLabel,
                style: readMoreStyle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHtml(TextStyle? style, TextStyle? readMoreStyle) {
    final htmlWidget = Html(
      data: widget.notes,
      style: {
        'html': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: style?.color,
          fontSize: style?.fontSize != null ? FontSize(style!.fontSize!) : null,
          lineHeight: style?.height != null ? LineHeight(style!.height!) : null,
          textAlign: TextAlign.start,
        ),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: style?.color,
          fontSize: style?.fontSize != null ? FontSize(style!.fontSize!) : null,
          lineHeight: style?.height != null ? LineHeight(style!.height!) : null,
          textAlign: TextAlign.start,
        ),
        'ul': Style(margin: Margins.zero, padding: HtmlPaddings.only(left: 18)),
        'ol': Style(margin: Margins.zero, padding: HtmlPaddings.only(left: 18)),
        'li': Style(
          margin: Margins.only(bottom: 6),
          padding: HtmlPaddings.zero,
          textAlign: TextAlign.start,
        ),
        'p': Style(
          margin: Margins.only(bottom: 6),
          padding: HtmlPaddings.zero,
          textAlign: TextAlign.start,
        ),
      },
    );

    // Use a character-count heuristic to decide if read-more is needed.
    // Strip tags to get an estimate of rendered content length.
    final strippedLength = widget.notes
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim()
        .length;
    final needsToggle = strippedLength > 280;

    if (!needsToggle) {
      return htmlWidget;
    }

    return Column(
      crossAxisAlignment: _crossAxisAlignment,
      children: [
        if (!_expanded)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _PatchNotesContent._htmlCollapsedMaxHeight,
            ),
            child: ClipRect(child: htmlWidget),
          )
        else
          htmlWidget,
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: readMoreStyle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResolvedPresentationTheme {
  const _ResolvedPresentationTheme({
    required this.accentColor,
    required this.accentForegroundColor,
    required this.surfaceColor,
    required this.contentColor,
    required this.outlineColor,
  });

  factory _ResolvedPresentationTheme.from(
    BuildContext context,
    FirebaseUpdatePresentationTheme theme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return _ResolvedPresentationTheme(
      accentColor: theme.accentColor ?? colorScheme.primary,
      accentForegroundColor:
          theme.accentForegroundColor ?? colorScheme.onPrimary,
      surfaceColor: theme.surfaceColor ?? colorScheme.surfaceContainerHighest,
      contentColor: theme.contentColor ?? colorScheme.onSurface,
      outlineColor: theme.outlineColor ?? colorScheme.outlineVariant,
    );
  }

  final Color accentColor;
  final Color accentForegroundColor;
  final Color surfaceColor;
  final Color contentColor;
  final Color outlineColor;
}
