import '../config/firebase_update_store_urls.dart';
import '../models/firebase_update_patch_notes_format.dart';
import '../models/firebase_update_payload.dart';

/// Fixed Remote Config field names used by the package.
///
/// These are the keys the package reads from the JSON value stored under
/// [FirebaseUpdateConfig.remoteConfigKey]. Use the same names in your Remote
/// Config schema, or refer to the README for the full expected shape.
abstract final class FirebaseUpdateSchema {
  static const minimumVersion = 'min_version';
  static const latestVersion = 'latest_version';
  static const updateTitle = 'update_title';
  static const updateMessage = 'update_message';
  static const forceUpdateTitle = 'force_update_title';
  static const forceUpdateMessage = 'force_update_message';
  static const optionalUpdateTitle = 'optional_update_title';
  static const optionalUpdateMessage = 'optional_update_message';
  static const maintenanceTitle = 'maintenance_title';
  static const maintenanceMessage = 'maintenance_message';
  static const patchNotes = 'patch_notes';
  static const patchNotesFormat = 'patch_notes_format';
  static const storeUrlAndroid = 'store_url_android';
  static const storeUrlIos = 'store_url_ios';
  static const storeUrlMacos = 'store_url_macos';
  static const storeUrlWindows = 'store_url_windows';
  static const storeUrlLinux = 'store_url_linux';
  static const storeUrlWeb = 'store_url_web';
}

class FirebaseUpdatePayloadParser {
  const FirebaseUpdatePayloadParser();

  FirebaseUpdatePayload parse(Map<String, dynamic>? rawPayload) {
    final p = rawPayload ?? const <String, dynamic>{};

    return FirebaseUpdatePayload(
      minimumVersion: _str(p, FirebaseUpdateSchema.minimumVersion),
      latestVersion: _str(p, FirebaseUpdateSchema.latestVersion),
      updateTitle: _str(p, FirebaseUpdateSchema.updateTitle),
      updateMessage: _str(p, FirebaseUpdateSchema.updateMessage),
      forceUpdateTitle: _str(p, FirebaseUpdateSchema.forceUpdateTitle),
      forceUpdateMessage: _str(p, FirebaseUpdateSchema.forceUpdateMessage),
      optionalUpdateTitle: _str(p, FirebaseUpdateSchema.optionalUpdateTitle),
      optionalUpdateMessage:
          _str(p, FirebaseUpdateSchema.optionalUpdateMessage),
      maintenanceTitle: _str(p, FirebaseUpdateSchema.maintenanceTitle),
      maintenanceMessage: _str(p, FirebaseUpdateSchema.maintenanceMessage),
      patchNotes: _str(p, FirebaseUpdateSchema.patchNotes),
      patchNotesFormat:
          _patchNotesFormat(_str(p, FirebaseUpdateSchema.patchNotesFormat)),
      storeUrls: _storeUrls(p),
    );
  }

  String? _str(Map<String, dynamic> p, String key) {
    final value = p[key];
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  FirebaseUpdateStoreUrls? _storeUrls(Map<String, dynamic> p) {
    final android = _str(p, FirebaseUpdateSchema.storeUrlAndroid);
    final ios = _str(p, FirebaseUpdateSchema.storeUrlIos);
    final macos = _str(p, FirebaseUpdateSchema.storeUrlMacos);
    final windows = _str(p, FirebaseUpdateSchema.storeUrlWindows);
    final linux = _str(p, FirebaseUpdateSchema.storeUrlLinux);
    final web = _str(p, FirebaseUpdateSchema.storeUrlWeb);
    if (android == null &&
        ios == null &&
        macos == null &&
        windows == null &&
        linux == null &&
        web == null) {
      return null;
    }
    return FirebaseUpdateStoreUrls(
      android: android,
      ios: ios,
      macos: macos,
      windows: windows,
      linux: linux,
      web: web,
    );
  }

  FirebaseUpdatePatchNotesFormat _patchNotesFormat(String? raw) {
    if (raw?.trim().toLowerCase() == 'html') {
      return FirebaseUpdatePatchNotesFormat.html;
    }
    return FirebaseUpdatePatchNotesFormat.plainText;
  }
}
