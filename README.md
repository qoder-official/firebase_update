# Firebase Update

> **Real-time in-app updates and maintenance mode for Flutter apps using Firebase Remote Config**. The goal is simple: one package, low setup friction, customizable UI, and a clean path from basic update prompts to a complete release-control layer.

## Table of Contents

- [Quick Start](#quick-start)
- [Vision](#vision)
- [Key Features](#key-features)
- [What You Get](#what-you-get)
- [Documentation Index](#documentation-index)
- [Planned Package Structure](#planned-package-structure)
- [Planned Public API](#planned-public-api)
- [Implementation Status](#implementation-status)
- [Roadmap](#roadmap)

## Quick Start

The package is still in planning and implementation mode, but this is the target integration experience:

```dart
import 'package:firebase_update/firebase_update.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> bootstrap() async {
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
}
```

The intended result:

- The package listens for Remote Config changes.
- It decides whether the app is up to date, needs an optional update, needs a forced update, or should enter maintenance mode.
- It can present package-provided UI globally through the app `navigatorKey`.
- It can also expose update state reactively so features can render their own UI.

## Vision

`firebase_update` is being built as a Firebase-native control layer for Flutter apps that already use Firebase and want a better update story than ad hoc Remote Config parsing.

The package should make these use cases straightforward:

- Force updates that block app usage when a breaking release is required.
- Optional updates that encourage upgrade without fully interrupting the user.
- Maintenance mode that can shut off usage quickly without shipping a new build.
- Patch notes that can be shown inline, in dialogs, or in bottom sheets.
- Real-time update propagation through Firebase Remote Config listeners.
- Fully custom presentation where the package provides the data and lifecycle, while the app owns the UI.

## Key Features

### Core package goals

- Real-time Remote Config listening for update and maintenance changes.
- Global presentation with only a `navigatorKey`.
- Optional and forced update flows.
- Maintenance mode as a first-class blocking state.
- Patch notes with plain text or HTML support.
- Schema mapping so teams can keep their own Remote Config key names.
- Builder-based reactive widgets for in-screen update surfaces.
- Custom dialog, bottom sheet, and full-screen presentation hooks.

### Developer-experience goals

- Minimal setup for teams that already completed Firebase setup.
- Strong defaults for common update flows.
- Incremental adoption: use the global listener, or just the builder, or both.
- A package structure and docs style consistent with Qoder's other Firebase package work.

## What You Get

The package is intended to scale in layers:

- **Always-on core**: state parsing, version comparison, Remote Config subscription, stream-based update events.
- **Global UX layer**: show an update dialog, bottom sheet, or maintenance screen without passing `BuildContext` around the app.
- **Reactive UI layer**: `FirebaseUpdateBuilder` and related widgets for inline notices, settings screens, and release note surfaces.
- **Customization layer**: map your own schema, inject your own widgets, own your own visuals, and decide how aggressive the UX should be.

## Documentation Index

Use the README as the landing page. The deeper planning and implementation docs live under `documentation/`.

- [Documentation barrel](documentation/index.md)
- [Product vision](documentation/vision.md)
- [Full package plan](documentation/plan.md)
- [Manual implementation example](documentation/manual-implementation-example.md)
- [Current status](documentation/status.md)
- [Current features](documentation/current-features.md)
- [Roadmap](documentation/roadmap.md)
- [Architecture plan](documentation/architecture.md)
- [Configuration schema plan](documentation/configuration-schema.md)
- [Implementation plan](documentation/implementation-plan.md)
- [Feature: In-app updates](documentation/features/in-app-updates.md)
- [Feature: Maintenance mode](documentation/features/maintenance-mode.md)
- [Feature: Patch notes](documentation/features/patch-notes.md)
- [Feature: Custom UI](documentation/features/custom-ui.md)
- [Feature: Realtime updates](documentation/features/realtime-updates.md)
- [Feature: FirebaseUpdateBuilder](documentation/features/firebase-update-builder.md)

## Planned Package Structure

The structure should follow the same documentation-first discipline used in `reference/firebase_messaging_handler`, while staying smaller and focused on update orchestration.

```text
lib/
  firebase_update.dart
  src/
    core/
    config/
    models/
    services/
    presentation/
    widgets/
    utils/

documentation/
  index.md
  vision.md
  status.md
  roadmap.md
  architecture.md
  configuration-schema.md
  implementation-plan.md
  features/
    in-app-updates.md
    maintenance-mode.md
    patch-notes.md
    custom-ui.md
    realtime-updates.md
    firebase-update-builder.md
```

## Planned Public API

The public API should stay narrow and ergonomic.

```dart
class FirebaseUpdate {
  static FirebaseUpdate get instance;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required FirebaseUpdateConfig config,
  });

  Stream<FirebaseUpdateState> get stream;
  FirebaseUpdateState get currentState;
  Future<void> checkNow();
}

class FirebaseUpdateBuilder extends StatelessWidget {
  const FirebaseUpdateBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    FirebaseUpdateState state,
  ) builder;
}
```

Final API names can move, but the shape should remain simple.

## Implementation Status

Current state of the repository:

- Core production package code now exists.
- Remote Config-backed runtime plumbing is partially implemented.
- Default package-managed presentation exists, but still needs major design and customization upgrades.
- Documentation remains the active source of truth for implementation sequencing.

See [documentation/status.md](documentation/status.md) for the detailed status log.

## Roadmap

Near-term priorities:

1. Replace the placeholder package scaffold with real library structure.
2. Implement config parsing and schema mapping.
3. Add Remote Config subscription and state stream handling.
4. Build global presentation flows for optional update, forced update, and maintenance.
5. Add patch note rendering and `FirebaseUpdateBuilder`.
6. Write examples, tests, and setup docs once the API is stable.

Detailed milestone planning lives in [documentation/roadmap.md](documentation/roadmap.md).
