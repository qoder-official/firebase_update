import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/firebase_update_state.dart';
import '../presentation/firebase_update_presentation.dart';
import '../services/firebase_update_patch_source.dart';
import '../services/firebase_update_preferences_store.dart';
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
    this.onStoreLaunch,
    this.onForceUpdateTap,
    this.onOptionalUpdateTap,
    this.onOptionalLaterTap,
    this.onDialogShown,
    this.onDialogDismissed,
    this.onSnoozed,
    this.onVersionSkipped,
    this.allowedFlavors,
    this.showSkipVersion = false,
    this.snoozeDuration,
    this.patchSource,
    this.onPatchApplied,
    this.shorebirdPatchWidget,
    this.preferencesStore,
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
  /// when not set. The global default is `false` (dialog).
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

  // ---------------------------------------------------------------------------
  // Callback hooks
  // ---------------------------------------------------------------------------

  /// Overrides the default store-launch behavior for "Update now" buttons.
  ///
  /// When provided, this callback is called **instead of** the default flow
  /// (which tries `app_review` first, then falls back to `url_launcher` with
  /// the platform-appropriate store URL). Use this when you need a fully
  /// custom open-store experience — deep link, in-app browser, analytics, etc.
  ///
  /// The dialog/sheet is dismissed automatically after the callback returns.
  final VoidCallback? onStoreLaunch;

  /// Called when the user taps "Update now" on the force-update dialog.
  ///
  /// Fires in addition to the default store-launch behavior.
  final VoidCallback? onForceUpdateTap;

  /// Called when the user taps "Update now" on the optional-update dialog or
  /// sheet.
  ///
  /// Fires in addition to the default store-launch behavior.
  final VoidCallback? onOptionalUpdateTap;

  /// Called when the user taps "Later" on the optional-update dialog or sheet.
  ///
  /// Fires in addition to the default snooze behavior.
  final VoidCallback? onOptionalLaterTap;

  // ---------------------------------------------------------------------------
  // Analytics callbacks (zero new dependencies)
  // ---------------------------------------------------------------------------

  /// Called immediately after a dialog or bottom sheet is presented to the
  /// user. Receives the [FirebaseUpdateState] that triggered the presentation.
  ///
  /// Use this to track impressions in Firebase Analytics, Mixpanel, Amplitude,
  /// or any other analytics SDK. The package has no analytics dependency —
  /// wire this to whichever SDK your app already uses.
  ///
  /// ```dart
  /// onDialogShown: (state) {
  ///   analytics.logEvent(name: 'update_dialog_shown',
  ///       parameters: {'kind': state.kind.name});
  /// },
  /// ```
  final void Function(FirebaseUpdateState state)? onDialogShown;

  /// Called immediately after a dialog or bottom sheet is dismissed, whether
  /// by user action or programmatically (e.g. server clears the update flag).
  ///
  /// Receives the [FirebaseUpdateState] that was active when the UI was shown.
  final void Function(FirebaseUpdateState state)? onDialogDismissed;

  /// Called when the user snoozes the optional-update prompt by tapping
  /// "Later" while [snoozeDuration] is configured.
  ///
  /// Provides the version being offered and the snooze duration so you can
  /// record both in your analytics backend.
  final void Function(String version, Duration snoozeFor)? onSnoozed;

  /// Called when the user permanently skips a version by tapping
  /// "Skip this version" (requires [showSkipVersion] to be `true`).
  ///
  /// Provides the skipped version string.
  final void Function(String version)? onVersionSkipped;

  // ---------------------------------------------------------------------------
  // Flavor whitelist
  // ---------------------------------------------------------------------------

  /// Restricts the package to specific build flavors.
  ///
  /// When non-null, the package reads `String.fromEnvironment('FLAVOR')` at
  /// runtime and suppresses all UI and state emission if the current flavor is
  /// not in this list. When `null` (the default), the package is always active
  /// regardless of the build flavor.
  ///
  /// Use this to keep staging and development builds silent while production
  /// builds receive update UI:
  ///
  /// ```dart
  /// FirebaseUpdateConfig(
  ///   allowedFlavors: ['production'],
  /// )
  /// ```
  ///
  /// Pass the flavor at build time:
  ///
  /// ```bash
  /// flutter run --dart-define=FLAVOR=production
  /// ```
  final List<String>? allowedFlavors;

  // ---------------------------------------------------------------------------
  // Skip version
  // ---------------------------------------------------------------------------

  /// When `true`, a "Skip this version" button is shown on the optional-update
  /// dialog or sheet. Tapping it permanently hides prompts for that specific
  /// version (persisted across restarts via [preferencesStore]).
  ///
  /// Defaults to `false`.
  final bool showSkipVersion;

  // ---------------------------------------------------------------------------
  // Snooze
  // ---------------------------------------------------------------------------

  /// Duration for which the optional-update prompt is suppressed after the
  /// user taps "Later".
  ///
  /// When `null` (the default), tapping "Later" hides the prompt for the
  /// current app session only — it reappears on the next app launch.
  ///
  /// Set a [Duration] (e.g. `Duration(hours: 24)`) to persist the snooze
  /// across restarts so the prompt stays hidden for that period even after
  /// the user relaunches the app.
  ///
  /// You can also call [FirebaseUpdate.instance.snoozeOptionalUpdate] or
  /// [FirebaseUpdate.instance.dismissOptionalUpdateForSession] programmatically
  /// from a custom [optionalUpdateWidget] to update snooze state without
  /// relying on the built-in buttons.
  final Duration? snoozeDuration;

  // ---------------------------------------------------------------------------
  // Shorebird patches
  // ---------------------------------------------------------------------------

  /// Inject a [FirebaseUpdatePatchSource] to enable automatic patch checking
  /// when the app is up to date.
  ///
  /// When non-null the package calls [FirebaseUpdatePatchSource.isPatchAvailable]
  /// each time an [FirebaseUpdateKind.upToDate] state is emitted, and promotes
  /// to [FirebaseUpdateKind.shorebirdPatch] if a patch is found.
  final FirebaseUpdatePatchSource? patchSource;

  /// Called immediately after [FirebaseUpdatePatchSource.downloadAndApplyPatch]
  /// completes successfully.
  ///
  /// Use this to trigger a hot restart so the patch takes effect. If `null`,
  /// a snackbar is shown instructing the user to restart manually.
  final VoidCallback? onPatchApplied;

  /// Replaces the default patch-available dialog or bottom sheet with a custom
  /// widget.
  ///
  /// Receives [FirebaseUpdatePresentationData] with the patch state, including
  /// a primary tap callback that starts the async patch download.
  final FirebaseUpdateViewBuilder? shorebirdPatchWidget;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Storage backend used to persist the skipped version and snooze expiry
  /// across app restarts.
  ///
  /// Defaults to [SharedPreferencesFirebaseUpdateStore]. Inject a custom
  /// implementation for encrypted storage, database-backed storage, etc.
  final FirebaseUpdatePreferencesStore? preferencesStore;

  bool get resolvesOptionalUpdateAsBottomSheet =>
      useBottomSheetForOptionalUpdate ??
      presentation.useBottomSheetForOptionalUpdate;
}
