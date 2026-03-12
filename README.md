# firebase_update

> Flutter force update, maintenance mode, and real-time update prompts with Firebase Remote Config.

[![pub.dev](https://img.shields.io/pub/v/firebase_update.svg)](https://pub.dev/packages/firebase_update)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

One package to handle forced updates, optional updates, maintenance mode, and patch notes — with built-in UI, real-time Remote Config listening, and full customization hooks.

**[Full documentation → qoder.in/resources/firebase-update](https://qoder.in/resources/firebase-update)**

---

## Index

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Remote Config Schema](#remote-config-schema)
- [Payload Examples](#payload-examples)
- [Update States](#update-states)
- [How It Works](#how-it-works)
- [Configuration](#configuration)
- [Custom UI](#custom-ui)
- [Reactive Widget](#reactive-widget)
- [API Reference](#api-reference)
- [Testing](#testing)

---

## Features

- **Force update** — blocks app usage when a breaking release is required
- **Optional update** — encourages upgrade via a dismissible dialog or bottom sheet
- **Maintenance mode** — instantly gates the app without shipping a build
- **Patch notes** — plain text or HTML, shown inline in the update UI
- **Real-time updates** — reacts to Remote Config changes without an app restart
- **Built-in UI** — default dialog and bottom sheet, no setup beyond a `navigatorKey`
- **Custom UI** — replace any surface with your own widget builders
- **`FirebaseUpdateBuilder`** — reactive widget for building your own in-screen update surfaces

---

## Installation

```yaml
dependencies:
  firebase_update: ^1.0.0
```

This package requires Firebase to already be set up in your app. If you haven't done that yet, follow the [FlutterFire setup guide](https://firebase.flutter.dev/docs/overview).

---

## Quick Start

### 1. Initialize

Call `initialize()` once during app bootstrap, after `Firebase.initializeApp()`:

```dart
import 'package:firebase_update/firebase_update.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseUpdate.instance.initialize(
    navigatorKey: navigatorKey,
    config: const FirebaseUpdateConfig(),
  );

  runApp(MyApp(navigatorKey: navigatorKey));
}
```

Pass the same `navigatorKey` to your `MaterialApp`:

```dart
MaterialApp(
  navigatorKey: navigatorKey,
  home: const HomeScreen(),
)
```

That's it. The package now listens for Remote Config changes and automatically presents the appropriate UI when an update or maintenance state is detected.

---

## Remote Config Schema

Create a parameter named `firebase_update_config` in the Firebase console (or use a custom name via `remoteConfigKey`). Its value must be a **JSON string**:

```json
{
  "min_version": "2.0.0",
  "latest_version": "2.3.1",
  "maintenance_message": "",
  "patch_notes": "• Bug fixes\n• Performance improvements",
  "patch_notes_format": "text"
}
```

| Field | Type | Description |
|---|---|---|
| `min_version` | string | Minimum supported version. Below this → force update (blocking). |
| `latest_version` | string | Latest available version. Below this → optional update. |
| `maintenance_title` | string | Title shown on the maintenance screen. |
| `maintenance_message` | string | Non-empty string activates maintenance mode (blocking). |
| `force_update_title` | string | Override title for the force update screen. |
| `force_update_message` | string | Override body for the force update screen. |
| `optional_update_title` | string | Override title for the optional update prompt. |
| `optional_update_message` | string | Override body for the optional update prompt. |
| `patch_notes` | string | Release notes shown alongside the update prompt. |
| `patch_notes_format` | string | `"text"` (default) or `"html"`. |

**Priority:** maintenance (if `maintenance_message` is non-empty) → force update (if `current < min_version`) → optional update (if `current < latest_version`). Only one surface is shown at a time; the package dismisses the previous modal before showing a new one.

---

## Payload Examples

These are the three default states most teams care about first. The screenshots below were generated from [`scripts/take_screenshots.sh`](/Volumes/Development/Projects/flutter/Qoder/firebase_update/scripts/take_screenshots.sh), so the README reflects the actual packaged UI.

### Optional Update

Use this when you want to encourage upgrades without blocking the app.

```json
{
  "min_version": "2.0.0",
  "latest_version": "2.6.0",
  "optional_update_title": "Update available",
  "optional_update_message": "Version 2.6.0 is ready with a smoother experience.",
  "patch_notes": "Faster startup · Cleaner onboarding · Bug fixes.",
  "patch_notes_format": "text"
}
```

<p>
  <img src="screenshots/optional_update_dialog.png" alt="Optional update dialog" width="260" />
  <img src="screenshots/optional_update_sheet.png" alt="Optional update sheet" width="260" />
</p>

### Force Update

Use this when the installed app version is no longer safe or compatible.

```json
{
  "min_version": "2.5.0",
  "latest_version": "2.6.0",
  "force_update_message": "This release contains required security fixes.",
  "patch_notes": "<ul><li>Critical security patches</li><li>Required backend compatibility</li></ul>",
  "patch_notes_format": "html"
}
```

<p>
  <img src="screenshots/force_update_dialog.png" alt="Force update dialog" width="260" />
  <img src="screenshots/force_update_sheet.png" alt="Force update sheet" width="260" />
</p>

### Maintenance Mode

Use this when you need to temporarily gate the app without shipping a new build.

```json
{
  "maintenance_title": "Scheduled maintenance",
  "maintenance_message": "We're upgrading our servers. We'll be back shortly."
}
```

<img src="screenshots/maintenance_dialog.png" alt="Maintenance dialog" width="320" />

If you want to go beyond the defaults, the next sections cover state handling, presentation controls, and fully custom surfaces.

---

## Update States

`FirebaseUpdateState.kind` is one of:

| Kind | Meaning |
|---|---|
| `idle` | Not yet initialized. |
| `upToDate` | App version meets the minimum requirement. |
| `optionalUpdate` | A newer version is available, but the app is usable. |
| `forceUpdate` | App version is below the minimum. Usage is blocked. |
| `maintenance` | Maintenance mode is active. Usage is blocked. |

`state.isBlocking` is `true` for `forceUpdate` and `maintenance`.

---

## How It Works

### State priority

Every time the Remote Config payload is received or updated, the package resolves exactly one state. The resolution order is:

```
maintenance_message non-empty?  →  maintenance  (blocking)
current < min_version?          →  forceUpdate  (blocking)
current < latest_version?       →  optionalUpdate
otherwise                       →  upToDate
```

Only one surface is shown at a time. If state changes while a dialog is already on screen, the existing dialog is dismissed first and the new one appears in its place.

---

### Maintenance mode

Activated by setting `maintenance_message` to any non-empty string in the payload. The app is immediately gated — no update button, no store launch, just your message and a "try again" option. The dialog/sheet cannot be dismissed by the user.

To lift maintenance, clear `maintenance_message` (set it to `""` or remove the field). The package detects the change in real time and dismisses the gate automatically.

**Priority:** maintenance takes precedence over everything — even if `min_version` and `latest_version` are also set, the maintenance gate is shown first.

---

### Force update

Triggered when `current_version < min_version`. The dialog/sheet blocks the app; the user can only tap "Update now" to be taken to the store. There is no dismiss, snooze, or skip.

When you raise `min_version` above the user's current version, the force gate appears immediately (or on the next realtime RC push). When you lower it again so the user's version is no longer below the minimum, the gate dismisses automatically.

**Snooze interaction:** if the user previously snoozed an optional update and a force update then comes in, the snooze is automatically cleared. Once the force constraint is lifted and state returns to `optionalUpdate`, the optional dialog appears immediately — the user was blocked by the server, not voluntarily deferring.

---

### Optional update

Triggered when `min_version ≤ current_version < latest_version`. The dialog/sheet is dismissible. The user can:

- **Update now** — taken to the store
- **Later** — dismissed; behavior depends on `snoozeDuration` (see below)
- **Skip this version** — permanently suppressed for this specific version (`showSkipVersion: true` required)

---

### Snooze

Snooze controls how long an optional update stays hidden after the user taps "Later".

| `snoozeDuration` set? | Behavior |
|---|---|
| No (default) | Dismissed for the current session only. Reappears on next app launch. |
| Yes (e.g. `Duration(hours: 24)`) | Hidden for the specified duration, persisted across restarts. Reappears automatically when the timer expires — no restart required. |

**Version-aware snooze:** the snooze is tied to the `latest_version` that was active when the user tapped "Later".

- Same version offered again → snooze remains active until it expires
- Newer version offered → snooze is immediately cleared and the new version is shown

**Example:**
```
User snoozes optional 1.7.0 (24 h snooze active)
→ Admin rolls 1.7.0 back, then serves 1.7.0 again → still snoozed ✓
→ Admin bumps to 1.8.0 instead                    → snooze cleared, 1.8.0 shown ✓
```

---

### Skip version

When `showSkipVersion: true`, the optional prompt shows a "Skip this version" button. Tapping it permanently suppresses prompts for that specific version across all restarts (persisted via `shared_preferences` or your custom store). Cleared automatically when a newer `latest_version` is served.

---

### State transition summary

```
upToDate  ──► optionalUpdate   dialog appears
          ──► forceUpdate       blocking gate appears; any active optional snooze is cleared
          ──► maintenance       blocking gate appears

forceUpdate ──► optionalUpdate  gate dismisses, optional shown (snooze not restored)
            ──► upToDate        gate dismisses, nothing shown
            ──► maintenance     gate replaced by maintenance gate

optionalUpdate ──► forceUpdate  optional dialog dismissed, force gate appears
               ──► maintenance  optional dialog dismissed, maintenance gate appears
               ──► upToDate     optional dialog dismissed, nothing shown
```

---

## Configuration

```dart
FirebaseUpdateConfig(
  // remoteConfigKey defaults to 'firebase_update_config'

  currentVersion: '2.1.0',              // Override auto-detected version
  packageName: 'com.example.app',        // Override auto-detected package name
  fetchTimeout: Duration(seconds: 60),
  minimumFetchInterval: Duration(hours: 12),
  listenToRealtimeUpdates: true,         // React to RC changes without restart
  enableDefaultPresentation: true,       // Set false to fully own the UI
  useBottomSheetForOptionalUpdate: true, // false = dialog instead
  fallbackStoreUrls: FirebaseUpdateStoreUrls(
    android: 'https://play.google.com/store/apps/details?id=com.example.app',
    ios: 'https://apps.apple.com/app/id000000000',
  ),
  presentation: FirebaseUpdatePresentation(...), // Theme / alignment / icon
)
```

---

## Custom UI

Override any surface directly on `FirebaseUpdateConfig` — replace one, two, or all three independently:

```dart
// Just override maintenance — everything else stays default
FirebaseUpdateConfig(
  maintenanceWidget: (context, data) => MyMaintenanceScreen(data: data),
)

// Mix and match
FirebaseUpdateConfig(
  forceUpdateWidget: (context, data) => MyForceUpdateDialog(data: data),
  optionalUpdateWidget: (context, data) => MyUpdateSheet(data: data),
  maintenanceWidget: (context, data) => MyMaintenanceScreen(data: data),
)
```

Each builder receives `FirebaseUpdatePresentationData` with the resolved title, state, primary/secondary action labels, and tap callbacks wired to the correct package behavior — your widget doesn't need to re-implement any of that logic.

For `optionalUpdateWidget`, the modal type (dialog vs bottom sheet) is still controlled by `useBottomSheetForOptionalUpdate` — your widget is the content regardless of which container is used.

### Theming the default UI

```dart
FirebaseUpdatePresentation(
  theme: FirebaseUpdatePresentationTheme(
    accentColor: Colors.indigo,
    accentForegroundColor: Colors.white,
    surfaceColor: Colors.white,
    heroGradient: LinearGradient(
      colors: [Colors.indigo.shade800, Colors.indigo.shade400],
    ),
    dialogBorderRadius: BorderRadius.circular(24),
  ),
)
```

---

## Reactive Widget

Use `FirebaseUpdateBuilder` to build your own in-screen update surfaces — a settings row, a banner, or anything else that should react to update state:

```dart
FirebaseUpdateBuilder(
  builder: (context, state) {
    if (state.kind == FirebaseUpdateKind.optionalUpdate) {
      return UpdateBanner(version: state.latestVersion);
    }
    return const SizedBox.shrink();
  },
)
```

---

## API Reference

### `FirebaseUpdate`

The singleton controller exposed as `FirebaseUpdate.instance`.

```dart
await FirebaseUpdate.instance.initialize(
  navigatorKey: navigatorKey,
  config: config,
);
```

Key members:

| Member | Type | What it does |
|---|---|---|
| `initialize({required navigatorKey, required config})` | `Future<void>` | Boots the package, fetches Remote Config, restores skip/snooze state, and starts real-time listening when enabled. |
| `checkNow()` | `Future<void>` | Forces an immediate Remote Config fetch and re-evaluates the current state. |
| `applyPayload(Map<String, dynamic>? rawPayload, {String? currentVersion})` | `Future<FirebaseUpdateState>` | Resolves state from a raw payload without going through Firebase. Useful for tests and custom sources. |
| `stream` | `Stream<FirebaseUpdateState>` | Broadcast stream of update-state changes. |
| `currentState` | `FirebaseUpdateState` | Last resolved state, synchronously readable. |
| `navigatorKey` | `GlobalKey<NavigatorState>?` | Navigator key registered during initialization. |
| `config` | `FirebaseUpdateConfig?` | Active config object currently in use. |
| `snoozeOptionalUpdate([duration])` | `Future<void>` | Snoozes an optional update using the passed duration or `config.snoozeDuration`. |
| `dismissOptionalUpdateForSession()` | `void` | Hides the current optional prompt only for the current app session. |
| `skipVersion(version)` | `Future<void>` | Permanently skips prompts for one specific version. |
| `clearSnooze()` | `Future<void>` | Clears any persisted snooze window. |
| `clearSkippedVersion()` | `Future<void>` | Clears any persisted skipped version. |

### `FirebaseUpdateState`

Resolved state emitted by the package.

| Property | Type | Notes |
|---|---|---|
| `kind` | `FirebaseUpdateKind` | `idle`, `upToDate`, `optionalUpdate`, `forceUpdate`, `maintenance`, `shorebirdPatch` |
| `isInitialized` | `bool` | `true` after `initialize()` has completed |
| `title` | `String?` | Resolved title used for default presentation |
| `message` | `String?` | Resolved message body |
| `currentVersion` | `String?` | Current app version |
| `minimumVersion` | `String?` | Required minimum version |
| `latestVersion` | `String?` | Latest available version |
| `patchNotes` | `String?` | Raw patch notes content |
| `patchNotesFormat` | `FirebaseUpdatePatchNotesFormat` | `plainText` or `html` |
| `maintenanceTitle` | `String?` | Maintenance title from payload |
| `maintenanceMessage` | `String?` | Maintenance message from payload |
| `storeUrls` | `FirebaseUpdateStoreUrls?` | Store URLs from Remote Config payload |
| `isBlocking` | `bool` | Convenience getter for force update and maintenance |

### `FirebaseUpdateConfig`

Main configuration object passed to `initialize()`.

Core setup:

| Property | Type | Purpose |
|---|---|---|
| `remoteConfigKey` | `String` | Remote Config parameter key. Default: `firebase_update_config` |
| `currentVersion` | `String?` | Manual version override |
| `packageName` | `String?` | Manual app identifier override for store launch |
| `fallbackStoreUrls` | `FirebaseUpdateStoreUrls` | Per-platform store fallback URLs |
| `fetchTimeout` | `Duration` | Remote Config fetch timeout |
| `minimumFetchInterval` | `Duration` | Remote Config fetch throttle interval |
| `listenToRealtimeUpdates` | `bool` | Enables real-time RC subscription |
| `enableDefaultPresentation` | `bool` | Turns package-managed dialogs/sheets on or off |

Presentation control:

| Property | Type | Purpose |
|---|---|---|
| `useBottomSheetForOptionalUpdate` | `bool?` | Optional update as sheet instead of dialog |
| `useBottomSheetForForceUpdate` | `bool` | Force update as sheet |
| `useBottomSheetForMaintenance` | `bool` | Maintenance as sheet |
| `presentation` | `FirebaseUpdatePresentation` | Theme, labels, typography, alignment, icon builder |
| `forceUpdateWidget` | `FirebaseUpdateViewBuilder?` | Replaces default force UI |
| `optionalUpdateWidget` | `FirebaseUpdateViewBuilder?` | Replaces default optional UI |
| `maintenanceWidget` | `FirebaseUpdateViewBuilder?` | Replaces default maintenance UI |
| `shorebirdPatchWidget` | `FirebaseUpdateViewBuilder?` | Replaces default patch-ready UI |

Behavior and hooks:

| Property | Type | Purpose |
|---|---|---|
| `onStoreLaunch` | `VoidCallback?` | Fully overrides default store-launch behavior |
| `onForceUpdateTap` | `VoidCallback?` | Analytics or side effects for force CTA |
| `onOptionalUpdateTap` | `VoidCallback?` | Analytics or side effects for optional CTA |
| `onOptionalLaterTap` | `VoidCallback?` | Analytics or side effects for dismiss CTA |
| `onDialogShown` | `void Function(FirebaseUpdateState)?` | Fires when package UI is presented |
| `onDialogDismissed` | `void Function(FirebaseUpdateState)?` | Fires when package UI is dismissed |
| `onSnoozed` | `void Function(String, Duration)?` | Fires when optional prompt is snoozed |
| `onVersionSkipped` | `void Function(String)?` | Fires when a version is skipped |
| `allowedFlavors` | `List<String>?` | Whitelist build flavors using `--dart-define=FLAVOR=...` |
| `showSkipVersion` | `bool` | Shows “Skip this version” on optional prompts |
| `snoozeDuration` | `Duration?` | Default snooze duration |
| `preferencesStore` | `FirebaseUpdatePreferencesStore?` | Custom persistence backend for skip/snooze |

Patch support:

| Property | Type | Purpose |
|---|---|---|
| `patchSource` | `FirebaseUpdatePatchSource?` | Integrates Shorebird or another patch provider |
| `onPatchApplied` | `VoidCallback?` | Called after a patch has been applied |

### `FirebaseUpdatePresentation`

Controls the built-in UI system.

| Member | Type | Purpose |
|---|---|---|
| `useBottomSheetForOptionalUpdate` | `bool` | Global default for optional updates |
| `contentAlignment` | `FirebaseUpdateContentAlignment?` | Aligns icon, title, and body |
| `patchNotesAlignment` | `FirebaseUpdateContentAlignment?` | Aligns the patch notes block independently |
| `typography` | `FirebaseUpdateTypography` | Fine-grained text-style overrides |
| `labels` | `FirebaseUpdateLabels` | Override every static string in the default UI |
| `theme` | `FirebaseUpdatePresentationTheme` | Colors, border radius, blur, gradient, layout tokens |
| `iconBuilder` | `FirebaseUpdateIconBuilder?` | Replaces the default top icon |

Supporting presentation objects:

| Object | What it controls |
|---|---|
| `FirebaseUpdatePresentationTheme` | Accent colors, surface colors, outline, barrier, blur, gradients, radii, max dialog width |
| `FirebaseUpdateTypography` | Title, body, release-notes, read-more, and button text styles |
| `FirebaseUpdateLabels` | Titles, CTA text, release-notes labels, skip-version text, patch-ready copy |
| `FirebaseUpdateContentAlignment` | `start`, `center`, `end` |

### Widgets

| Widget | Purpose |
|---|---|
| `FirebaseUpdateBuilder` | Rebuilds on every `FirebaseUpdateState` change so you can render custom inline UI |
| `FirebaseUpdateCard` | Ready-made inline card for optional update, force update, maintenance, and patch states |

Example:

```dart
FirebaseUpdateBuilder(
  builder: (context, state) {
    if (state.kind == FirebaseUpdateKind.optionalUpdate) {
      return FirebaseUpdateCard();
    }
    return const SizedBox.shrink();
  },
)
```

### Supporting Types

| Type | Purpose |
|---|---|
| `FirebaseUpdateKind` | Enum for `idle`, `upToDate`, `optionalUpdate`, `forceUpdate`, `maintenance`, `shorebirdPatch` |
| `FirebaseUpdatePatchNotesFormat` | Enum for `plainText` and `html` patch notes rendering |
| `FirebaseUpdateStoreUrls` | Per-platform fallback URLs: `android`, `ios`, `macos`, `windows`, `linux`, `web` |
| `FirebaseUpdatePatchSource` | Interface for code-push patch providers such as Shorebird |
| `FirebaseUpdatePreferencesStore` | Interface for skip/snooze persistence |
| `SharedPreferencesFirebaseUpdateStore` | Default `shared_preferences` implementation of the persistence store |

---

## Testing

### Unit + widget tests

```bash
flutter test
```

### Real Remote Config integration (requires service account)

A Dart CLI tool in `test/firebase_config/` pushes predefined scenarios directly to Firebase Remote Config, leaving all other parameters untouched. The running app reacts in real time via `onConfigUpdated`.

```bash
cd test/firebase_config

# One-time dependency install
dart pub get

# Push a scenario
dart run update_remote_config.dart optional     # optional update bottom sheet / dialog
dart run update_remote_config.dart force        # force update (blocking)
dart run update_remote_config.dart maintenance  # maintenance mode (blocking)
dart run update_remote_config.dart clear        # back to up-to-date

# Custom Remote Config key
dart run update_remote_config.dart optional --key my_update_key
```

Requires `test/firebase_config/service-account.json` with `firebaseremoteconfig` write permissions.

---

## Keywords

`flutter force update` · `flutter maintenance mode` · `flutter in-app update` · `firebase remote config update` · `flutter app update prompt` · `flutter update dialog` · `flutter update wall` · `flutter app gate` · `real-time update control` · `no-code update control`

---

## License

BSD-3-Clause © [Qoder](https://qoder.in)

---

Made with love in India 🇮🇳
