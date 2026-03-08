import 'package:flutter/foundation.dart';

import '../presentation/firebase_update_presentation.dart';
import 'firebase_update_fallback_store_urls.dart';
import 'firebase_update_field_mapping.dart';

/// Configuration for `firebase_update`.
///
/// Pass an instance to [FirebaseUpdate.initialize] to tell the package which
/// Remote Config object to read, how its fields are named, and how the default
/// presentation should behave.
///
/// ```dart
/// const FirebaseUpdateConfig(
///   remoteConfigKey: 'app_update',
///   fields: FirebaseUpdateFieldMapping(
///     minimumVersion: 'min_version',
///     latestVersion: 'latest_version',
///     updateType: 'update_type',
///   ),
/// )
/// ```
@immutable
class FirebaseUpdateConfig {
  const FirebaseUpdateConfig({
    required this.remoteConfigKey,
    required this.fields,
    this.currentVersion,
    this.fallbackStoreUrls = const FirebaseUpdateFallbackStoreUrls(),
    this.fetchTimeout = const Duration(seconds: 60),
    this.minimumFetchInterval = const Duration(hours: 12),
    this.listenToRealtimeUpdates = true,
    this.enableDefaultPresentation = true,
    this.useBottomSheetForOptionalUpdate,
    this.presentation = const FirebaseUpdatePresentation(),
  });

  /// The key of the Remote Config JSON object that contains the update
  /// configuration. Must match the key name set in the Firebase console.
  final String remoteConfigKey;

  /// Mapping between the package's internal field names and the actual field
  /// names used in your Remote Config schema.
  final FirebaseUpdateFieldMapping fields;

  /// Override the running app version instead of reading it from
  /// `package_info_plus`. Useful in tests or when the host app manages its own
  /// version string.
  final String? currentVersion;

  /// Fallback store URLs used when native store-listing launch fails, keyed
  /// by platform.
  final FirebaseUpdateFallbackStoreUrls fallbackStoreUrls;

  /// Maximum time to wait for a Remote Config fetch to complete.
  final Duration fetchTimeout;

  /// Minimum interval between Remote Config fetches.
  final Duration minimumFetchInterval;

  /// Whether to subscribe to real-time Remote Config updates after the initial
  /// fetch. Defaults to `true`.
  final bool listenToRealtimeUpdates;

  /// Whether the package should automatically present default update and
  /// maintenance UI through the navigator key. Set to `false` if you want to
  /// handle all presentation through [FirebaseUpdateBuilder].
  final bool enableDefaultPresentation;

  /// When `true`, optional updates are shown as a bottom sheet. When `false`,
  /// a dialog is used. Falls back to [FirebaseUpdatePresentation.useBottomSheetForOptionalUpdate]
  /// when not set.
  final bool? useBottomSheetForOptionalUpdate;

  /// Presentation configuration for the default update and maintenance UI,
  /// including theme tokens and custom builder overrides.
  final FirebaseUpdatePresentation presentation;

  bool get resolvesOptionalUpdateAsBottomSheet =>
      useBottomSheetForOptionalUpdate ??
      presentation.useBottomSheetForOptionalUpdate;
}
