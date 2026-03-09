import 'package:flutter/foundation.dart';

import 'firebase_update_patch_notes_format.dart';

@immutable
class FirebaseUpdatePayload {
  const FirebaseUpdatePayload({
    this.minimumVersion,
    this.latestVersion,
    this.updateTitle,
    this.updateMessage,
    this.forceUpdateTitle,
    this.forceUpdateMessage,
    this.optionalUpdateTitle,
    this.optionalUpdateMessage,
    this.maintenanceTitle,
    this.maintenanceMessage,
    this.patchNotes,
    this.patchNotesFormat = FirebaseUpdatePatchNotesFormat.plainText,
  });

  final String? minimumVersion;
  final String? latestVersion;
  final String? updateTitle;
  final String? updateMessage;
  final String? forceUpdateTitle;
  final String? forceUpdateMessage;
  final String? optionalUpdateTitle;
  final String? optionalUpdateMessage;
  final String? maintenanceTitle;
  final String? maintenanceMessage;
  final String? patchNotes;
  final FirebaseUpdatePatchNotesFormat patchNotesFormat;
}
