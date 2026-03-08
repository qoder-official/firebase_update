import 'package:flutter/foundation.dart';

import 'firebase_update_kind.dart';
import 'firebase_update_patch_notes_format.dart';
import 'firebase_update_payload.dart';

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

  final FirebaseUpdateKind kind;
  final bool isInitialized;
  final String? title;
  final String? currentVersion;
  final String? minimumVersion;
  final String? latestVersion;
  final String? message;
  final String? patchNotes;
  final FirebaseUpdatePatchNotesFormat patchNotesFormat;
  final String? storeUrl;
  final String? maintenanceTitle;
  final String? maintenanceMessage;
  final FirebaseUpdatePayload? payload;

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
