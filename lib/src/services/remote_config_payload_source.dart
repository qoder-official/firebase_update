import '../config/firebase_update_config.dart';

abstract class RemoteConfigPayloadSource {
  bool get isAvailable;

  Future<Map<String, dynamic>?> fetchPayload(FirebaseUpdateConfig config);

  Stream<Map<String, dynamic>?> watchPayload(FirebaseUpdateConfig config);
}
