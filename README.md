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

![Optional update dialog](screenshots/optional_update_dialog.png)

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

![Force update dialog](screenshots/force_update_dialog.png)

### Maintenance Mode

Use this when you need to temporarily gate the app without shipping a new build.

```json
{
  "maintenance_title": "Scheduled maintenance",
  "maintenance_message": "We're upgrading our servers. We'll be back shortly."
}
```

![Maintenance dialog](screenshots/maintenance_dialog.png)

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

```dart
// Initialize once at app startup
await FirebaseUpdate.instance.initialize(
  navigatorKey: navigatorKey,
  config: config,
);

// Force an immediate Remote Config fetch and re-evaluate state
await FirebaseUpdate.instance.checkNow();

// Current state (synchronous)
FirebaseUpdateState state = FirebaseUpdate.instance.currentState;

// Reactive stream of state changes
Stream<FirebaseUpdateState> stream = FirebaseUpdate.instance.stream;

// Apply a raw payload manually (useful for testing or custom sources)
await FirebaseUpdate.instance.applyPayload({'min_version': '2.0.0', ...});
```

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
