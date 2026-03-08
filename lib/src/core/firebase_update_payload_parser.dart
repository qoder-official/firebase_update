import '../config/firebase_update_config.dart';
import '../models/firebase_update_patch_notes_format.dart';
import '../models/firebase_update_payload.dart';

class FirebaseUpdatePayloadParser {
  const FirebaseUpdatePayloadParser();

  FirebaseUpdatePayload parse({
    required FirebaseUpdateConfig config,
    required Map<String, dynamic>? rawPayload,
  }) {
    final payload = rawPayload ?? const <String, dynamic>{};
    final fields = config.fields;

    return FirebaseUpdatePayload(
      minimumVersion: _readString(payload, fields.minimumVersion),
      latestVersion: _readString(payload, fields.latestVersion),
      updateTitle: _readString(payload, fields.updateTitle),
      updateMessage: _readString(payload, fields.updateMessage),
      forceUpdateTitle: _readString(payload, fields.forceUpdateTitle),
      forceUpdateMessage: _readString(payload, fields.forceUpdateMessage),
      optionalUpdateTitle: _readString(payload, fields.optionalUpdateTitle),
      optionalUpdateMessage: _readString(payload, fields.optionalUpdateMessage),
      updateType: _readString(payload, fields.updateType),
      maintenanceEnabled:
          _readBool(payload, fields.maintenanceEnabled) ?? false,
      maintenanceTitle: _readString(payload, fields.maintenanceTitle),
      maintenanceMessage: _readString(payload, fields.maintenanceMessage),
      patchNotes: _readString(payload, fields.patchNotes),
      patchNotesFormat: _parsePatchNotesFormat(
        _readString(payload, fields.patchNotesFormat),
      ),
      storeUrl: _readString(payload, fields.storeUrl),
    );
  }

  String? _readString(Map<String, dynamic> payload, String? key) {
    if (key == null || key.isEmpty) {
      return null;
    }
    final value = payload[key];
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  bool? _readBool(Map<String, dynamic> payload, String? key) {
    if (key == null || key.isEmpty) {
      return null;
    }
    final value = payload[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'no':
          return false;
      }
    }
    if (value is num) {
      return value != 0;
    }
    return null;
  }

  FirebaseUpdatePatchNotesFormat _parsePatchNotesFormat(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case 'html':
        return FirebaseUpdatePatchNotesFormat.html;
      default:
        return FirebaseUpdatePatchNotesFormat.plainText;
    }
  }
}
