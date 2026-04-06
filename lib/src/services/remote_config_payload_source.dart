import '../config/firebase_update_config.dart';

abstract class RemoteConfigPayloadSource {
  bool get isAvailable;

  Future<Map<String, dynamic>?> fetchPayload(FirebaseUpdateConfig config);

  /// Like [fetchPayload], but temporarily sets `minimumFetchInterval` to
  /// [Duration.zero] so the fetch bypasses any cached response.
  ///
  /// Use this when the store version fallback has confirmed the app is
  /// outdated and we need the absolute latest Remote Config values.
  Future<Map<String, dynamic>?> fetchPayloadFresh(
      FirebaseUpdateConfig config);

  Stream<Map<String, dynamic>?> watchPayload(FirebaseUpdateConfig config);
}
