import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
      remoteConfigKey: 'app_update',
      currentVersion: '2.4.0',
      useBottomSheetForOptionalUpdate: useBottomSheetForOptionalUpdate,
      fields: FirebaseUpdateFieldMapping(
        minimumVersion: 'min_version',
        latestVersion: 'latest_version',
        updateTitle: 'update_title',
        updateMessage: 'update_message',
        forceUpdateTitle: 'force_update_title',
        forceUpdateMessage: 'force_update_message',
        optionalUpdateTitle: 'optional_update_title',
        optionalUpdateMessage: 'optional_update_message',
        maintenanceEnabled: 'maintenance_enabled',
        maintenanceTitle: 'maintenance_title',
        maintenanceMessage: 'maintenance_message',
        updateType: 'update_type',
        patchNotes: 'patch_notes',
        patchNotesFormat: 'patch_notes_format',
        storeUrl: 'store_url',
      ),
    ),
  );
}

class FirebaseUpdateExampleApp extends StatelessWidget {
  const FirebaseUpdateExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFF7F1E8);
    const ink = Color(0xFF1F2937);
    const accent = Color(0xFFD97706);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Firebase Update Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: cream,
        ),
        scaffoldBackgroundColor: cream,
        textTheme: Typography.blackMountainView.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F1E8), Color(0xFFF3E2C2), Color(0xFFE9C88B)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'firebase_update',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Example app shell for Qoder\'s Firebase-controlled in-app update package.',
                style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 24),
              FirebaseUpdateBuilder(
                builder: (context, state) {
                  return _StatusCard(state: state);
                },
              ),
              const SizedBox(height: 20),
              const _SectionTitle('State Simulator (Local Overrides)'),
              const SizedBox(height: 12),
              const _SimulatorPanel(),
              const SizedBox(height: 20),
              const _SectionTitle('Planned Remote Config Contract'),
              const SizedBox(height: 12),
              const _CodeCard(
                code: '''
root key: app_update

{
  "min_version": "2.4.0",
  "latest_version": "2.6.0",
  "force_update_title": "Update required",
  "force_update_message": "A critical release is needed before the app can continue.",
  "update_type": "force",
  "maintenance_enabled": false,
  "patch_notes": "<ul><li>Security improvements</li></ul>",
  "patch_notes_format": "html",
  "store_url": "https://qoder.in/app-update"
}
''',
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Planned Package Surface'),
              const SizedBox(height: 12),
              const _FeatureGrid(),
              const SizedBox(height: 20),
              const _SectionTitle('Current Reality'),
              const SizedBox(height: 12),
              const _InfoCard(
                title: 'Implementation stage',
                body:
                    'This example now initializes Firebase, lets the package read the installed app version automatically, and prepares the runtime for Remote Config-backed state updates. Package-managed presentation flows are next.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Next step is package-managed dialogs, sheets, and maintenance screens.',
                      ),
                    ),
                  );
                },
                child: const Text('Check planned next step'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final FirebaseUpdateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Runtime state',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            state.kind.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            state.message ??
                'Waiting for the real Remote Config integration to land.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.5,
            ),
          ),
          if (state.currentVersion != null) ...[
            const SizedBox(height: 12),
            Text(
              'Current: ${state.currentVersion}  Latest: ${state.latestVersion ?? '-'}  Min: ${state.minimumVersion ?? '-'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimulatorPanel extends StatelessWidget {
  const _SimulatorPanel();

  Future<void> _applyUpToDate() {
    return FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.4.0',
      'update_title': 'Everything is current',
      'update_message': 'This simulator state confirms the package is idle.',
      'update_type': 'optional',
      'patch_notes': 'You are already on the current release.',
      'patch_notes_format': 'text',
    });
  }

  Future<void> _applyOptionalUpdate({required bool useBottomSheet}) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      useBottomSheetForOptionalUpdate: useBottomSheet,
    );
    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'optional_update_title': useBottomSheet
          ? 'Update available in a sheet'
          : 'Update available in a dialog',
      'optional_update_message':
          'A smoother release is ready. You can update now or come back later.',
      'update_type': 'optional',
      'patch_notes':
          'Version 2.6.0 adds faster startup, cleaner onboarding, and bug fixes.',
      'patch_notes_format': 'text',
      'store_url': 'https://qoder.in/app-update',
    });
  }

  Future<void> _applyForceUpdate() {
    return FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'force_update_title': 'Update required',
      'force_update_message':
          'This release contains required backend compatibility changes.',
      'update_type': 'force',
      'patch_notes':
          '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
      'patch_notes_format': 'html',
      'store_url': 'https://qoder.in/app-update',
    });
  }

  Future<void> _applyMaintenance() {
    return FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'maintenance_enabled': true,
      'maintenance_title': 'Scheduled maintenance',
      'maintenance_message':
          'Qoder is deploying infrastructure improvements. Please try again shortly.',
      'patch_notes_format': 'text',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonal(
          key: ExampleAppKeys.upToDateButton,
          onPressed: _applyUpToDate,
          child: const Text('Up to date'),
        ),
        FilledButton.tonal(
          key: ExampleAppKeys.optionalUpdateDialogButton,
          onPressed: () => _applyOptionalUpdate(useBottomSheet: false),
          child: const Text('Optional dialog'),
        ),
        FilledButton.tonal(
          key: ExampleAppKeys.optionalUpdateBottomSheetButton,
          onPressed: () => _applyOptionalUpdate(useBottomSheet: true),
          child: const Text('Optional sheet'),
        ),
        FilledButton(
          key: ExampleAppKeys.forceUpdateButton,
          onPressed: _applyForceUpdate,
          child: const Text('Force update'),
        ),
        OutlinedButton(
          key: ExampleAppKeys.maintenanceButton,
          onPressed: _applyMaintenance,
          child: const Text('Maintenance'),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _InfoCard(
          title: 'Force update',
          body: 'Block app usage when a minimum supported version is breached.',
        ),
        _InfoCard(
          title: 'Optional update',
          body:
              'Encourage upgrade through a sheet or dialog without hard blocking.',
        ),
        _InfoCard(
          title: 'Maintenance mode',
          body:
              'Flip a Firebase flag and move the app into a blocking maintenance state.',
        ),
        _InfoCard(
          title: 'Patch notes',
          body:
              'Support text and HTML, including read-more expansion for long notes.',
        ),
        _InfoCard(
          title: 'Custom UI',
          body:
              'Use package defaults or provide your own widgets with normalized state.',
        ),
        _InfoCard(
          title: 'Realtime',
          body:
              'Subscribe to Remote Config changes while the app remains open.',
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5D4B7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SelectableText(
        code.trim(),
        style: const TextStyle(
          color: Color(0xFFF9FAFB),
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
