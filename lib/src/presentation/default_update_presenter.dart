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

  /// Clears all presenter-held state. Called on [FirebaseUpdate.initialize]
  /// and [FirebaseUpdate.debugReset] so each initialization cycle starts clean.
  void reset() {
    _presentedKind = null;
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
        _presentedKind = null;
        _skippedVersion = null;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        presentIfNeeded(
          state: state,
          config: config,
          navigatorKey: navigatorKey,
        );
      });
      return;
    }

    if (_presentedKind != null && _presentedKind != state.kind) {
      Navigator.of(context, rootNavigator: true).maybePop();
      _presentedKind = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        presentIfNeeded(
          state: state,
          config: config,
          navigatorKey: navigatorKey,
        );
      });
      return;
    }

    _presentedKind = state.kind;
    unawaited(
      Future<void>(() async {
        if (!context.mounted) {
          _presentedKind = null;
          return;
        }

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

    final data = FirebaseUpdatePresentationData(
      title: state.title ?? 'Update available',
      state: state,
      isBlocking: false,
      primaryLabel: 'Update now',
      secondaryLabel: 'Later',
      onPrimaryTap: () => _launchStore(
        context,
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
                config.presentation.optionalUpdateDialogBuilder?.call(
                  dialogContext,
                  dialogData,
                ) ??
                _DefaultUpdateDialog(
                  data: dialogData,
                  theme: config.presentation.theme,
                  iconBuilder: config.presentation.iconBuilder,
                  alignment:
                      config.presentation.contentAlignment ??
                      FirebaseUpdateContentAlignment.center,
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
    final data = FirebaseUpdatePresentationData(
      title: state.title ?? 'Update required',
      state: state,
      isBlocking: true,
      primaryLabel: 'Update now',
      onPrimaryTap: () => _launchStore(
        context,
        fallbackUrl: _resolveStoreUrl(config),
      ),
    );

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: config.presentation.theme.barrierColor,
      builder: (dialogContext) => _BlurredModalWrapper(
        sigma: config.presentation.theme.dialogBackgroundBlurSigma,
        child:
            config.presentation.forceUpdateDialogBuilder?.call(
              dialogContext,
              data,
            ) ??
            _DefaultUpdateDialog(
              data: data,
              theme: config.presentation.theme,
              iconBuilder: config.presentation.iconBuilder,
              alignment:
                  config.presentation.contentAlignment ??
                  FirebaseUpdateContentAlignment.center,
            ),
      ),
    );

    _presentedKind = null;
  }

  Future<void> _presentMaintenance(
    BuildContext context,
    FirebaseUpdateState state,
    FirebaseUpdateConfig config,
  ) async {
    final data = FirebaseUpdatePresentationData(
      title: state.title ?? state.maintenanceTitle ?? 'Maintenance in progress',
      state: state,
      isBlocking: true,
      primaryLabel: 'Okay',
      onPrimaryTap: null,
    );

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
              config.presentation.maintenanceDialogBuilder?.call(
                dialogContext,
                data,
              ) ??
              _DefaultUpdateDialog(
                data: data,
                theme: config.presentation.theme,
                iconBuilder: config.presentation.iconBuilder,
                alignment:
                    config.presentation.contentAlignment ??
                    FirebaseUpdateContentAlignment.center,
              ),
        ),
      ),
    );

    _presentedKind = null;
  }

  Future<void> _launchStore(BuildContext context, {String? fallbackUrl}) async {
    final didLaunch = await _storeLauncher.launch(fallbackUrl: fallbackUrl);
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
            config.presentation.optionalUpdateBottomSheetBuilder?.call(
              dialogContext,
              sheetData,
            ) ??
            _DefaultUpdateSheet(
              data: sheetData,
              theme: config.presentation.theme,
              iconBuilder: config.presentation.iconBuilder,
              alignment:
                  config.presentation.contentAlignment ??
                  FirebaseUpdateContentAlignment.start,
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
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Material(color: Colors.transparent, child: child)],
              ),
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
    if (kIsWeb) return config.storeUrls.web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return config.storeUrls.android;
      case TargetPlatform.iOS:
        return config.storeUrls.ios;
      case TargetPlatform.macOS:
        return config.storeUrls.macos;
      case TargetPlatform.windows:
        return config.storeUrls.windows;
      case TargetPlatform.linux:
        return config.storeUrls.linux;
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
    this.iconBuilder,
  });

  final FirebaseUpdatePresentationData data;
  final FirebaseUpdatePresentationTheme theme;
  final FirebaseUpdateContentAlignment alignment;
  final FirebaseUpdateIconBuilder? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final visualTheme = _ResolvedPresentationTheme.from(context, theme);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
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
            iconBuilder: iconBuilder,
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
    this.iconBuilder,
  });

  final FirebaseUpdatePresentationData data;
  final FirebaseUpdatePresentationTheme theme;
  final FirebaseUpdateContentAlignment alignment;
  final FirebaseUpdateIconBuilder? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final visualTheme = _ResolvedPresentationTheme.from(context, theme);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: screenWidth,
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
                    iconBuilder: iconBuilder,
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
    this.iconBuilder,
  });

  final FirebaseUpdatePresentationData data;
  final _ResolvedPresentationTheme theme;
  final FirebaseUpdateContentAlignment alignment;
  final FirebaseUpdateIconBuilder? iconBuilder;

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

  @override
  Widget build(BuildContext context) {
    final state = data.state;
    final resolvedIcon = iconBuilder?.call(context, state);
    final panelGradient =
        theme.heroGradient ??
        LinearGradient(
          colors: [theme.surfaceHighlightColor, theme.surfaceColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: panelGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                    ),
                  ),
                  if (state.message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      state.message!,
                      textAlign: _textAlign,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: theme.contentColor.withValues(alpha: 0.86),
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (state.patchNotes != null &&
                      state.patchNotes!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: _crossAxisAlignment,
                        children: [
                          Text(
                            'Release notes',
                            textAlign: _textAlign,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: theme.contentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _PatchNotesContent(
                            notes: state.patchNotes!,
                            format: state.patchNotesFormat,
                            alignment: alignment,
                            readMoreColor: theme.accentColor,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: theme.contentColor.withValues(
                                    alpha: 0.82,
                                  ),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (data.secondaryLabel != null &&
                          data.onSecondaryTap != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: data.onSecondaryTap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.contentColor,
                              side: BorderSide(color: theme.outlineColor),
                              minimumSize: const Size.fromHeight(54),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(data.primaryLabel),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
  });

  final String notes;
  final FirebaseUpdatePatchNotesFormat format;
  final FirebaseUpdateContentAlignment alignment;
  final TextStyle? style;
  final Color? readMoreColor;

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
    final readMoreStyle = resolvedStyle?.copyWith(
      color: widget.readMoreColor ?? Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

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
                _expanded ? 'Show less' : 'Read more',
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
    required this.surfaceHighlightColor,
    required this.contentColor,
    required this.outlineColor,
    required this.heroGradient,
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
      surfaceHighlightColor:
          (theme.surfaceColor ?? colorScheme.surfaceContainerHigh).withValues(
            alpha: 0.92,
          ),
      contentColor: theme.contentColor ?? colorScheme.onSurface,
      outlineColor: theme.outlineColor ?? colorScheme.outlineVariant,
      heroGradient: theme.heroGradient,
    );
  }

  final Color accentColor;
  final Color accentForegroundColor;
  final Color surfaceColor;
  final Color surfaceHighlightColor;
  final Color contentColor;
  final Color outlineColor;
  final Gradient? heroGradient;
}
