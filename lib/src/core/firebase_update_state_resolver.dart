import '../models/firebase_update_kind.dart';
import '../models/firebase_update_payload.dart';
import '../models/firebase_update_state.dart';
import 'version_comparator.dart';

class FirebaseUpdateStateResolver {
  const FirebaseUpdateStateResolver({
    VersionComparator versionComparator = const VersionComparator(),
  }) : _versionComparator = versionComparator;

  final VersionComparator _versionComparator;

  FirebaseUpdateState resolve({
    required bool isInitialized,
    required String? currentVersion,
    required FirebaseUpdatePayload payload,
  }) {
    final normalizedCurrentVersion = _normalize(currentVersion);
    if (!isInitialized) {
      return const FirebaseUpdateState.idle();
    }

    if (normalizedCurrentVersion == null) {
      return FirebaseUpdateState(
        kind: FirebaseUpdateKind.idle,
        isInitialized: true,
        title: payload.updateTitle,
        payload: payload,
        message:
            'Firebase Update is initialized, but no current app version is available yet.',
      );
    }

    if (payload.maintenanceEnabled) {
      return FirebaseUpdateState(
        kind: FirebaseUpdateKind.maintenance,
        isInitialized: true,
        title: payload.maintenanceTitle ?? payload.updateTitle,
        currentVersion: normalizedCurrentVersion,
        minimumVersion: _normalize(payload.minimumVersion),
        latestVersion: _normalize(payload.latestVersion),
        maintenanceTitle: payload.maintenanceTitle,
        maintenanceMessage: payload.maintenanceMessage,
        patchNotes: payload.patchNotes,
        patchNotesFormat: payload.patchNotesFormat,
        storeUrl: payload.storeUrl,
        payload: payload,
        message:
            payload.maintenanceMessage ??
            payload.updateMessage ??
            'Maintenance mode is currently active for this app.',
      );
    }

    final minimumVersion = _normalize(payload.minimumVersion);
    if (minimumVersion != null &&
        _versionComparator.compare(normalizedCurrentVersion, minimumVersion) <
            0) {
      return FirebaseUpdateState(
        kind: FirebaseUpdateKind.forceUpdate,
        isInitialized: true,
        title:
            payload.forceUpdateTitle ??
            payload.updateTitle ??
            'Update required',
        currentVersion: normalizedCurrentVersion,
        minimumVersion: minimumVersion,
        latestVersion: _normalize(payload.latestVersion),
        patchNotes: payload.patchNotes,
        patchNotesFormat: payload.patchNotesFormat,
        storeUrl: payload.storeUrl,
        payload: payload,
        message:
            payload.forceUpdateMessage ??
            payload.updateMessage ??
            'A newer app version is required before this app can continue.',
      );
    }

    final latestVersion = _normalize(payload.latestVersion);
    if (latestVersion != null &&
        _versionComparator.compare(normalizedCurrentVersion, latestVersion) <
            0) {
      final updateType = payload.updateType?.trim().toLowerCase();
      final kind = updateType == 'force'
          ? FirebaseUpdateKind.forceUpdate
          : FirebaseUpdateKind.optionalUpdate;

      return FirebaseUpdateState(
        kind: kind,
        isInitialized: true,
        title: kind == FirebaseUpdateKind.forceUpdate
            ? (payload.forceUpdateTitle ??
                  payload.updateTitle ??
                  'Update required')
            : (payload.optionalUpdateTitle ??
                  payload.updateTitle ??
                  'Update available'),
        currentVersion: normalizedCurrentVersion,
        minimumVersion: minimumVersion,
        latestVersion: latestVersion,
        patchNotes: payload.patchNotes,
        patchNotesFormat: payload.patchNotesFormat,
        storeUrl: payload.storeUrl,
        payload: payload,
        message: kind == FirebaseUpdateKind.forceUpdate
            ? (payload.forceUpdateMessage ??
                  payload.updateMessage ??
                  'A newer app version is required before this app can continue.')
            : (payload.optionalUpdateMessage ??
                  payload.updateMessage ??
                  'A newer app version is available.'),
      );
    }

    return FirebaseUpdateState(
      kind: FirebaseUpdateKind.upToDate,
      isInitialized: true,
      title: payload.updateTitle,
      currentVersion: normalizedCurrentVersion,
      minimumVersion: minimumVersion,
      latestVersion: latestVersion,
      patchNotes: payload.patchNotes,
      patchNotesFormat: payload.patchNotesFormat,
      storeUrl: payload.storeUrl,
      payload: payload,
      message:
          payload.updateMessage ?? 'The current app version is up to date.',
    );
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
