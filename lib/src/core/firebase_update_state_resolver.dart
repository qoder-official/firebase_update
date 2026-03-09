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
    if (!isInitialized) return const FirebaseUpdateState.idle();

    final current = _normalize(currentVersion);
    if (current == null) {
      return const FirebaseUpdateState(
        kind: FirebaseUpdateKind.idle,
        isInitialized: true,
        message: 'Firebase Update is initialized, but no current app version is available yet.',
      );
    }

    if (payload.maintenanceMessage?.trim().isNotEmpty ?? false) {
      return FirebaseUpdateState(
        kind: FirebaseUpdateKind.maintenance,
        isInitialized: true,
        title: payload.maintenanceTitle ?? payload.updateTitle,
        currentVersion: current,
        minimumVersion: _normalize(payload.minimumVersion),
        latestVersion: _normalize(payload.latestVersion),
        maintenanceTitle: payload.maintenanceTitle,
        maintenanceMessage: payload.maintenanceMessage,
        patchNotes: payload.patchNotes,
        patchNotesFormat: payload.patchNotesFormat,
        message: payload.maintenanceMessage ??
            payload.updateMessage ??
            'Maintenance mode is currently active for this app.',
      );
    }

    final minimum = _normalize(payload.minimumVersion);
    if (minimum != null && _versionComparator.compare(current, minimum) < 0) {
      return FirebaseUpdateState(
        kind: FirebaseUpdateKind.forceUpdate,
        isInitialized: true,
        title: payload.forceUpdateTitle ?? payload.updateTitle ?? 'Update required',
        currentVersion: current,
        minimumVersion: minimum,
        latestVersion: _normalize(payload.latestVersion),
        patchNotes: payload.patchNotes,
        patchNotesFormat: payload.patchNotesFormat,
        message: payload.forceUpdateMessage ??
            payload.updateMessage ??
            'A newer app version is required before this app can continue.',
      );
    }

    final latest = _normalize(payload.latestVersion);
    if (latest != null && _versionComparator.compare(current, latest) < 0) {
      return FirebaseUpdateState(
        kind: FirebaseUpdateKind.optionalUpdate,
        isInitialized: true,
        title: payload.optionalUpdateTitle ?? payload.updateTitle ?? 'Update available',
        currentVersion: current,
        minimumVersion: minimum,
        latestVersion: latest,
        patchNotes: payload.patchNotes,
        patchNotesFormat: payload.patchNotesFormat,
        message: payload.optionalUpdateMessage ??
            payload.updateMessage ??
            'A newer app version is available.',
      );
    }

    return FirebaseUpdateState(
      kind: FirebaseUpdateKind.upToDate,
      isInitialized: true,
      currentVersion: current,
      minimumVersion: minimum,
      latestVersion: latest,
      message: payload.updateMessage ?? 'The current app version is up to date.',
    );
  }

  String? _normalize(String? value) {
    final s = value?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}
