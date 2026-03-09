import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
/// // With a package name override and fallback URLs
/// FirebaseUpdateConfig(
///   packageName: 'com.example.app',
///   fallbackStoreUrls: FirebaseUpdateStoreUrls(
///     android: 'https://play.google.com/store/apps/details?id=com.example.app',
///     ios: 'https://apps.apple.com/app/id000000000',
///   ),
/// )
/// ```
@immutable
class FirebaseUpdateConfig {
  const FirebaseUpdateConfig({
    this.remoteConfigKey = 'firebase_update_config',
    this.currentVersion,
    this.packageName,
    this.fallbackStoreUrls = const FirebaseUpdateStoreUrls(),
    this.fetchTimeout = const Duration(seconds: 60),
    this.minimumFetchInterval = const Duration(hours: 12),
    this.listenToRealtimeUpdates = true,
    this.enableDefaultPresentation = true,
    this.useBottomSheetForOptionalUpdate,
    this.useBottomSheetForForceUpdate = false,
    this.useBottomSheetForMaintenance = false,
    this.presentation = const FirebaseUpdatePresentation(),
    this.forceUpdateWidget,
    this.optionalUpdateWidget,
    this.maintenanceWidget,
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

  /// Override the package name used to open the app's store listing.
  ///
  /// By default the package reads the running app's identifier automatically
  /// via `package_info_plus` (Android: `packageName`, iOS: `bundleIdentifier`)
  /// and opens the store listing directly — no URL needed. Override this if
  /// your build uses a different identifier than the one published on the
  /// store (e.g. a staging build pointing at the production listing).
  ///
  /// On Android, the package name is used to construct a
  /// `market://details?id=<packageName>` intent. On iOS, native store
  /// launch still relies on `app_review`; set [fallbackStoreUrls.ios] as
  /// a safety net for devices where that fails.
  final String? packageName;

  /// Per-platform fallback URLs used when the native store-listing launch
  /// fails or is unavailable.
  ///
  /// The package first attempts to open the store directly using the app's
  /// package name (or the [packageName] override). These URLs are only used
  /// if that native launch fails, acting as a guaranteed fallback so the
  /// user can always reach the store page.
  final FirebaseUpdateStoreUrls fallbackStoreUrls;

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

  /// When `true`, force updates are shown as a bottom sheet instead of a dialog.
  /// Defaults to `false`. The sheet is non-dismissable — users can only tap
  /// 'Update now'.
  final bool useBottomSheetForForceUpdate;

  /// When `true`, maintenance mode is shown as a bottom sheet instead of a
  /// dialog. Defaults to `false`. The sheet is non-dismissable.
  final bool useBottomSheetForMaintenance;

  /// Presentation configuration for the default update and maintenance UI,
  /// including theme tokens, content alignment, and icon overrides.
  final FirebaseUpdatePresentation presentation;

  /// Replaces the default force-update dialog with a fully custom widget.
  ///
  /// Receives [FirebaseUpdatePresentationData] with the resolved title, state,
  /// and the primary tap callback wired to launch the store.
  final FirebaseUpdateViewBuilder? forceUpdateWidget;

  /// Replaces the default optional-update dialog or bottom sheet with a custom
  /// widget. The modal type (dialog vs sheet) is still controlled by
  /// [useBottomSheetForOptionalUpdate].
  ///
  /// Receives [FirebaseUpdatePresentationData] including the 'Later' callback.
  final FirebaseUpdateViewBuilder? optionalUpdateWidget;

  /// Replaces the default maintenance dialog with a fully custom widget.
  ///
  /// Receives [FirebaseUpdatePresentationData] with the resolved title and state.
  final FirebaseUpdateViewBuilder? maintenanceWidget;

  bool get resolvesOptionalUpdateAsBottomSheet =>
      useBottomSheetForOptionalUpdate ??
      presentation.useBottomSheetForOptionalUpdate;
}
