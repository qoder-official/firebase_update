# firebase_update

> Control your app's update story from Firebase — without shipping a new build.

[![pub.dev](https://img.shields.io/pub/v/firebase_update.svg)](https://pub.dev/packages/firebase_update)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

One package to handle forced updates, optional updates, maintenance mode, and patch notes — with built-in UI, real-time Remote Config listening, and full customization hooks.

**[Full documentation → qoder.in/resources/firebase-update](https://qoder.in/resources/firebase-update)**

---

## Why firebase_update?

Most Flutter update packages scrape the App Store listing or wrap a platform API — they tell you *what version is available*, but they can't tell your app *what to do about it* in real time.

| | firebase_update | upgrader | in_app_update | new_version_plus |
|---|:---:|:---:|:---:|:---:|
| Server-side update control | ✅ | ✗ | ✗ | ✗ |
| Maintenance / kill switch | ✅ | ✗ | ✗ | ✗ |
| Real-time propagation (no restart) | ✅ | ✗ | ✗ | ✗ |
| Patch notes alongside prompt | ✅ | ✗ | ✗ | ✗ |
| Fully custom UI builders | ✅ | partial | ✗ | ✗ |
| iOS + Android | ✅ | ✅ | Android only | ✅ |
| Works without store listing | ✅ | ✗ | ✗ | ✗ |

> You already have Firebase. Now get update control for free.

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
  fetchTimeout: Duration(seconds: 60),
  minimumFetchInterval: Duration(hours: 12),
  listenToRealtimeUpdates: true,         // React to RC changes without restart
  enableDefaultPresentation: true,       // Set false to fully own the UI
  useBottomSheetForOptionalUpdate: true, // false = dialog instead
  storeUrls: FirebaseUpdateStoreUrls(
    android: 'https://play.google.com/store/apps/details?id=com.example.app',
    ios: 'https://apps.apple.com/app/id000000000',
  ),
  presentation: FirebaseUpdatePresentation(...), // Custom UI builders
)
```

---

## Custom UI

Supply your own builders per surface:

```dart
FirebaseUpdateConfig(
  presentation: FirebaseUpdatePresentation(
    forceUpdateDialogBuilder: (context, data) {
      return MyForceUpdateDialog(data: data);
    },
    optionalUpdateBottomSheetBuilder: (context, data) {
      return MyUpdateSheet(data: data);
    },
    maintenanceDialogBuilder: (context, data) {
      return MyMaintenanceScreen(data: data);
    },
  ),
)
```

Each builder receives a `FirebaseUpdatePresentationData` with the resolved title, state, primary/secondary action labels, and tap callbacks — so your widget doesn't need to re-implement the action logic.

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
