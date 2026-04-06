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
  Future<Map<String, dynamic>?> fetchPayloadFresh(
    FirebaseUpdateConfig config,
  ) async {
    if (!isAvailable) {
      return null;
    }

    final remoteConfig = _remoteConfig ??= FirebaseRemoteConfig.instance;
    await remoteConfig.ensureInitialized();

    // Temporarily drop the minimum fetch interval to zero so Firebase
    // bypasses its local cache and hits the server.
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: config.fetchTimeout,
        minimumFetchInterval: Duration.zero,
      ),
    );

    try {
      await remoteConfig.fetchAndActivate();
      return _decode(remoteConfig.getString(config.remoteConfigKey));
    } finally {
      // Restore the caller's preferred interval for all subsequent fetches.
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: config.fetchTimeout,
          minimumFetchInterval: config.minimumFetchInterval,
        ),
      );
    }
  }

  /// Maximum number of reconnection attempts before the real-time stream
  /// gives up. Each retry uses exponential backoff (2^attempt seconds).
  static const int _maxReconnectAttempts = 5;

  @override
  Stream<Map<String, dynamic>?> watchPayload(
    FirebaseUpdateConfig config,
  ) async* {
    if (!isAvailable || !config.listenToRealtimeUpdates) {
      return;
    }

    final remoteConfig = await _instance(config);
    var attempt = 0;

    while (attempt <= _maxReconnectAttempts) {
      try {
        yield* remoteConfig.onConfigUpdated
            .where(
                (event) => event.updatedKeys.contains(config.remoteConfigKey))
            .asyncMap((event) async {
          await remoteConfig.activate();
          attempt = 0; // Reset on every successful event.
          return _decode(remoteConfig.getString(config.remoteConfigKey));
        });
        // Stream completed normally — no more retries.
        break;
      } catch (_) {
        attempt++;
        if (attempt > _maxReconnectAttempts) break;
        // Exponential backoff: 2s, 4s, 8s, 16s, 32s.
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
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
