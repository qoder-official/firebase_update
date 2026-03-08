import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/firebase_update_config.dart';
import '../core/firebase_update_payload_parser.dart';
import '../core/firebase_update_state_resolver.dart';
import '../models/firebase_update_state.dart';
import '../presentation/default_update_presenter.dart';
import '../services/app_review_store_launcher.dart';
import '../services/app_version_provider.dart';
import '../services/firebase_remote_config_payload_source.dart';
import '../services/package_info_app_version_provider.dart';
import '../services/remote_config_payload_source.dart';
import '../services/store_launcher.dart';

class FirebaseUpdate {
  FirebaseUpdate._({
    AppVersionProvider? appVersionProvider,
    RemoteConfigPayloadSource? remoteConfigPayloadSource,
    StoreLauncher? storeLauncher,
  }) : _appVersionProvider =
           appVersionProvider ?? const PackageInfoAppVersionProvider(),
       _remoteConfigPayloadSource =
           remoteConfigPayloadSource ?? FirebaseRemoteConfigPayloadSource(),
       _defaultUpdatePresenter = DefaultUpdatePresenter(
         storeLauncher: storeLauncher ?? const AppReviewStoreLauncher(),
       );

  static final FirebaseUpdate instance = FirebaseUpdate._();

  final StreamController<FirebaseUpdateState> _controller =
      StreamController<FirebaseUpdateState>.broadcast();
  final FirebaseUpdatePayloadParser _payloadParser =
      const FirebaseUpdatePayloadParser();
  final FirebaseUpdateStateResolver _stateResolver =
      const FirebaseUpdateStateResolver();
  final AppVersionProvider _appVersionProvider;
  final RemoteConfigPayloadSource _remoteConfigPayloadSource;
  final DefaultUpdatePresenter _defaultUpdatePresenter;

  FirebaseUpdateState _currentState = const FirebaseUpdateState.idle();
  GlobalKey<NavigatorState>? _navigatorKey;
  FirebaseUpdateConfig? _config;
  StreamSubscription<Map<String, dynamic>?>? _payloadSubscription;
  String? _currentVersion;

  Stream<FirebaseUpdateState> get stream => _controller.stream;
  FirebaseUpdateState get currentState => _currentState;
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;
  FirebaseUpdateConfig? get config => _config;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required FirebaseUpdateConfig config,
  }) async {
    await _payloadSubscription?.cancel();
    _navigatorKey = navigatorKey;
    _config = config;
    _currentVersion = config.currentVersion ?? await _safeGetCurrentVersion();

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
    _payloadSubscription = _remoteConfigPayloadSource
        .watchPayload(config)
        .listen((payload) {
          _emit(_resolve(config: config, rawPayload: payload));
        });
  }

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

    final payload = _payloadParser.parse(
      config: config,
      rawPayload: rawPayload,
    );
    final state = _stateResolver.resolve(
      isInitialized: true,
      currentVersion:
          currentVersion ?? _currentVersion ?? config.currentVersion,
      payload: payload,
    );
    _emit(state);
    return state;
  }

  @visibleForTesting
  void debugEmit(FirebaseUpdateState state) {
    _emit(state);
  }

  @visibleForTesting
  void debugReset() {
    unawaited(_payloadSubscription?.cancel());
    _payloadSubscription = null;
    _config = null;
    _navigatorKey = null;
    _currentVersion = null;
    _emit(const FirebaseUpdateState.idle());
  }

  void _emit(FirebaseUpdateState state) {
    _currentState = state;
    _controller.add(state);
    final config = _config;
    if (config != null) {
      _defaultUpdatePresenter.presentIfNeeded(
        state: state,
        config: config,
        navigatorKey: _navigatorKey,
      );
    }
  }

  Future<void> _refreshFromRemoteConfig(FirebaseUpdateConfig config) async {
    final payload = await _remoteConfigPayloadSource.fetchPayload(config);
    _emit(_resolve(config: config, rawPayload: payload));
  }

  FirebaseUpdateState _resolve({
    required FirebaseUpdateConfig config,
    required Map<String, dynamic>? rawPayload,
  }) {
    return _stateResolver.resolve(
      isInitialized: true,
      currentVersion: _currentVersion ?? config.currentVersion,
      payload: _payloadParser.parse(config: config, rawPayload: rawPayload),
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
