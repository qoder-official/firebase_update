import 'package:flutter/foundation.dart';

import '../presentation/firebase_update_presentation.dart';
import 'firebase_update_store_urls.dart';

/// Configuration for `firebase_update`.
///
/// Pass an instance to [FirebaseUpdate.initialize] to tell the package how
/// to connect to Remote Config and how the default presentation should behave.
///
/// The package reads a single Remote Config parameter (default key:
/// `firebase_update_config`) whose value is a JSON object with a
/// [fixed schema](https://pub.dev/packages/firebase_update#remote-config-schema).
/// Override [remoteConfigKey] if your project uses a different parameter name.
///
/// ```dart
/// // Minimal — all defaults
/// const FirebaseUpdateConfig()
///
/// // With store URLs and custom RC key
/// FirebaseUpdateConfig(
///   remoteConfigKey: 'my_update_config',
///   storeUrls: FirebaseUpdateStoreUrls(
///     android: 'https://play.google.com/store/apps/details?id=com.example',
///     ios: 'https://apps.apple.com/app/id000000000',
///   ),
/// )
/// ```
@immutable
class FirebaseUpdateConfig {
  const FirebaseUpdateConfig({
    this.remoteConfigKey = 'firebase_update_config',
    this.currentVersion,
    this.storeUrls = const FirebaseUpdateStoreUrls(),
    this.fetchTimeout = const Duration(seconds: 60),
    this.minimumFetchInterval = const Duration(hours: 12),
    this.listenToRealtimeUpdates = true,
    this.enableDefaultPresentation = true,
    this.useBottomSheetForOptionalUpdate,
    this.presentation = const FirebaseUpdatePresentation(),
  });

  /// The Remote Config parameter key whose value is a JSON object containing
  /// the update configuration. Defaults to `'firebase_update_config'`.
  ///
  /// Override this if your project uses a different key name.
  final String remoteConfigKey;

  /// Override the running app version instead of reading it from
  /// `package_info_plus`. Useful in tests or when the host app manages its own
  /// version string.
  final String? currentVersion;

  /// Per-platform store URLs used when the native store-listing launcher needs
  /// a direct URL.
  final FirebaseUpdateStoreUrls storeUrls;

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
