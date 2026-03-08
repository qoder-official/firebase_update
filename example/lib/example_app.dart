import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

// ---------------------------------------------------------------------------
// Navigator key — passed to both MaterialApp and FirebaseUpdate.initialize
// ---------------------------------------------------------------------------

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------------------
// Keys for integration tests
// ---------------------------------------------------------------------------

class ExampleAppKeys {
  const ExampleAppKeys._();

  static const upToDateButton = ValueKey<String>('simulator-up-to-date');
  static const optionalUpdateDialogButton = ValueKey<String>(
    'simulator-optional-update-dialog',
  );
  static const optionalUpdateBottomSheetButton = ValueKey<String>(
    'simulator-optional-update-bottom-sheet',
  );
  static const forceUpdateButton = ValueKey<String>('simulator-force-update');
  static const maintenanceButton = ValueKey<String>('simulator-maintenance');
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

/// Initializes Firebase and the firebase_update package.
///
/// [initializeFirebase] can be set to `false` in tests that supply their own
/// Firebase mock or skip the real SDK.
Future<void> initializeExampleFirebaseUpdate({
  bool initializeFirebase = true,
  bool useBottomSheetForOptionalUpdate = true,
}) async {
  if (initializeFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await FirebaseUpdate.instance.initialize(
    navigatorKey: rootNavigatorKey,
    config: FirebaseUpdateConfig(
      // remoteConfigKey defaults to 'firebase_update_config'
      useBottomSheetForOptionalUpdate: useBottomSheetForOptionalUpdate,
    ),
  );
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class FirebaseUpdateExampleApp extends StatelessWidget {
  const FirebaseUpdateExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'firebase_update example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const ExampleHomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('firebase_update')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          // 1. Reactive state display using FirebaseUpdateBuilder
          _StateCard(),
          SizedBox(height: 24),

          // 2. Buttons that call applyPayload() to simulate Remote Config changes
          _SectionHeader('Simulate Remote Config scenarios'),
          SizedBox(height: 12),
          _SimulatorPanel(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. FirebaseUpdateBuilder — reactive state display
// ---------------------------------------------------------------------------

class _StateCard extends StatelessWidget {
  const _StateCard();

  @override
  Widget build(BuildContext context) {
    return FirebaseUpdateBuilder(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current state',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.kind.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (state.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.message!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (state.currentVersion != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'app: ${state.currentVersion}'
                    '  •  latest: ${state.latestVersion ?? '—'}'
                    '  •  min: ${state.minimumVersion ?? '—'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Simulator — calls applyPayload() directly, just like Remote Config would
// ---------------------------------------------------------------------------

class _SimulatorPanel extends StatelessWidget {
  const _SimulatorPanel();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton(
          key: ExampleAppKeys.upToDateButton,
          onPressed: () => FirebaseUpdate.instance.applyPayload({
            'min_version': '2.0.0',
            'latest_version': '2.4.0',
            'update_type': '',
          }),
          child: const Text('Up to date'),
        ),
        OutlinedButton(
          key: ExampleAppKeys.optionalUpdateDialogButton,
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: false,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'update_type': 'optional',
              'optional_update_title': 'Update available',
              'optional_update_message': 'A smoother release is ready.',
              'patch_notes': 'Version 2.6.0 — faster startup, cleaner onboarding, bug fixes.',
              'patch_notes_format': 'text',
            });
          },
          child: const Text('Optional (dialog)'),
        ),
        OutlinedButton(
          key: ExampleAppKeys.optionalUpdateBottomSheetButton,
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: true,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'update_type': 'optional',
              'optional_update_title': 'Update available',
              'optional_update_message': 'A smoother release is ready.',
              'patch_notes': 'Version 2.6.0 — faster startup, cleaner onboarding, bug fixes.',
              'patch_notes_format': 'text',
            });
          },
          child: const Text('Optional (sheet)'),
        ),
        FilledButton(
          key: ExampleAppKeys.forceUpdateButton,
          onPressed: () => FirebaseUpdate.instance.applyPayload({
            'min_version': '2.5.0',
            'latest_version': '2.6.0',
            'update_type': 'force',
            'force_update_message': 'This release contains required backend changes.',
            'patch_notes':
                '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
            'patch_notes_format': 'html',
          }),
          child: const Text('Force update'),
        ),
        OutlinedButton(
          key: ExampleAppKeys.maintenanceButton,
          onPressed: () => FirebaseUpdate.instance.applyPayload({
            'maintenance_enabled': true,
            'maintenance_title': 'Scheduled maintenance',
            'maintenance_message': 'We\'ll be back shortly.',
          }),
          child: const Text('Maintenance'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
