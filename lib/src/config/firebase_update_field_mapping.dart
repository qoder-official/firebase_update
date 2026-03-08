import 'package:flutter/foundation.dart';

@immutable
class FirebaseUpdateFieldMapping {
  const FirebaseUpdateFieldMapping({
    required this.minimumVersion,
    this.latestVersion,
    this.updateTitle,
    this.updateMessage,
    this.forceUpdateTitle,
    this.forceUpdateMessage,
    this.optionalUpdateTitle,
    this.optionalUpdateMessage,
    this.maintenanceEnabled,
    this.maintenanceTitle,
    this.maintenanceMessage,
    this.updateType,
    this.patchNotes,
    this.patchNotesFormat,
    this.storeUrl,
  });

  final String minimumVersion;
  final String? latestVersion;
  final String? updateTitle;
  final String? updateMessage;
  final String? forceUpdateTitle;
  final String? forceUpdateMessage;
  final String? optionalUpdateTitle;
  final String? optionalUpdateMessage;
  final String? maintenanceEnabled;
  final String? maintenanceTitle;
  final String? maintenanceMessage;
  final String? updateType;
  final String? patchNotes;
  final String? patchNotesFormat;
  final String? storeUrl;
}
