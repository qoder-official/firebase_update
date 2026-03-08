import 'package:flutter/foundation.dart';

/// Maps the package's internal field names to the actual key names used in
/// your Firebase Remote Config schema.
///
/// This allows the package to work with any existing Remote Config layout
/// without requiring you to rename your fields.
///
/// ```dart
/// const FirebaseUpdateFieldMapping(
///   minimumVersion: 'min_v',
///   latestVersion: 'curr_v',
///   updateType: 'upgrade_type',
///   maintenanceEnabled: 'down_for_service',
/// )
/// ```
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

  /// Remote Config field name for the minimum supported app version string
  /// (e.g. `'1.2.0'`). Required.
  final String minimumVersion;

  /// Remote Config field name for the latest available app version string.
  final String? latestVersion;

  /// Remote Config field name for the shared update dialog title used for
  /// both optional and force update states when state-specific titles are
  /// absent.
  final String? updateTitle;

  /// Remote Config field name for the shared update dialog message.
  final String? updateMessage;

  /// Remote Config field name for the force-update dialog title.
  final String? forceUpdateTitle;

  /// Remote Config field name for the force-update dialog message.
  final String? forceUpdateMessage;

  /// Remote Config field name for the optional-update dialog title.
  final String? optionalUpdateTitle;

  /// Remote Config field name for the optional-update dialog message.
  final String? optionalUpdateMessage;

  /// Remote Config field name for the boolean maintenance-mode flag.
  final String? maintenanceEnabled;

  /// Remote Config field name for the maintenance dialog title.
  final String? maintenanceTitle;

  /// Remote Config field name for the maintenance dialog message.
  final String? maintenanceMessage;

  /// Remote Config field name for the update type string. Recognized values
  /// are `'optional'` and `'force'`.
  final String? updateType;

  /// Remote Config field name for the patch notes string.
  final String? patchNotes;

  /// Remote Config field name for the patch notes format. Recognized values
  /// are `'plainText'` and `'html'`.
  final String? patchNotesFormat;

  /// Remote Config field name for the store URL to open when the user taps
  /// the update CTA.
  final String? storeUrl;
}
