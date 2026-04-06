import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/firebase_update_config.dart';
import '../core/firebase_update_payload_parser.dart';
import '../core/firebase_update_state_resolver.dart';
import '../core/version_comparator.dart';
import '../models/firebase_update_kind.dart';
import '../models/firebase_update_state.dart';
import '../presentation/default_update_presenter.dart';
import '../services/app_review_store_launcher.dart';
import '../services/app_version_provider.dart';
import '../services/firebase_remote_config_payload_source.dart';
import '../services/firebase_update_preferences_store.dart';
import '../services/package_info_app_version_provider.dart';
import '../services/remote_config_payload_source.dart';
import '../services/store_launcher.dart';

/// The singleton entry point for `firebase_update`.
///
/// Call [initialize] once after `Firebase.initializeApp()` to start the update
/// check lifecycle. After initialization the package monitors Remote Config
/// in real time and surfaces update state through [stream], [currentState],
/// and the default package-managed UI when a `navigatorKey` is provided.
///
/// ```dart
/// await FirebaseUpdate.instance.initialize(
///   navigatorKey: rootNavigatorKey,
///   config: const FirebaseUpdateConfig(),
/// );
/// ```
class FirebaseUpdate {
  FirebaseUpdate._({
    AppVersionProvider? appVersionProvider,
    RemoteConfigPayloadSource? remoteConfigPayloadSource,
    StoreLauncher? storeLauncher,
  })  : _appVersionProvider =
            appVersionProvider ?? const PackageInfoAppVersionProvider(),
        _remoteConfigPayloadSource =
            remoteConfigPayloadSource ?? FirebaseRemoteConfigPayloadSource(),
        _defaultUpdatePresenter = DefaultUpdatePresenter(
          storeLauncher: storeLauncher ?? const AppReviewStoreLauncher(),
        );

  /// The shared singleton instance.
  static final FirebaseUpdate instance = FirebaseUpdate._();

  /// When `true`, the 3-second blocking-state retry timer is never created.
  ///
  /// Set this to `true` in test `setUp` so pending timers don't leak into
  /// Flutter's `_verifyInvariants` check.  Has no effect in production.
  @visibleForTesting
  static bool disableBlockingRetryTimer = false;

  final StreamController<FirebaseUpdateState> _controller =
      StreamController<FirebaseUpdateState>.broadcast();
  final FirebaseUpdatePayloadParser _payloadParser =
      const FirebaseUpdatePayloadParser();
  final FirebaseUpdateStateResolver _stateResolver =
      const FirebaseUpdateStateResolver();
  final AppVersionProvider _appVersionProvider;
  final RemoteConfigPayloadSource _remoteConfigPayloadSource;
  final DefaultUpdatePresenter _defaultUpdatePresenter;

  final VersionComparator _versionComparator = const VersionComparator();

  FirebaseUpdateState _currentState = const FirebaseUpdateState.idle();
  GlobalKey<NavigatorState>? _navigatorKey;
  FirebaseUpdateConfig? _config;
  StreamSubscription<Map<String, dynamic>?>? _payloadSubscription;
  Timer? _recheckTimer;
  Timer? _blockingRetryTimer;
  AppLifecycleListener? _lifecycleListener;
  String? _currentVersion;
  FirebaseUpdatePreferencesStore? _store;

  /// A broadcast stream of [FirebaseUpdateState] that emits on every state
  /// change, including real-time Remote Config updates.
  Stream<FirebaseUpdateState> get stream => _controller.stream;

  /// The most recently resolved [FirebaseUpdateState].
  FirebaseUpdateState get currentState => _currentState;

  /// The navigator key that was passed to [initialize], if any.
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  /// The active [FirebaseUpdateConfig], or `null` before [initialize].
  FirebaseUpdateConfig? get config => _config;

  /// Initializes the package with the given [navigatorKey] and [config].
  ///
  /// Performs an immediate Remote Config fetch, then subscribes to real-time
  /// updates if [FirebaseUpdateConfig.listenToRealtimeUpdates] is `true`.
  ///
  /// Must be called after `Firebase.initializeApp()`.
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required FirebaseUpdateConfig config,
  }) async {
    await _payloadSubscription?.cancel();
    _defaultUpdatePresenter.reset();
    _navigatorKey = navigatorKey;
    _config = config;
    _currentVersion = config.currentVersion ?? await _safeGetCurrentVersion();

    // Load persisted skip/snooze state before first presentation.
    final store =
        config.preferencesStore ?? SharedPreferencesFirebaseUpdateStore();
    _store = store;
    final skippedVersion = await store.getSkippedVersion();
    final snoozedUntil = await store.getSnoozedUntil();
    final snoozedForVersion = await store.getSnoozedForVersion();
    _defaultUpdatePresenter.loadPersistedState(
      store: store,
      skippedVersion: skippedVersion,
      snoozedUntil: snoozedUntil,
      snoozedForVersion: snoozedForVersion,
    );

    if (!_remoteConfigPayloadSource.isAvailable) {
      _emit(
        _resolve(config: config, rawPayload: null).copyWith(
          message:
              'Firebase Update is initialized. Call Firebase.initializeApp() before using Remote Config-driven update checks.',
        ),
      );
      return;
    }

    await _refreshFromRemoteConfig(config);
    if (config.listenToRealtimeUpdates) {
      _payloadSubscription =
          _remoteConfigPayloadSource.watchPayload(config).listen(
        (payload) {
          _emit(_resolve(config: config, rawPayload: payload));
        },
        onError: (Object error) {
          // The watchPayload stream handles its own retry logic with
          // exponential backoff. If an error still propagates here the
          // stream has exhausted its retries — fall back to the last
          // known state and rely on periodic / lifecycle re-checks.
        },
      );
    }

    // --- Store version fallback ---
    // When a storeVersionSource is provided, compare the local version
    // against the store version. If the store is ahead, force a cache-busting
    // Remote Config fetch so the update dialog is guaranteed to appear.
    if (config.storeVersionSource != null && _currentVersion != null) {
      unawaited(_checkStoreVersionFallback(config));
    }

    // --- Periodic re-check timer ---
    // Each tick runs the full reliability check: store version comparison
    // followed by a cache-busting or regular RC fetch as appropriate.
    _recheckTimer?.cancel();
    _recheckTimer = null;
    if (config.recheckInterval != null) {
      _recheckTimer = Timer.periodic(config.recheckInterval!, (_) {
        unawaited(_periodicCheck(config));
      });
    }

    // --- App lifecycle listener ---
    // Always registered. On resume:
    // 1. If a blocking state (force update / maintenance) is active, re-emit
    //    it so the dialog is re-presented in case the user went to the store,
    //    didn't update, and came back.
    // 2. If checkStoreVersionOnResume is true and a storeVersionSource is
    //    provided, run the store-anchored version check + cache-bust.
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Re-present any blocking dialog that was dismissed while the
        // user was in the store or app switcher.
        final current = _currentState;
        if (current.kind == FirebaseUpdateKind.forceUpdate ||
            current.kind == FirebaseUpdateKind.maintenance) {
          _emit(current);
        }

        // Store version fallback on resume (opt-in).
        if (config.checkStoreVersionOnResume &&
            config.storeVersionSource != null &&
            _currentVersion != null) {
          unawaited(_checkStoreVersionFallback(config));
        }
      },
    );
  }

  /// Triggers an immediate Remote Config fetch and emits the resolved state.
  Future<void> checkNow() async {
    final config = _config;
    if (config == null) {
      _emit(const FirebaseUpdateState.idle());
      return;
    }

    if (!_remoteConfigPayloadSource.isAvailable) {
      _emit(
        _resolve(config: config, rawPayload: null).copyWith(
          message:
              'Firebase Remote Config is unavailable until Firebase.initializeApp() completes.',
        ),
      );
      return;
    }

    await _refreshFromRemoteConfig(config);
  }

  /// Resolves and emits a state from a raw Remote Config [rawPayload] map.
  ///
  /// Useful in test harnesses or when driving state from a custom source.
  Future<FirebaseUpdateState> applyPayload(
    Map<String, dynamic>? rawPayload, {
    String? currentVersion,
  }) async {
    final config = _config;
    if (config == null) {
      const state = FirebaseUpdateState.idle(
        message: 'Call initialize() before applying update payloads.',
      );
      _emit(state);
      return state;
    }

    final payload = _payloadParser.parse(rawPayload);
    final state = _stateResolver.resolve(
      isInitialized: true,
      currentVersion:
          currentVersion ?? _currentVersion ?? config.currentVersion,
      payload: payload,
    );
    _emit(state);
    return state;
  }

  // ---------------------------------------------------------------------------
  // Public skip / snooze API
  //
  // These methods are primarily useful when you supply a custom
  // [FirebaseUpdateConfig.optionalUpdateWidget] and need to drive skip/snooze
  // state from your own dialog without relying on the built-in buttons.
  // ---------------------------------------------------------------------------

  /// Snoozes the optional-update prompt for [duration].
  ///
  /// If [duration] is omitted, [FirebaseUpdateConfig.snoozeDuration] is used.
  /// If neither is set, the call is a no-op (use
  /// [dismissOptionalUpdateForSession] for a session-only dismiss instead).
  ///
  /// The snooze is persisted via [FirebaseUpdateConfig.preferencesStore] so
  /// it survives app restarts.
  Future<void> snoozeOptionalUpdate([Duration? duration]) async {
    final effectiveDuration = duration ?? _config?.snoozeDuration;
    if (effectiveDuration == null) return;
    // Delegate until-computation to the presenter so the injected test clock
    // is used consistently (avoids mixing real DateTime.now with fake clock).
    final until = _defaultUpdatePresenter.applySnooze(
      effectiveDuration,
      forVersion: _currentState.latestVersion,
    );
    await _store?.setSnoozedUntil(until);
  }

  /// Dismisses the optional-update prompt for the current app session only.
  ///
  /// The prompt will reappear on the next app launch. This mirrors what
  /// happens when the user taps "Later" and no [FirebaseUpdateConfig.snoozeDuration]
  /// is configured.
  void dismissOptionalUpdateForSession() {
    final version = _currentState.latestVersion;
    if (version != null) {
      _defaultUpdatePresenter.applySessionDismiss(version);
    }
  }

  /// Permanently skips the optional-update prompt for [version].
  ///
  /// The prompt for this exact version will not appear again (even after an
  /// app restart) until Remote Config returns a higher [latestVersion].
  ///
  /// Persisted via [FirebaseUpdateConfig.preferencesStore].
  Future<void> skipVersion(String version) async {
    _defaultUpdatePresenter.applySkippedVersion(version);
    await _store?.setSkippedVersion(version);
  }

  /// Clears any active time-based snooze so the optional-update prompt can
  /// reappear on the next state emission.
  Future<void> clearSnooze() async {
    _defaultUpdatePresenter.clearSnoozedUntil();
    await _store?.clearSnoozedUntil();
  }

  /// Clears any persistently skipped version so the optional-update prompt can
  /// reappear on the next state emission.
  Future<void> clearSkippedVersion() async {
    _defaultUpdatePresenter.clearSkippedVersion();
    await _store?.clearSkippedVersion();
  }

  /// Overrides the clock used for snooze calculations.
  ///
  /// Pass a function that returns a controlled [DateTime] to make snooze
  /// behaviour deterministic in widget tests without needing real delays.
  @visibleForTesting
  void debugSetClock(DateTime Function() clock) {
    _defaultUpdatePresenter.internalSetClock(clock);
  }

  @visibleForTesting
  void debugEmit(FirebaseUpdateState state) {
    _emit(state);
  }

  @visibleForTesting
  void debugReset() {
    unawaited(_payloadSubscription?.cancel());
    _payloadSubscription = null;
    _recheckTimer?.cancel();
    _recheckTimer = null;
    _blockingRetryTimer?.cancel();
    _blockingRetryTimer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _config = null;
    _navigatorKey = null;
    _currentVersion = null;
    _store = null;
    _defaultUpdatePresenter.reset();
    _emit(const FirebaseUpdateState.idle());
  }

  /// Returns `true` when [FirebaseUpdateConfig.allowedFlavors] is set and the
  /// current build flavor (`String.fromEnvironment('FLAVOR')`) is not in the
  /// list.  Pure Dart — no additional dependencies.
  bool _isFlavourBlocked(FirebaseUpdateConfig config) {
    final allowed = config.allowedFlavors;
    if (allowed == null) return false;
    const flavor = String.fromEnvironment('FLAVOR');
    return !allowed.contains(flavor);
  }

  void _emit(FirebaseUpdateState state) {
    // When an allowed-flavors whitelist is configured and the current flavor
    // is not on the list, stay idle — no UI, no state propagation.
    final config = _config;
    if (config != null && _isFlavourBlocked(config)) {
      _currentState = const FirebaseUpdateState.idle();
      _controller.add(_currentState);
      return;
    }
    _currentState = state;
    _controller.add(state);
    if (config != null) {
      _defaultUpdatePresenter.presentIfNeeded(
        state: state,
        config: config,
        navigatorKey: _navigatorKey,
      );

      // --- Force update / maintenance safety net ---
      // Schedule a delayed re-presentation attempt for blocking states.
      // If the presenter failed silently (context not mounted, generation
      // race, hot reload, etc.) this retry ensures the dialog appears.
      _blockingRetryTimer?.cancel();
      _blockingRetryTimer = null;
      if (!disableBlockingRetryTimer &&
          (state.kind == FirebaseUpdateKind.forceUpdate ||
              state.kind == FirebaseUpdateKind.maintenance)) {
        _blockingRetryTimer = Timer(const Duration(seconds: 3), () {
          _blockingRetryTimer = null;
          // Only retry if we're still in the same blocking state.
          if (_currentState.kind == state.kind) {
            _defaultUpdatePresenter.presentIfNeeded(
              state: _currentState,
              config: config,
              navigatorKey: _navigatorKey,
            );
          }
        });
      }
      // Check for Shorebird patches whenever the app is up to date.
      if (state.kind == FirebaseUpdateKind.upToDate &&
          config.patchSource != null) {
        unawaited(_checkForPatch(config));
      }
    }
  }

  Future<void> _checkForPatch(FirebaseUpdateConfig config) async {
    try {
      final isAvailable = await config.patchSource!.isPatchAvailable();
      if (!isAvailable) return;
      // Abort if state changed while the async check was in flight.
      if (_currentState.kind != FirebaseUpdateKind.upToDate) return;

      final labels = config.presentation.labels;
      _emit(
        FirebaseUpdateState(
          kind: FirebaseUpdateKind.shorebirdPatch,
          isInitialized: true,
          title: labels.patchAvailableTitle ?? 'Patch ready',
          message: labels.patchAvailableMessage ??
              'A new patch is available. Apply it and restart to update.',
          currentVersion: _currentVersion,
        ),
      );
    } catch (_) {
      // Silently ignore patch check failures.
    }
  }

  /// Unified periodic reliability check.
  ///
  /// If a [StoreVersionSource] is configured, checks the store first. When the
  /// store is ahead the cache-busting fetch already handles RC. Otherwise
  /// falls back to a regular RC fetch to pick up any other config changes.
  Future<void> _periodicCheck(FirebaseUpdateConfig config) async {
    if (config.storeVersionSource != null && _currentVersion != null) {
      try {
        final storeVersion =
            await config.storeVersionSource!.getStoreVersion();
        if (storeVersion != null &&
            _versionComparator.compare(_currentVersion!, storeVersion) < 0) {
          // Store is ahead — cache-bust.
          await _refreshFromRemoteConfigFresh(config);
          return;
        }
      } catch (_) {
        // Fall through to regular fetch on store check failure.
      }
    }
    // No store mismatch (or no store source) — still worth a regular fetch
    // to pick up maintenance mode changes, copy updates, etc.
    await _refreshFromRemoteConfig(config);
  }

  /// Compares the local app version against the store version. When the store
  /// has a newer version, forces a cache-busting Remote Config re-fetch so the
  /// update state is guaranteed to reflect the latest server values — even if
  /// the real-time listener missed the push or the local RC cache is stale.
  Future<void> _checkStoreVersionFallback(FirebaseUpdateConfig config) async {
    try {
      final storeVersion =
          await config.storeVersionSource!.getStoreVersion();
      if (storeVersion == null || _currentVersion == null) return;

      // Store is ahead of the local version — cache-bust fetch.
      if (_versionComparator.compare(_currentVersion!, storeVersion) < 0) {
        await _refreshFromRemoteConfigFresh(config);
      }
    } catch (_) {
      // Store check is a best-effort fallback; never block the lifecycle.
    }
  }

  Future<void> _refreshFromRemoteConfig(FirebaseUpdateConfig config) async {
    final payload = await _remoteConfigPayloadSource.fetchPayload(config);
    _emit(_resolve(config: config, rawPayload: payload));
  }

  /// Like [_refreshFromRemoteConfig] but bypasses the RC cache by temporarily
  /// setting `minimumFetchInterval` to `Duration.zero`.
  Future<void> _refreshFromRemoteConfigFresh(
    FirebaseUpdateConfig config,
  ) async {
    final payload =
        await _remoteConfigPayloadSource.fetchPayloadFresh(config);
    _emit(_resolve(config: config, rawPayload: payload));
  }

  FirebaseUpdateState _resolve({
    required FirebaseUpdateConfig config,
    required Map<String, dynamic>? rawPayload,
  }) {
    return _stateResolver.resolve(
      isInitialized: true,
      currentVersion: _currentVersion ?? config.currentVersion,
      payload: _payloadParser.parse(rawPayload),
    );
  }

  Future<String?> _safeGetCurrentVersion() async {
    try {
      return await _appVersionProvider.getCurrentVersion();
    } catch (_) {
      return null;
    }
  }
}
