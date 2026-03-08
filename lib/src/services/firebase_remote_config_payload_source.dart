import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../config/firebase_update_config.dart';
import 'remote_config_payload_source.dart';

class FirebaseRemoteConfigPayloadSource implements RemoteConfigPayloadSource {
  FirebaseRemoteConfigPayloadSource();

  FirebaseRemoteConfig? _remoteConfig;

  @override
  bool get isAvailable => Firebase.apps.isNotEmpty;

  @override
  Future<Map<String, dynamic>?> fetchPayload(
    FirebaseUpdateConfig config,
  ) async {
    if (!isAvailable) {
      return null;
    }

    final remoteConfig = await _instance(config);
    await remoteConfig.fetchAndActivate();
    return _decode(remoteConfig.getString(config.remoteConfigKey));
  }

  @override
  Stream<Map<String, dynamic>?> watchPayload(
    FirebaseUpdateConfig config,
  ) async* {
    if (!isAvailable || !config.listenToRealtimeUpdates) {
      return;
    }

    final remoteConfig = await _instance(config);
    yield* remoteConfig.onConfigUpdated
        .where((event) => event.updatedKeys.contains(config.remoteConfigKey))
        .asyncMap((event) async {
          await remoteConfig.activate();
          return _decode(remoteConfig.getString(config.remoteConfigKey));
        });
  }

  Future<FirebaseRemoteConfig> _instance(FirebaseUpdateConfig config) async {
    final remoteConfig = _remoteConfig ??= FirebaseRemoteConfig.instance;
    await remoteConfig.ensureInitialized();
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: config.fetchTimeout,
        minimumFetchInterval: config.minimumFetchInterval,
      ),
    );
    return remoteConfig;
  }

  Map<String, dynamic>? _decode(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
