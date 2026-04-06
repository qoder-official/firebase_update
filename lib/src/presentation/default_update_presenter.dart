import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/material.dart';

import '../config/firebase_update_config.dart';
import '../models/firebase_update_kind.dart';
import '../models/firebase_update_patch_notes_format.dart';
import '../models/firebase_update_state.dart';
import '../services/firebase_update_patch_source.dart';
import '../services/firebase_update_preferences_store.dart';
import '../services/store_launcher.dart';
import 'firebase_update_presentation.dart';

class DefaultUpdatePresenter {
  DefaultUpdatePresenter({required StoreLauncher storeLauncher})
      : _storeLauncher = storeLauncher;

  final StoreLauncher _storeLauncher;
  FirebaseUpdateKind? _presentedKind;
  String? _skippedVersion;
  String? _sessionDismissedVersion;

  // Clock abstraction — replaced in tests via [setClockForTesting] so that
  // time-based snooze can be verified without real wall-clock delays.
  DateTime Function() _clock = DateTime.now;
  // True when a test has injected a custom clock.  When set, the real-time
  // snooze expiry timer is skipped — tests exercise re-appearance by advancing
  // the injected clock and calling applyPayload (which calls presentIfNeeded).
  bool _clockOverridden = false;
  DateTime? _snoozedUntil;
  String? _snoozedForVersion; // tracks which latestVersion triggered the snooze
  FirebaseUpdatePreferencesStore? _store;

  // Real-time snooze timer — fires presentIfNeeded when the snooze expires,
  // re-showing the optional update prompt without a restart or RC push.
  Timer? _snoozeExpiryTimer;
  GlobalKey<NavigatorState>? _lastNavigatorKey;
  FirebaseUpdateConfig? _lastConfig;
  FirebaseUpdateState? _lastOptionalState;
  bool _allowNextDismissal = false;
  String? _debugDismissedBlockingSignature;

  // ---------------------------------------------------------------------------
  // Concurrency guards
  // ---------------------------------------------------------------------------

  /// Maximum number of frames the presenter will wait for the navigator to
  /// mount before giving up on showing a blocking dialog. At ~16ms per frame
  /// this is roughly 800ms — generous enough for the heaviest app startup.
  static const int _kMaxMountRetries = 50;

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
    _sessionDismissedVersion = null;
    _snoozedUntil = null;
    _snoozedForVersion = null;
    _snoozeExpiryTimer?.cancel();
    _snoozeExpiryTimer = null;
    _lastNavigatorKey = null;
    _lastConfig = null;
    _lastOptionalState = null;
    _allowNextDismissal = false;
    _debugDismissedBlockingSignature = null;
    _store = null;
    _clock = DateTime.now;
    _clockOverridden = false;
  }

  // Not annotated @visibleForTesting so that FirebaseUpdate.debugSetClock
  // can delegate to it without triggering the linter.
  // ignore: use_setters_to_change_properties
  void internalSetClock(DateTime Function() clock) {
    _clock = clock;
    _clockOverridden = true;
  }

  /// Loads persisted skip-version and snooze state from [store].
  ///
  /// Called by [FirebaseUpdate.initialize] after reading from persistent storage.
  void loadPersistedState({
    required FirebaseUpdatePreferencesStore store,
    required String? skippedVersion,
    required DateTime? snoozedUntil,
    required String? snoozedForVersion,
  }) {
    _store = store;
    _skippedVersion = skippedVersion;
    _snoozedUntil = snoozedUntil;
    _snoozedForVersion = snoozedForVersion;
  }

  // ---------------------------------------------------------------------------
  // Programmatic state mutators — called from FirebaseUpdate public API so
  // custom dialog builders can interact with skip/snooze state directly.
  // ---------------------------------------------------------------------------

  void applySnoozedUntil(DateTime until) {
    _snoozedUntil = until;
  }

  /// Computes `_clock() + duration`, stores it, and returns the expiry.
  /// Used by [FirebaseUpdate.snoozeOptionalUpdate] so the controller stays
  /// consistent with whatever clock is active (real or injected for tests).
  DateTime applySnooze(Duration duration, {String? forVersion}) {
    final until = _clock().add(duration);
    _snoozedUntil = until;
    _snoozedForVersion = forVersion;
    // Timed snooze supersedes any active session dismiss for the same version.
    _sessionDismissedVersion = null;
    if (forVersion != null) {
      unawaited(_store?.setSnoozedForVersion(forVersion));
    }
    return until;
  }

  void applySkippedVersion(String version) {
    _skippedVersion = version;
    _sessionDismissedVersion = null;
  }

  void applySessionDismiss(String version) {
    _sessionDismissedVersion = version;
  }

  void clearSnoozedUntil() {
    _snoozedUntil = null;
    _snoozedForVersion = null;
    _snoozeExpiryTimer?.cancel();
    _snoozeExpiryTimer = null;
  }

  void clearSkippedVersion() {
    _skippedVersion = null;
  }

  // Starts (or restarts) the real-time snooze expiry timer.
  // When it fires, the optional update dialog is re-presented automatically —
  // no restart or RC push required.
  //
  // The timer is skipped when a test clock has been injected via
  // [internalSetClock]; tests exercise re-appearance by advancing the clock
  // and calling applyPayload / presentIfNeeded directly.
  void _startSnoozeTimer(
    Duration duration,
    String forVersion,
    GlobalKey<NavigatorState> navigatorKey,
    FirebaseUpdateConfig config,
    FirebaseUpdateState state,
  ) {
    if (_clockOverridden) return;
    _snoozeExpiryTimer?.cancel();
    _snoozeExpiryTimer = Timer(duration, () {
      _snoozeExpiryTimer = null;
      // Clear the expired snooze so presentIfNeeded won't suppress the dialog.
      if (_snoozedForVersion == forVersion) {
        _snoozedUntil = null;
        _snoozedForVersion = null;
      }
      // Use stored context; fall back to the latest seen optional state.
      final key = _lastNavigatorKey ?? navigatorKey;
      final cfg = _lastConfig ?? config;
      final st = _lastOptionalState ?? state;
      presentIfNeeded(state: st, config: cfg, navigatorKey: key);
    });
  }

  bool _isBlockingKind(FirebaseUpdateKind kind) =>
      kind == FirebaseUpdateKind.forceUpdate ||
      kind == FirebaseUpdateKind.maintenance;

  bool _showsDebugBack(FirebaseUpdateConfig config) =>
      config.allowDebugBack && kDebugMode;

  String _blockingStateSignature(FirebaseUpdateState state) {
    return [
      state.kind.name,
      state.title ?? '',
      state.currentVersion ?? '',
      state.minimumVersion ?? '',
      state.latestVersion ?? '',
      state.message ?? '',
      state.maintenanceTitle ?? '',
      state.maintenanceMessage ?? '',
      state.patchNotes ?? '',
      state.patchNotesFormat.name,
    ].join('|');
  }

  void _dismissBlockingForDebug(
    BuildContext context,
    FirebaseUpdateState state,
  ) {
    _debugDismissedBlockingSignature = _blockingStateSignature(state);
    _allowNextDismissal = true;
    _isPresenting = false;
    _presentedKind = null;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _runBeforePresentHook(
    BuildContext context,
    FirebaseUpdateConfig config,
    FirebaseUpdateState state,
  ) async {
    final callback = config.onBeforePresent;
    if (callback == null) return;

    try {
      await callback(context, state);
    } catch (_) {
      // Asset preloading should not block a critical maintenance/update gate.
    }
  }

  FirebaseUpdatePresentationData _presentationDataForCustomWidget(
    BuildContext context,
    FirebaseUpdatePresentationData data,
  ) {
    VoidCallback? wrapCallback(
      VoidCallback? callback,
      bool shouldDismiss,
    ) {
      if (callback == null) return null;
      final route = ModalRoute.of(context);
      return () {
        callback();
        if (!shouldDismiss) return;
        scheduleMicrotask(() {
          if (!context.mounted) return;
          if (route != null && !route.isCurrent) return;
          Navigator.of(context, rootNavigator: true).maybePop();
        });
      };
    }

    return data.copyWith(
      onUpdateClick:
          wrapCallback(data.onUpdateClick, data.dismissOnUpdateClick),
      dismissOnUpdateClick: false,
      onLaterClick: wrapCallback(data.onLaterClick, data.dismissOnLaterClick),
      dismissOnLaterClick: false,
      onSkipClick: wrapCallback(data.onSkipClick, data.dismissOnSkipClick),
      dismissOnSkipClick: false,
    );
  }

  /// Schedules a post-frame callback that re-invokes [presentIfNeeded].
  ///
  /// For blocking states (force update / maintenance) the callback re-schedules
  /// itself up to [retriesRemaining] times if the navigator is still not
  /// mounted. This prevents a force update from being silently dropped when
  /// [initialize] runs before the widget tree is fully built.
  void _deferUntilMounted({
    required FirebaseUpdateState state,
    required FirebaseUpdateConfig config,
    required GlobalKey<NavigatorState>? navigatorKey,
    required int retriesRemaining,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx =
          navigatorKey?.currentContext ?? navigatorKey?.currentState?.context;
      if (ctx != null) {
        presentIfNeeded(
            state: state, config: config, navigatorKey: navigatorKey);
        return;
      }
      // Still not mounted — retry for blocking states.
      if (retriesRemaining > 1) {
        _deferUntilMounted(
          state: state,
          config: config,
          navigatorKey: navigatorKey,
          retriesRemaining: retriesRemaining - 1,
        );
      }
    });
  }

  void presentIfNeeded({
    required FirebaseUpdateState state,
    required FirebaseUpdateConfig config,
    required GlobalKey<NavigatorState>? navigatorKey,
  }) {
    if (!config.enableDefaultPresentation || navigatorKey == null) {
      return;
    }

    // Keep a reference to the latest navigator/config for the snooze timer.
    _lastNavigatorKey = navigatorKey;
    _lastConfig = config;
    if (state.kind == FirebaseUpdateKind.optionalUpdate) {
      _lastOptionalState = state;
    }

    // A force update supersedes any prior optional snooze — the user is
    // blocked by the server, not voluntarily deferring.  Clearing the snooze
    // here ensures that when the force constraint is later lifted and state
    // drops back to optionalUpdate, the dialog appears immediately instead of
    // being silently suppressed by a stale snooze.
    if (state.kind == FirebaseUpdateKind.forceUpdate && _snoozedUntil != null) {
      _snoozedUntil = null;
      _snoozedForVersion = null;
      _snoozeExpiryTimer?.cancel();
      _snoozeExpiryTimer = null;
      unawaited(_store?.clearSnoozedUntil());
    }

    if (state.kind == FirebaseUpdateKind.idle ||
        state.kind == FirebaseUpdateKind.upToDate) {
      _debugDismissedBlockingSignature = null;
      if (state.kind == FirebaseUpdateKind.upToDate) {
        _generation++;
        _sessionDismissedVersion = null;
        // Dismiss any active overlay so the app returns to a usable state
        // when the server signals that no update or maintenance is needed.
        if (_isPresenting) {
          // The overlay is actually on the navigator — pop it.
          // pop() (not maybePop) is required because force-update and
          // maintenance dialogs use PopScope(canPop: false) and are
          // intentionally non-user-dismissable; only the presenter may
          // programmatically close them.
          _allowNextDismissal = true;
          _isPresenting = false;
          _presentedKind = null;
          final context =
              navigatorKey.currentContext ?? navigatorKey.currentState?.context;
          if (context != null) {
            Navigator.of(context, rootNavigator: true).pop();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final lateContext = navigatorKey.currentContext ??
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

    if (state.isBlocking) {
      final signature = _blockingStateSignature(state);
      if (_debugDismissedBlockingSignature == signature) {
        return;
      }
      if (_debugDismissedBlockingSignature != null) {
        _debugDismissedBlockingSignature = null;
      }
    } else {
      _debugDismissedBlockingSignature = null;
    }

    // Clear persistent skip, session dismiss, and snooze if a newer version is offered.
    if (state.kind == FirebaseUpdateKind.optionalUpdate &&
        state.latestVersion != null) {
      if (_skippedVersion != null && state.latestVersion != _skippedVersion) {
        _skippedVersion = null;
        unawaited(_store?.clearSkippedVersion());
      }
      if (_sessionDismissedVersion != null &&
          state.latestVersion != _sessionDismissedVersion) {
        _sessionDismissedVersion = null;
      }
      // A newer version supersedes any active snooze for an older version.
      if (_snoozedForVersion != null &&
          state.latestVersion != _snoozedForVersion) {
        _snoozedUntil = null;
        _snoozedForVersion = null;
        unawaited(_store?.clearSnoozedUntil());
      }
    }

    // Suppress if user permanently skipped this version.
    if (state.kind == FirebaseUpdateKind.optionalUpdate &&
        state.latestVersion != null &&
        state.latestVersion == _skippedVersion) {
      return;
    }

    // Suppress for the current session if user tapped "Later" with no snooze.
    if (state.kind == FirebaseUpdateKind.optionalUpdate &&
        state.latestVersion != null &&
        state.latestVersion == _sessionDismissedVersion) {
      return;
    }

    // Check time-based snooze for optional updates.
    if (state.kind == FirebaseUpdateKind.optionalUpdate) {
      final snoozedUntil = _snoozedUntil;
      if (snoozedUntil != null && _clock().isBefore(snoozedUntil)) {
        return; // still snoozed
      } else if (snoozedUntil != null) {
        _snoozedUntil = null;
        unawaited(_store?.clearSnoozedUntil());
      }
    }

    if (_presentedKind == state.kind) {
      return;
    }

    final context =
        navigatorKey.currentContext ?? navigatorKey.currentState?.context;
    if (context == null) {
      // Navigator not ready yet — defer to the next frame.
      // For blocking states (force update / maintenance) we retry persistently
      // across multiple frames because missing a force update is unacceptable.
      // For non-blocking states a single retry is sufficient.
      final retriesRemaining =
          _isBlockingKind(state.kind) ? _kMaxMountRetries : 1;
      _deferUntilMounted(
        state: state,
        config: config,
        navigatorKey: navigatorKey,
        retriesRemaining: retriesRemaining,
      );
      return;
    }

    if (_presentedKind != null) {
      if (_isPresenting) {
        // An overlay is actually on the navigator — pop it so the new one
        // can take its place.  pop() is intentional: see the upToDate branch
        // above for the rationale.
        _allowNextDismissal = true;
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
        await _runBeforePresentHook(context, config, state);
        if (!context.mounted || _generation != gen) {
          if (_generation == gen) _presentedKind = null;
          _isPresenting = false;
          return;
        }
        try {
          config.onDialogShown?.call(state);
        } catch (_) {
          // Analytics must never prevent a critical update dialog from appearing.
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
          case FirebaseUpdateKind.shorebirdPatch:
            await _presentShorebirdPatch(context, state, config);
            break;
          case FirebaseUpdateKind.idle:
          case FirebaseUpdateKind.upToDate:
            break;
        }
        final wasExpectedDismissal = _allowNextDismissal;
        _allowNextDismissal = false;
        _isPresenting = false;
        if (_generation == gen &&
            _isBlockingKind(state.kind) &&
            !wasExpectedDismissal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_generation != gen) return;
            presentIfNeeded(
              state: state,
              config: config,
              navigatorKey: navigatorKey,
            );
          });
          return;
        }
        try {
          config.onDialogDismissed?.call(state);
        } catch (_) {
          // Ignore — analytics must not affect post-dismiss cleanup.
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
    final labels = config.presentation.labels;

    // Immediately record snooze / skip when the user taps the button — before
    // the dialog closes — so the real-time snooze timer can start right away.
    void onLater() {
      try {
        config.onOptionalLaterTap?.call();
      } catch (_) {}
      if (versionBeingOffered != null) {
        final snoozeDuration = config.snoozeDuration;
        if (snoozeDuration != null) {
          final until = _clock().add(snoozeDuration);
          _snoozedUntil = until;
          _snoozedForVersion = versionBeingOffered;
          unawaited(_store?.setSnoozedUntil(until));
          unawaited(_store?.setSnoozedForVersion(versionBeingOffered));
          try {
            config.onSnoozed?.call(versionBeingOffered, snoozeDuration);
          } catch (_) {}
          // _lastNavigatorKey is guaranteed non-null here: presentIfNeeded
          // stores it before calling _presentOptionalUpdate.
          if (_lastNavigatorKey != null) {
            _startSnoozeTimer(
              snoozeDuration,
              versionBeingOffered,
              _lastNavigatorKey!,
              config,
              state,
            );
          }
        } else {
          _sessionDismissedVersion = versionBeingOffered;
        }
      }
    }

    void onSkip() {
      if (versionBeingOffered != null) {
        _skippedVersion = versionBeingOffered;
        unawaited(_store?.setSkippedVersion(versionBeingOffered));
        try {
          config.onVersionSkipped?.call(versionBeingOffered);
        } catch (_) {}
      }
    }

    final data = FirebaseUpdatePresentationData(
      title: state.title ?? labels.optionalUpdateTitle ?? 'Update available',
      state: state,
      isBlocking: false,
      primaryLabel: labels.updateNow ?? 'Update now',
      onUpdateClick: () {
        try {
          config.onOptionalUpdateTap?.call();
        } catch (_) {}
        _launchStore(
          context,
          packageName: config.packageName,
          fallbackUrl: _resolveStoreUrl(config, state),
          override: config.onStoreLaunch,
        );
      },
      // _launchStore handles its own pop on success, so don't double-pop.
      dismissOnUpdateClick: false,
      secondaryLabel: labels.later ?? 'Later',
      onLaterClick: onLater,
      tertiaryLabel: config.showSkipVersion
          ? (labels.skipVersion ?? 'Skip this version')
          : null,
      onSkipClick: config.showSkipVersion ? onSkip : null,
    );

    if (config.resolvesOptionalUpdateAsBottomSheet) {
      await _showOptionalBottomSheet(
        context: context,
        config: config,
        data: data,
      );
    } else {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: false,
        barrierColor: config.presentation.theme.barrierColor,
        builder: (dialogContext) => _BlurredModalWrapper(
          sigma: config.presentation.theme.dialogBackgroundBlurSigma,
          child: config.optionalUpdateWidget?.call(
                dialogContext,
                _presentationDataForCustomWidget(dialogContext, data),
              ) ??
              _DefaultUpdateDialog(
                data: data,
                theme: config.presentation.theme,
                iconBuilder: config.presentation.iconBuilder,
                alignment: config.presentation.contentAlignment ??
                    FirebaseUpdateContentAlignment.center,
                notesAlignment: config.presentation.patchNotesAlignment ??
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
      );
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
      onUpdateClick: () {
        try {
          config.onForceUpdateTap?.call();
        } catch (_) {}
        _launchStore(
          context,
          packageName: config.packageName,
          fallbackUrl: _resolveStoreUrl(config, state),
          override: config.onStoreLaunch,
        );
      },
      // _launchStore handles its own pop on success, so don't double-pop.
      dismissOnUpdateClick: false,
    );

    if (config.useBottomSheetForForceUpdate) {
      await _showBlockingBottomSheet(
        context: context,
        config: config,
        data: data,
        customWidget: config.forceUpdateWidget,
        state: state,
      );
    } else {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: false,
        barrierDismissible: false,
        barrierColor: config.presentation.theme.barrierColor,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: _buildBlockingDialogWrapper(
            context: dialogContext,
            config: config,
            state: state,
            child: config.forceUpdateWidget?.call(
                  dialogContext,
                  _presentationDataForCustomWidget(dialogContext, data),
                ) ??
                _DefaultUpdateDialog(
                  data: data,
                  theme: config.presentation.theme,
                  iconBuilder: config.presentation.iconBuilder,
                  alignment: config.presentation.contentAlignment ??
                      FirebaseUpdateContentAlignment.center,
                  notesAlignment: config.presentation.patchNotesAlignment ??
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
            sigma: config.presentation.theme.dialogBackgroundBlurSigma,
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
    required FirebaseUpdateState state,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: config.presentation.theme.barrierColor ?? Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final child = customWidget?.call(
              dialogContext,
              _presentationDataForCustomWidget(dialogContext, data),
            ) ??
            _DefaultUpdateSheet(
              data: data,
              theme: config.presentation.theme,
              iconBuilder: config.presentation.iconBuilder,
              alignment: config.presentation.contentAlignment ??
                  FirebaseUpdateContentAlignment.center,
              notesAlignment: config.presentation.patchNotesAlignment ??
                  FirebaseUpdateContentAlignment.start,
              typography: config.presentation.typography,
              releaseNotesHeading:
                  config.presentation.labels.releaseNotesHeading ??
                      'Release notes',
              readMoreLabel: config.presentation.labels.readMore ?? 'Read more',
              showLessLabel: config.presentation.labels.showLess ?? 'Show less',
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
                children: [
                  if (_showsDebugBack(config))
                    SafeArea(
                      top: false,
                      child: Center(
                        child: _DebugBackButton(
                          onPressed: () =>
                              _dismissBlockingForDebug(dialogContext, state),
                        ),
                      ),
                    ),
                  if (_showsDebugBack(config)) const SizedBox(height: 8),
                  Material(color: Colors.transparent, child: child),
                ],
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
      title: state.title ??
          state.maintenanceTitle ??
          labels.maintenanceTitle ??
          'Maintenance in progress',
      state: state,
      isBlocking: true,
      primaryLabel: labels.okay ?? 'Okay',
      onUpdateClick: null,
    );

    if (config.useBottomSheetForMaintenance) {
      await _showBlockingBottomSheet(
        context: context,
        config: config,
        data: data,
        customWidget: config.maintenanceWidget,
        state: state,
      );
    } else {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: false,
        barrierDismissible: false,
        barrierColor: config.presentation.theme.barrierColor,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: _buildBlockingDialogWrapper(
            context: dialogContext,
            config: config,
            state: state,
            child: config.maintenanceWidget?.call(
                  dialogContext,
                  _presentationDataForCustomWidget(dialogContext, data),
                ) ??
                _DefaultUpdateDialog(
                  data: data,
                  theme: config.presentation.theme,
                  iconBuilder: config.presentation.iconBuilder,
                  alignment: config.presentation.contentAlignment ??
                      FirebaseUpdateContentAlignment.center,
                  notesAlignment: config.presentation.patchNotesAlignment ??
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
            sigma: config.presentation.theme.dialogBackgroundBlurSigma,
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
    VoidCallback? override,
  }) async {
    if (override != null) {
      override();
      if (context.mounted) {
        _allowNextDismissal = true;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      return;
    }

    final didLaunch = await _storeLauncher.launch(
      packageName: packageName,
      fallbackUrl: fallbackUrl,
    );
    if (!context.mounted) {
      return;
    }

    if (didLaunch) {
      _allowNextDismissal = true;
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  Future<void> _showOptionalBottomSheet({
    required BuildContext context,
    required FirebaseUpdateConfig config,
    required FirebaseUpdatePresentationData data,
  }) async {
    var dismissedByExplicitAction = false;
    final wrappedData = data.copyWith(
      onUpdateClick: data.onUpdateClick == null
          ? null
          : () {
              dismissedByExplicitAction = true;
              data.onUpdateClick!.call();
            },
      onLaterClick: data.onLaterClick == null
          ? null
          : () {
              dismissedByExplicitAction = true;
              data.onLaterClick!.call();
            },
      onSkipClick: data.onSkipClick == null
          ? null
          : () {
              dismissedByExplicitAction = true;
              data.onSkipClick!.call();
            },
    );

    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: config.presentation.theme.barrierColor ?? Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        // Snooze/skip logic is already in data.onLaterClick / data.onSkipClick;
        // dismissOnLaterClick and dismissOnSkipClick (both true by default)
        // cause the sheet widget to pop after calling the callback.
        final child = config.optionalUpdateWidget?.call(
              dialogContext,
              _presentationDataForCustomWidget(dialogContext, wrappedData),
            ) ??
            _DefaultUpdateSheet(
              data: wrappedData,
              theme: config.presentation.theme,
              iconBuilder: config.presentation.iconBuilder,
              alignment: config.presentation.contentAlignment ??
                  FirebaseUpdateContentAlignment.center,
              notesAlignment: config.presentation.patchNotesAlignment ??
                  FirebaseUpdateContentAlignment.start,
              typography: config.presentation.typography,
              releaseNotesHeading:
                  config.presentation.labels.releaseNotesHeading ??
                      'Release notes',
              readMoreLabel: config.presentation.labels.readMore ?? 'Read more',
              showLessLabel: config.presentation.labels.showLess ?? 'Show less',
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

    // Dismissing the optional sheet by tapping the barrier should follow the
    // same code path as the "Later" action so session-dismiss / snooze state
    // stays consistent with the visible affordance.
    if (!dismissedByExplicitAction) {
      data.onLaterClick?.call();
    }
  }

  Future<void> _presentShorebirdPatch(
    BuildContext context,
    FirebaseUpdateState state,
    FirebaseUpdateConfig config,
  ) async {
    final labels = config.presentation.labels;
    final title = state.title ?? labels.patchAvailableTitle ?? 'Patch ready';
    final message = state.message ??
        labels.patchAvailableMessage ??
        'A patch has been downloaded. Restart the app to apply it.';
    final applyLabel = labels.applyPatch ?? 'Apply & restart';
    final laterLabel = labels.later ?? 'Later';

    if (config.resolvesOptionalUpdateAsBottomSheet) {
      await _showShorebirdPatchBottomSheet(
        context: context,
        config: config,
        title: title,
        message: message,
        applyLabel: applyLabel,
        laterLabel: laterLabel,
        state: state,
      );
    } else {
      await _showShorebirdPatchDialog(
        context: context,
        config: config,
        title: title,
        message: message,
        applyLabel: applyLabel,
        laterLabel: laterLabel,
        state: state,
      );
    }
    _presentedKind = null;
  }

  Future<void> _showShorebirdPatchDialog({
    required BuildContext context,
    required FirebaseUpdateConfig config,
    required String title,
    required String message,
    required String applyLabel,
    required String laterLabel,
    required FirebaseUpdateState state,
  }) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: false,
      barrierColor: config.presentation.theme.barrierColor,
      builder: (dialogContext) {
        return _BlurredModalWrapper(
          sigma: config.presentation.theme.dialogBackgroundBlurSigma,
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            backgroundColor: Colors.transparent,
            child: _ShorebirdPatchPanel(
              patchSource: config.patchSource!,
              onPatchApplied: config.onPatchApplied,
              theme: config.presentation.theme,
              typography: config.presentation.typography,
              alignment: config.presentation.contentAlignment ??
                  FirebaseUpdateContentAlignment.center,
              title: title,
              message: message,
              applyLabel: applyLabel,
              laterLabel: laterLabel,
              state: state,
              iconBuilder: config.presentation.iconBuilder,
              customWidget: config.shorebirdPatchWidget,
              isSheet: false,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShorebirdPatchBottomSheet({
    required BuildContext context,
    required FirebaseUpdateConfig config,
    required String title,
    required String message,
    required String applyLabel,
    required String laterLabel,
    required FirebaseUpdateState state,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: config.presentation.theme.barrierColor ?? Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
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
              children: [
                Material(
                  color: Colors.transparent,
                  child: _ShorebirdPatchPanel(
                    patchSource: config.patchSource!,
                    onPatchApplied: config.onPatchApplied,
                    theme: config.presentation.theme,
                    typography: config.presentation.typography,
                    alignment: config.presentation.contentAlignment ??
                        FirebaseUpdateContentAlignment.start,
                    title: title,
                    message: message,
                    applyLabel: applyLabel,
                    laterLabel: laterLabel,
                    state: state,
                    iconBuilder: config.presentation.iconBuilder,
                    customWidget: config.shorebirdPatchWidget,
                    isSheet: true,
                  ),
                ),
              ],
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

  String? _resolveStoreUrl(
      FirebaseUpdateConfig config, FirebaseUpdateState state) {
    // RC-sourced URLs take priority; fall back to local config.
    if (kIsWeb) {
      return state.storeUrls?.web ?? config.fallbackStoreUrls.web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return state.storeUrls?.android ?? config.fallbackStoreUrls.android;
      case TargetPlatform.iOS:
        return state.storeUrls?.ios ?? config.fallbackStoreUrls.ios;
      case TargetPlatform.macOS:
        return state.storeUrls?.macos ?? config.fallbackStoreUrls.macos;
      case TargetPlatform.windows:
        return state.storeUrls?.windows ?? config.fallbackStoreUrls.windows;
      case TargetPlatform.linux:
        return state.storeUrls?.linux ?? config.fallbackStoreUrls.linux;
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  Widget _buildBlockingDialogWrapper({
    required BuildContext context,
    required FirebaseUpdateConfig config,
    required FirebaseUpdateState state,
    required Widget child,
    double? sigma,
  }) {
    return _BlurredModalWrapper(
      sigma: sigma,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: child,
          ),
          if (_showsDebugBack(config))
            Positioned(
              left: 0,
              right: 0,
              bottom: 28 + MediaQuery.paddingOf(context).bottom,
              child: Center(
                child: _DebugBackButton(
                  onPressed: () => _dismissBlockingForDebug(context, state),
                ),
              ),
            ),
        ],
      ),
    );
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

class _DebugBackButton extends StatelessWidget {
  const _DebugBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.82),
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withValues(alpha: 0.65),
          fontWeight: FontWeight.w500,
        );

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('Debug back', style: style),
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

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Widget build(BuildContext context) {
    final visualTheme = _ResolvedPresentationTheme.from(context, theme);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final maxWidth = _isDesktop ? theme.desktopMaxDialogWidth : double.infinity;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
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
                  // Flexible allows the panel to fill up to the ConstrainedBox
                  // cap (85 % of screen height) so that when "Read more"
                  // expands the patch notes the SingleChildScrollView inside
                  // the panel scrolls instead of overflowing.
                  Flexible(
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
                      extraBottomPadding: bottomInset,
                    ),
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

  bool get _hasPrimaryAction => data.onUpdateClick != null;

  bool get _hasSecondaryAction =>
      data.secondaryLabel != null && data.onLaterClick != null;

  bool get _hasTertiaryAction =>
      data.tertiaryLabel != null && data.onSkipClick != null;

  bool get _hasAnyActions =>
      _hasPrimaryAction || _hasSecondaryAction || _hasTertiaryAction;

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

  _StateVisualSpec get _visuals =>
      _StateVisualSpec.forState(data.state, theme: theme);

  Widget _buildHero(BuildContext context) {
    final state = data.state;
    final resolvedIcon = iconBuilder?.call(context, state);
    final gradient = theme.heroGradient ?? _visuals.gradient;

    return Align(
      alignment: Alignment.center,
      child: resolvedIcon ??
          _AnimatedHeroBadge(
            icon: _visuals.icon,
            gradient: gradient,
            glowColor: theme.heroGlowColor,
            iconColor: theme.accentForegroundColor,
            size: 54,
          ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final state = data.state;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossAxisAlignment,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildHero(context),
        ),
        const SizedBox(height: 18),
        Text(
          data.title,
          textAlign: _textAlign,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                color: theme.contentColor,
                fontWeight: FontWeight.w800,
              )
              .merge(typography.titleStyle),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 8),
          Text(
            state.message!,
            textAlign: _textAlign,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(
                  color: theme.contentColor.withValues(alpha: 0.86),
                  height: 1.45,
                )
                .merge(typography.messageStyle),
          ),
        ],
        if (state.patchNotes != null && state.patchNotes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.noteBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.outlineColor.withValues(alpha: 0.75),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: _notesAxisAlignment,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 17,
                          color: theme.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            releaseNotesHeading,
                            textAlign: _notesTextAlign,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: theme.contentColor,
                                  fontWeight: FontWeight.w700,
                                )
                                .merge(typography.releaseNotesHeadingStyle),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PatchNotesContent(
                      notes: state.patchNotes!,
                      format: state.patchNotesFormat,
                      alignment: notesAlignment,
                      readMoreLabel: readMoreLabel,
                      showLessLabel: showLessLabel,
                      readMoreColor: theme.accentColor,
                      readMoreStyleOverride: typography.readMoreStyle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: theme.contentColor.withValues(alpha: 0.82),
                            height: 1.45,
                          )
                          .merge(typography.patchNotesStyle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    if (!_hasAnyActions) {
      return const SizedBox.shrink();
    }

    void handlePrimary() {
      data.onUpdateClick?.call();
      if (data.dismissOnUpdateClick) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }

    void handleSecondary() {
      data.onLaterClick?.call();
      if (data.dismissOnLaterClick) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }

    void handleTertiary() {
      data.onSkipClick?.call();
      if (data.dismissOnSkipClick) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }

    final actionRow = Row(
      children: [
        if (data.secondaryLabel != null && data.onLaterClick != null)
          Expanded(
            child: OutlinedButton(
              onPressed: handleSecondary,
              style: OutlinedButton.styleFrom(
                backgroundColor: theme.surfaceColor.withValues(alpha: 0.92),
                foregroundColor: theme.contentColor,
                side: BorderSide(color: theme.outlineColor),
                minimumSize: const Size.fromHeight(54),
                textStyle: typography.secondaryButtonStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(data.secondaryLabel!),
            ),
          ),
        if (data.secondaryLabel != null &&
            data.onLaterClick != null &&
            data.onUpdateClick != null)
          const SizedBox(width: 12),
        if (data.onUpdateClick != null)
          Expanded(
            child: FilledButton(
              onPressed: handlePrimary,
              style: FilledButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.accentForegroundColor,
                elevation: 0,
                shadowColor: theme.accentColor.withValues(alpha: 0.28),
                minimumSize: const Size.fromHeight(54),
                textStyle: typography.primaryButtonStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(data.primaryLabel),
            ),
          ),
      ],
    );

    if (data.tertiaryLabel != null && data.onSkipClick != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          actionRow,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: TextButton(
                onPressed: handleTertiary,
                style: TextButton.styleFrom(
                  foregroundColor: theme.contentColor.withValues(alpha: 0.6),
                  textStyle: typography.secondaryButtonStyle,
                ),
                child: Text(data.tertiaryLabel!),
              ),
            ),
          ),
        ],
      );
    }

    return actionRow;
  }

  @override
  Widget build(BuildContext context) {
    final panelPadding = _hasAnyActions
        ? const EdgeInsets.fromLTRB(18, 16, 18, 18)
        : const EdgeInsets.fromLTRB(20, 18, 20, 22);

    final decoratedChild = DecoratedBox(
      decoration: BoxDecoration(gradient: theme.panelGradient),
      child: Padding(
        padding: panelPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _crossAxisAlignment,
          children: [
            _buildContent(context),
            if (_hasAnyActions) ...[
              const SizedBox(height: 16),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );

    if (scrollable) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: extraBottomPadding),
              child: decoratedChild,
            );
          }

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.only(bottom: extraBottomPadding),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: theme.panelGradient),
                child: Padding(
                  padding: panelPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: _crossAxisAlignment,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: _buildContent(context),
                        ),
                      ),
                      if (_hasAnyActions) ...[
                        const SizedBox(height: 16),
                        _buildActions(context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return decoratedChild;
  }
}

class _StateVisualSpec {
  const _StateVisualSpec({
    required this.icon,
    required this.gradient,
  });

  factory _StateVisualSpec.forState(
    FirebaseUpdateState state, {
    required _ResolvedPresentationTheme theme,
  }) {
    switch (state.kind) {
      case FirebaseUpdateKind.forceUpdate:
        return _StateVisualSpec(
          icon: Icons.rocket_launch_rounded,
          gradient: theme.heroGradient ??
              const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B4A),
                  Color(0xFFFFB14A),
                  Color(0xFFB45CFF),
                ],
              ),
        );
      case FirebaseUpdateKind.maintenance:
        return _StateVisualSpec(
          icon: Icons.construction_rounded,
          gradient: theme.heroGradient ??
              const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFAF6EFF),
                  Color(0xFFFF8F62),
                  Color(0xFFFFD772),
                ],
              ),
        );
      case FirebaseUpdateKind.shorebirdPatch:
        return _StateVisualSpec(
          icon: Icons.auto_fix_high_rounded,
          gradient: theme.heroGradient ??
              const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3D74FF),
                  Color(0xFF45C4FF),
                  Color(0xFF8A5DFF),
                ],
              ),
        );
      case FirebaseUpdateKind.optionalUpdate:
      case FirebaseUpdateKind.idle:
      case FirebaseUpdateKind.upToDate:
        return _StateVisualSpec(
          icon: Icons.system_update_alt_rounded,
          gradient: theme.heroGradient ??
              const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF7B54),
                  Color(0xFFFFC24D),
                  Color(0xFFE779B8),
                ],
              ),
        );
    }
  }

  final IconData icon;
  final Gradient gradient;
}

class _AnimatedHeroBadge extends StatelessWidget {
  const _AnimatedHeroBadge({
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.iconColor,
    required this.size,
  });

  final IconData icon;
  final Gradient gradient;
  final Color glowColor;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        final scale = lerpDouble(0.90, 1.0, value)!;
        final angle = lerpDouble(-0.08, 0.0, value)!;
        final floatOffset = lerpDouble(8, 0, value)!;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.28),
                    blurRadius: 34,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: SizedBox(
                width: size * 0.78,
                height: size * 0.78,
              ),
            ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.42),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 14,
              right: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                child: const SizedBox(width: 10, height: 10),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SizedBox(
                width: size * 0.94,
                height: size * 0.94,
              ),
            ),
            Icon(
              icon,
              size: size * 0.4,
              color: iconColor,
            ),
          ],
        ),
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
    final strippedLength =
        widget.notes.replaceAll(RegExp(r'<[^>]*>'), '').trim().length;
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

// ---------------------------------------------------------------------------
// Shorebird patch panel
// ---------------------------------------------------------------------------

class _ShorebirdPatchPanel extends StatefulWidget {
  const _ShorebirdPatchPanel({
    required this.patchSource,
    required this.onPatchApplied,
    required this.theme,
    required this.typography,
    required this.alignment,
    required this.title,
    required this.message,
    required this.applyLabel,
    required this.laterLabel,
    required this.state,
    required this.isSheet,
    this.iconBuilder,
    this.customWidget,
  });

  final FirebaseUpdatePatchSource patchSource;
  final VoidCallback? onPatchApplied;
  final FirebaseUpdatePresentationTheme theme;
  final FirebaseUpdateTypography typography;
  final FirebaseUpdateContentAlignment alignment;
  final String title;
  final String message;
  final String applyLabel;
  final String laterLabel;
  final FirebaseUpdateState state;
  final bool isSheet;
  final FirebaseUpdateIconBuilder? iconBuilder;
  final FirebaseUpdateViewBuilder? customWidget;

  @override
  State<_ShorebirdPatchPanel> createState() => _ShorebirdPatchPanelState();
}

class _ShorebirdPatchPanelState extends State<_ShorebirdPatchPanel> {
  bool _isApplying = false;

  Future<void> _onApplyTap() async {
    setState(() => _isApplying = true);
    try {
      await widget.patchSource.downloadAndApplyPatch();
      if (!mounted) return;
      if (widget.onPatchApplied != null) {
        widget.onPatchApplied!();
      } else {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Patch applied! Restart the app to update.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to apply patch: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visualTheme = _ResolvedPresentationTheme.from(context, widget.theme);

    // Build presentation data for this state so custom widgets can receive it.
    final presentationData = FirebaseUpdatePresentationData(
      title: widget.title,
      state: widget.state,
      isBlocking: false,
      primaryLabel: widget.applyLabel,
      onUpdateClick: _isApplying ? null : _onApplyTap,
      // _onApplyTap handles its own navigation, so don't double-pop.
      dismissOnUpdateClick: false,
      secondaryLabel: widget.laterLabel,
      onLaterClick: _isApplying ? null : () {},
    );

    if (widget.customWidget != null) {
      return widget.customWidget!(context, presentationData);
    }

    if (widget.isSheet) {
      return _buildSheet(context, visualTheme, presentationData);
    }
    return _buildDialogContent(context, visualTheme, presentationData);
  }

  Widget _buildDialogContent(
    BuildContext context,
    _ResolvedPresentationTheme visualTheme,
    FirebaseUpdatePresentationData data,
  ) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visualTheme.surfaceColor,
          borderRadius: widget.theme.dialogBorderRadius,
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
          borderRadius: widget.theme.dialogBorderRadius,
          child: _buildPanelContent(context, visualTheme, data),
        ),
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    _ResolvedPresentationTheme visualTheme,
    FirebaseUpdatePresentationData data,
  ) {
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
              borderRadius: widget.theme.sheetBorderRadius,
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
              borderRadius: widget.theme.sheetBorderRadius,
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
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _buildContent(context, visualTheme, data),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: _buildActionRow(context, visualTheme),
                  ),
                  if (bottomInset > 0) SizedBox(height: bottomInset),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent(
    BuildContext context,
    _ResolvedPresentationTheme visualTheme,
    FirebaseUpdatePresentationData data,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _buildContent(context, visualTheme, data),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: _buildActionRow(context, visualTheme),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    _ResolvedPresentationTheme visualTheme,
    FirebaseUpdatePresentationData data,
  ) {
    final resolvedIcon = widget.iconBuilder?.call(context, widget.state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          widget.alignment == FirebaseUpdateContentAlignment.start
              ? CrossAxisAlignment.start
              : widget.alignment == FirebaseUpdateContentAlignment.end
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
      children: [
        Align(
          alignment: widget.alignment == FirebaseUpdateContentAlignment.start
              ? Alignment.centerLeft
              : widget.alignment == FirebaseUpdateContentAlignment.end
                  ? Alignment.centerRight
                  : Alignment.center,
          child: resolvedIcon ??
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: visualTheme.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_fix_high_rounded,
                    color: visualTheme.accentColor,
                    size: 26,
                  ),
                ),
              ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.title,
          textAlign: widget.alignment == FirebaseUpdateContentAlignment.start
              ? TextAlign.start
              : widget.alignment == FirebaseUpdateContentAlignment.end
                  ? TextAlign.end
                  : TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                color: visualTheme.contentColor,
                fontWeight: FontWeight.w800,
              )
              .merge(widget.typography.titleStyle),
        ),
        const SizedBox(height: 10),
        Text(
          widget.message,
          textAlign: widget.alignment == FirebaseUpdateContentAlignment.start
              ? TextAlign.start
              : widget.alignment == FirebaseUpdateContentAlignment.end
                  ? TextAlign.end
                  : TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(
                color: visualTheme.contentColor.withValues(alpha: 0.86),
                height: 1.45,
              )
              .merge(widget.typography.messageStyle),
        ),
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    _ResolvedPresentationTheme visualTheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isApplying
                ? null
                : () => Navigator.of(context, rootNavigator: true).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: visualTheme.contentColor,
              side: BorderSide(color: visualTheme.outlineColor),
              minimumSize: const Size.fromHeight(54),
              textStyle: widget.typography.secondaryButtonStyle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Text(widget.laterLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _isApplying ? null : _onApplyTap,
            style: FilledButton.styleFrom(
              backgroundColor: visualTheme.accentColor,
              foregroundColor: visualTheme.accentForegroundColor,
              minimumSize: const Size.fromHeight(54),
              textStyle: widget.typography.primaryButtonStyle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: _isApplying
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: visualTheme.accentForegroundColor,
                    ),
                  )
                : Text(widget.applyLabel),
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
    required this.heroGradient,
    required this.panelGradient,
    required this.heroGlowColor,
    required this.noteBackgroundColor,
    required this.statusBackgroundColor,
    required this.statusForegroundColor,
  });

  factory _ResolvedPresentationTheme.from(
    BuildContext context,
    FirebaseUpdatePresentationTheme theme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = theme.accentColor ?? colorScheme.primary;
    final surface = theme.surfaceColor ?? colorScheme.surfaceContainerHighest;
    final hslAccent = HSLColor.fromColor(accent);
    final darkerAccent = hslAccent
        .withLightness((hslAccent.lightness - 0.24).clamp(0.0, 1.0))
        .toColor();

    return _ResolvedPresentationTheme(
      accentColor: accent,
      accentForegroundColor:
          theme.accentForegroundColor ?? colorScheme.onPrimary,
      surfaceColor: surface,
      contentColor: theme.contentColor ?? colorScheme.onSurface,
      outlineColor: theme.outlineColor ?? colorScheme.outlineVariant,
      heroGradient: theme.heroGradient,
      panelGradient: theme.panelGradient ??
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.10),
              surface.withValues(alpha: 0.0),
              darkerAccent.withValues(alpha: 0.08),
            ],
          ),
      heroGlowColor: theme.heroGlowColor ?? accent,
      noteBackgroundColor:
          theme.noteBackgroundColor ?? accent.withValues(alpha: 0.08),
      statusBackgroundColor:
          theme.statusBackgroundColor ?? accent.withValues(alpha: 0.12),
      statusForegroundColor: theme.statusForegroundColor ?? darkerAccent,
    );
  }

  final Color accentColor;
  final Color accentForegroundColor;
  final Color surfaceColor;
  final Color contentColor;
  final Color outlineColor;
  final Gradient? heroGradient;
  final Gradient? panelGradient;
  final Color heroGlowColor;
  final Color noteBackgroundColor;
  final Color statusBackgroundColor;
  final Color statusForegroundColor;
}
