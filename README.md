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
| Custom field mapping | ✅ | ✗ | ✗ | ✗ |
| Fully custom UI builders | ✅ | partial | ✗ | ✗ |
| iOS + Android | ✅ | ✅ | Android only | ✅ |
| Works without store listing | ✅ | ✗ | ✗ | ✗ |

> You already have Firebase. Now get update control for free.

---

## Features

- **Force update** — blocks app usage when a breaking release is required
- **Optional update** — encourages upgrade via a dismissible dialog or bottom sheet
- **Maintenance mode** — instantly gates the app without shipping a build
- **Patch notes** — plain text or HTML, shown inline or in the update UI
- **Real-time updates** — reacts to Remote Config changes without an app restart
- **Built-in UI** — default dialog and bottom sheet, no setup beyond a `navigatorKey`
- **Custom UI** — replace any surface with your own widget builders
- **Schema mapping** — use your own Remote Config key names
- **`FirebaseUpdateBuilder`** — reactive widget for building your own in-screen update surfaces

---

## Installation

```yaml
dependencies:
  firebase_update: ^0.0.1
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
    config: const FirebaseUpdateConfig(
      remoteConfigKey: 'app_update',
      fields: FirebaseUpdateFieldMapping(
        minimumVersion: 'min_version',
        latestVersion: 'latest_version',
        maintenanceEnabled: 'maintenance_enabled',
        maintenanceMessage: 'maintenance_message',
        updateType: 'update_type',
        patchNotes: 'patch_notes',
        patchNotesFormat: 'patch_notes_format',
        storeUrl: 'store_url',
      ),
    ),
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

Set up a JSON parameter in Firebase Remote Config. The key name (`app_update` in the example above) is whatever you set as `remoteConfigKey`. The field names inside the JSON are whatever you map in `FirebaseUpdateFieldMapping`.

```json
{
  "min_version": "2.0.0",
  "latest_version": "2.3.1",
  "update_type": "optional",
  "maintenance_enabled": false,
  "maintenance_message": "We'll be back shortly.",
  "patch_notes": "• Bug fixes\n• Performance improvements",
  "patch_notes_format": "plain",
  "store_url": ""
}
```

| Field | Type | Description |
|---|---|---|
| `min_version` | string | Minimum version required. Below this → force update. |
| `latest_version` | string | Latest available version. Below this → optional update. |
| `update_type` | string | `"optional"` or `"force"` — overrides version logic if set. |
| `maintenance_enabled` | bool | When `true`, the app enters maintenance mode. |
| `maintenance_title` | string | Title shown on the maintenance screen. |
| `maintenance_message` | string | Message shown on the maintenance screen. |
| `patch_notes` | string | Release notes to show alongside the update prompt. |
| `patch_notes_format` | string | `"plain"` (default) or `"html"`. |
| `store_url` | string | Direct store URL. Falls back to `FirebaseUpdateFallbackStoreUrls` if empty. |

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
  remoteConfigKey: 'app_update',     // Remote Config parameter key
  fields: FirebaseUpdateFieldMapping(...),

  // Optional
  currentVersion: '2.1.0',           // Override auto-detected version
  fetchTimeout: Duration(seconds: 60),
  minimumFetchInterval: Duration(hours: 12),
  listenToRealtimeUpdates: true,      // React to RC changes without restart
  enableDefaultPresentation: true,    // Set false to fully own the UI
  useBottomSheetForOptionalUpdate: true, // false = dialog instead
  fallbackStoreUrls: FirebaseUpdateFallbackStoreUrls(
    android: 'https://play.google.com/store/apps/details?id=com.example.app',
    ios: 'https://apps.apple.com/app/id000000000',
  ),
  presentation: FirebaseUpdatePresentation(...), // Custom UI builders
)
```

---

## Custom UI

Disable the default presentation and supply your own builders per surface:

```dart
FirebaseUpdateConfig(
  remoteConfigKey: 'app_update',
  fields: FirebaseUpdateFieldMapping(minimumVersion: 'min_version'),
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

## Keywords

`flutter force update` · `flutter maintenance mode` · `flutter in-app update` · `firebase remote config update` · `flutter app update prompt` · `flutter update dialog` · `flutter update wall` · `flutter app gate` · `real-time update control` · `no-code update control`

---

## License

BSD-3-Clause © [Qoder](https://qoder.in)
