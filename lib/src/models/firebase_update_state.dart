import 'package:flutter/foundation.dart';

import 'firebase_update_kind.dart';
import 'firebase_update_patch_notes_format.dart';
import 'firebase_update_payload.dart';

/// The resolved update state emitted by `firebase_update`.
///
/// Consumers can read [kind] to branch on the current state, and use the
/// remaining fields to drive UI copy, version display, and patch-note
/// rendering.
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
    this.storeUrl,
    this.maintenanceTitle,
    this.maintenanceMessage,
    this.payload,
  });

  /// Convenience constructor for the uninitialized idle state.
  const FirebaseUpdateState.idle({
    this.isInitialized = false,
    this.message = 'Firebase Update is not initialized yet.',
  }) : kind = FirebaseUpdateKind.idle,
       title = null,
       currentVersion = null,
       minimumVersion = null,
       latestVersion = null,
       patchNotes = null,
       patchNotesFormat = FirebaseUpdatePatchNotesFormat.plainText,
       storeUrl = null,
       maintenanceTitle = null,
       maintenanceMessage = null,
       payload = null;

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

  /// Store URL from Remote Config. Falls back to
  /// [FirebaseUpdateFallbackStoreUrls] when `null`.
  final String? storeUrl;

  /// Maintenance dialog title from Remote Config.
  final String? maintenanceTitle;

  /// Maintenance dialog body message from Remote Config.
  final String? maintenanceMessage;

  /// The raw parsed payload that produced this state, exposed for advanced
  /// consumers that need access to unmapped fields.
  final FirebaseUpdatePayload? payload;

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
    String? storeUrl,
    String? maintenanceTitle,
    String? maintenanceMessage,
    FirebaseUpdatePayload? payload,
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
      storeUrl: storeUrl ?? this.storeUrl,
      maintenanceTitle: maintenanceTitle ?? this.maintenanceTitle,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      payload: payload ?? this.payload,
    );
  }
}
