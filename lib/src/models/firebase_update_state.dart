import 'package:flutter/foundation.dart';

import '../config/firebase_update_store_urls.dart';
import 'firebase_update_kind.dart';
import 'firebase_update_patch_notes_format.dart';

/// The resolved update state emitted by `firebase_update`.
///
/// Read [kind] to branch on the current state. The remaining fields carry
/// display copy and version info resolved from Remote Config.
@immutable
class FirebaseUpdateState {
  const FirebaseUpdateState({
    required this.kind,
    required this.isInitialized,
    this.title,
    this.currentVersion,
    this.minimumVersion,
    this.latestVersion,
    this.message,
    this.patchNotes,
    this.patchNotesFormat = FirebaseUpdatePatchNotesFormat.plainText,
    this.maintenanceTitle,
    this.maintenanceMessage,
    this.storeUrls,
  });

  /// Convenience constructor for the uninitialized idle state.
  const FirebaseUpdateState.idle({
    this.isInitialized = false,
    this.message = 'Firebase Update is not initialized yet.',
  })  : kind = FirebaseUpdateKind.idle,
        title = null,
        currentVersion = null,
        minimumVersion = null,
        latestVersion = null,
        patchNotes = null,
        patchNotesFormat = FirebaseUpdatePatchNotesFormat.plainText,
        maintenanceTitle = null,
        maintenanceMessage = null,
        storeUrls = null;

  /// The resolved [FirebaseUpdateKind] for this state.
  final FirebaseUpdateKind kind;

  /// Whether [FirebaseUpdate.initialize] has been called.
  final bool isInitialized;

  /// The dialog or sheet title resolved from Remote Config, or `null` when
  /// the default presenter copy should be used.
  final String? title;

  /// The running app version string at the time of the last check.
  final String? currentVersion;

  /// The minimum supported version string from Remote Config.
  final String? minimumVersion;

  /// The latest available version string from Remote Config.
  final String? latestVersion;

  /// The dialog or sheet body message resolved from Remote Config.
  final String? message;

  /// Patch notes string from Remote Config, rendered according to
  /// [patchNotesFormat].
  final String? patchNotes;

  /// The format to use when rendering [patchNotes].
  final FirebaseUpdatePatchNotesFormat patchNotesFormat;

  /// Maintenance dialog title from Remote Config.
  final String? maintenanceTitle;

  /// Maintenance dialog body message from Remote Config.
  final String? maintenanceMessage;

  /// Per-platform store URLs from Remote Config.
  ///
  /// When present, these take priority over [FirebaseUpdateConfig.fallbackStoreUrls].
  final FirebaseUpdateStoreUrls? storeUrls;

  /// Whether this state blocks user interaction (`forceUpdate` or
  /// `maintenance`).
  bool get isBlocking =>
      kind == FirebaseUpdateKind.forceUpdate ||
      kind == FirebaseUpdateKind.maintenance;

  FirebaseUpdateState copyWith({
    FirebaseUpdateKind? kind,
    bool? isInitialized,
    String? title,
    String? currentVersion,
    String? minimumVersion,
    String? latestVersion,
    String? message,
    String? patchNotes,
    FirebaseUpdatePatchNotesFormat? patchNotesFormat,
    String? maintenanceTitle,
    String? maintenanceMessage,
    FirebaseUpdateStoreUrls? storeUrls,
  }) {
    return FirebaseUpdateState(
      kind: kind ?? this.kind,
      isInitialized: isInitialized ?? this.isInitialized,
      title: title ?? this.title,
      currentVersion: currentVersion ?? this.currentVersion,
      minimumVersion: minimumVersion ?? this.minimumVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      message: message ?? this.message,
      patchNotes: patchNotes ?? this.patchNotes,
      patchNotesFormat: patchNotesFormat ?? this.patchNotesFormat,
      maintenanceTitle: maintenanceTitle ?? this.maintenanceTitle,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      storeUrls: storeUrls ?? this.storeUrls,
    );
  }
}
