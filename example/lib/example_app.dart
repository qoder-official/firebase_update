import 'dart:convert';

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
  static const forceUpdateDialogButton =
      ValueKey<String>('simulator-force-update-dialog');
  static const forceUpdateBottomSheetButton =
      ValueKey<String>('simulator-force-update-sheet');
  static const maintenanceDialogButton =
      ValueKey<String>('simulator-maintenance-dialog');
  static const maintenanceBottomSheetButton =
      ValueKey<String>('simulator-maintenance-sheet');
  static const optionalUpdateSnoozeButton =
      ValueKey<String>('simulator-optional-update-snooze');
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
  bool useBottomSheetForForceUpdate = false,
  bool useBottomSheetForMaintenance = false,
  String currentVersion = '2.4.0',
  Duration? snoozeDuration,
  FirebaseUpdateLabels? labels,
}) async {
  if (initializeFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await FirebaseUpdate.instance.initialize(
    navigatorKey: rootNavigatorKey,
    config: FirebaseUpdateConfig(
      // Pin to a known version so simulator buttons behave predictably
      // regardless of what package_info_plus reads from the build.
      currentVersion: currentVersion,
      useBottomSheetForOptionalUpdate: useBottomSheetForOptionalUpdate,
      useBottomSheetForForceUpdate: useBottomSheetForForceUpdate,
      useBottomSheetForMaintenance: useBottomSheetForMaintenance,
      snoozeDuration: snoozeDuration,
      presentation: labels != null
          ? FirebaseUpdatePresentation(labels: labels)
          : const FirebaseUpdatePresentation(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Long content strings for demo
// ---------------------------------------------------------------------------

const _longPlainText = 'Redesigned home screen with cleaner navigation bar\n'
    'Dark mode across all screens and components\n'
    '40% faster app startup time\n'
    'New notifications centre with grouped alerts and filters\n'
    'Improved search with smart suggestions and history\n'
    'Offline mode for core reading and browsing features\n'
    'Full VoiceOver and TalkBack accessibility support\n'
    'Fixed checkout edge cases on older Android devices\n'
    'Apple Pay and Google Pay now available in all regions\n'
    'Spanish, French, German, and Japanese language support\n'
    'Profile photo editing with crop and colour filters\n'
    'Two-factor authentication with TOTP and SMS options\n'
    'Background sync improvements reduce battery usage\n'
    'New widget support for iOS home screen and lock screen';

const _longHtml = '<ul>'
    '<li>Redesigned home screen with cleaner navigation bar</li>'
    '<li>Dark mode across all screens and components</li>'
    '<li>40% faster app startup time</li>'
    '<li>New notifications centre with grouped alerts</li>'
    '<li>Improved search with smart suggestions</li>'
    '<li>Offline mode for core features</li>'
    '<li>Full VoiceOver and TalkBack accessibility support</li>'
    '<li>Fixed checkout edge cases on older Android devices</li>'
    '<li>Apple Pay and Google Pay in all regions</li>'
    '<li>Spanish, French, German, and Japanese support</li>'
    '<li>Profile photo editing with crop and colour filters</li>'
    '<li>Two-factor authentication: TOTP and SMS options</li>'
    '<li>Background sync improvements for battery life</li>'
    '<li>New widget support for home screen and lock screen</li>'
    '</ul>';

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
        children: [
          // 1. Reactive state display using FirebaseUpdateBuilder
          const _StateCard(),
          const SizedBox(height: 24),

          // 2. Buttons that call applyPayload() to simulate Remote Config changes
          const _SectionHeader('Simulate Remote Config scenarios'),
          const SizedBox(height: 12),
          const _SimulatorPanel(),
          const SizedBox(height: 24),

          // 3. Long content demos (scrollable dialog / sheet)
          const _SectionHeader('Long content demos'),
          const SizedBox(height: 12),
          const _LongContentPanel(),
          const SizedBox(height: 24),

          // 4. Paste raw JSON and preview the result
          const _SectionHeader('Live config tester'),
          const SizedBox(height: 12),
          _LiveConfigTester(),
          const SizedBox(height: 24),
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
              'optional_update_title': 'Update available',
              'optional_update_message': 'A smoother release is ready.',
              'patch_notes':
                  'Version 2.6.0 — faster startup, cleaner onboarding, bug fixes.',
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
              'optional_update_title': 'Update available',
              'optional_update_message': 'A smoother release is ready.',
              'patch_notes':
                  'Version 2.6.0 — faster startup, cleaner onboarding, bug fixes.',
              'patch_notes_format': 'text',
            });
          },
          child: const Text('Optional (sheet)'),
        ),
        FilledButton(
          key: ExampleAppKeys.forceUpdateDialogButton,
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForForceUpdate: false,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.5.0',
              'latest_version': '2.6.0',
              'force_update_message':
                  'This release contains required backend changes.',
              'patch_notes':
                  '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
              'patch_notes_format': 'html',
            });
          },
          child: const Text('Force (dialog)'),
        ),
        FilledButton(
          key: ExampleAppKeys.forceUpdateBottomSheetButton,
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForForceUpdate: true,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.5.0',
              'latest_version': '2.6.0',
              'force_update_message':
                  'This release contains required backend changes.',
              'patch_notes':
                  '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
              'patch_notes_format': 'html',
            });
          },
          child: const Text('Force (sheet)'),
        ),
        OutlinedButton(
          key: ExampleAppKeys.maintenanceDialogButton,
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForMaintenance: false,
            );
            await FirebaseUpdate.instance.applyPayload({
              'maintenance_title': 'Scheduled maintenance',
              'maintenance_message': 'We\'ll be back shortly.',
            });
          },
          child: const Text('Maintenance (dialog)'),
        ),
        OutlinedButton(
          key: ExampleAppKeys.maintenanceBottomSheetButton,
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForMaintenance: true,
            );
            await FirebaseUpdate.instance.applyPayload({
              'maintenance_title': 'Scheduled maintenance',
              'maintenance_message': 'We\'ll be back shortly.',
            });
          },
          child: const Text('Maintenance (sheet)'),
        ),
        OutlinedButton(
          key: ExampleAppKeys.optionalUpdateSnoozeButton,
          onPressed: () async {
            // Re-initialize with a 10 s snooze so you can tap "Later (10s)"
            // and watch the dialog re-appear automatically without restarting.
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: false,
              snoozeDuration: const Duration(seconds: 10),
              labels: const FirebaseUpdateLabels(later: 'Later (10s)'),
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'Tap "Later (10s)" — the dialog comes back in 10 seconds!',
            });
          },
          child: const Text('Optional (snooze 10s)'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Long content demos — show scrollable dialog / sheet with release notes
// ---------------------------------------------------------------------------

class _LongContentPanel extends StatelessWidget {
  const _LongContentPanel();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton(
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: false,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longPlainText,
              'patch_notes_format': 'text',
            });
          },
          child: const Text('Long text (dialog)'),
        ),
        OutlinedButton(
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: true,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longPlainText,
              'patch_notes_format': 'text',
            });
          },
          child: const Text('Long text (sheet)'),
        ),
        OutlinedButton(
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: false,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longHtml,
              'patch_notes_format': 'html',
            });
          },
          child: const Text('Long HTML (dialog)'),
        ),
        OutlinedButton(
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: true,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longHtml,
              'patch_notes_format': 'html',
            });
          },
          child: const Text('Long HTML (sheet)'),
        ),
        OutlinedButton(
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: false,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message': 'A smoother experience is ready.',
            });
          },
          child: const Text('No notes (dialog)'),
        ),
        OutlinedButton(
          onPressed: () async {
            await initializeExampleFirebaseUpdate(
              initializeFirebase: false,
              useBottomSheetForOptionalUpdate: true,
            );
            await FirebaseUpdate.instance.applyPayload({
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message': 'A smoother experience is ready.',
            });
          },
          child: const Text('No notes (sheet)'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Live config tester — paste JSON, edit version, hit Apply
// ---------------------------------------------------------------------------

class _LiveConfigTester extends StatefulWidget {
  @override
  State<_LiveConfigTester> createState() => _LiveConfigTesterState();
}

class _LiveConfigTesterState extends State<_LiveConfigTester> {
  final _versionController = TextEditingController(text: '2.4.0');
  final _jsonController = TextEditingController(
    text: '{\n'
        '  "min_version": "2.0.0",\n'
        '  "latest_version": "2.6.0",\n'
        '  "force_update_title": "",\n'
        '  "force_update_message": "",\n'
        '  "optional_update_title": "Update available",\n'
        '  "optional_update_message": "A new version is ready.",\n'
        '  "maintenance_title": "",\n'
        '  "maintenance_message": "",\n'
        '  "patch_notes": "Bug fixes and performance improvements.",\n'
        '  "patch_notes_format": "text"\n'
        '}',
  );

  String? _validationError;
  Map<String, dynamic>? _parsedPayload;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    // Parse the pre-filled JSON so the Apply button is enabled immediately.
    _onJsonChanged(_jsonController.text);
  }

  static const _knownKeys = {
    'min_version',
    'latest_version',
    'force_update_title',
    'force_update_message',
    'optional_update_title',
    'optional_update_message',
    'maintenance_title',
    'maintenance_message',
    'patch_notes',
    'patch_notes_format',
  };

  @override
  void dispose() {
    _versionController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  void _onJsonChanged(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _validationError = null;
        _parsedPayload = null;
      });
      return;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _validationError = 'Must be a JSON object { ... }';
          _parsedPayload = null;
        });
        return;
      }
      setState(() {
        _validationError = null;
        _parsedPayload = Map<String, dynamic>.from(decoded);
      });
    } catch (e) {
      setState(() {
        _validationError = e.toString().replaceFirst('FormatException: ', '');
        _parsedPayload = null;
      });
    }
  }

  Future<void> _apply() async {
    if (_parsedPayload == null || _applying) return;
    setState(() => _applying = true);
    try {
      final version = _versionController.text.trim();
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        currentVersion: version.isEmpty ? '2.4.0' : version,
      );
      await FirebaseUpdate.instance.applyPayload(_parsedPayload!);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  List<String> get _recognizedKeys => _parsedPayload == null
      ? []
      : _parsedPayload!.keys.where(_knownKeys.contains).toList();

  List<String> get _unknownKeys => _parsedPayload == null
      ? []
      : _parsedPayload!.keys.where((k) => !_knownKeys.contains(k)).toList();

  @override
  Widget build(BuildContext context) {
    final isValid = _parsedPayload != null;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Version override field
        TextField(
          controller: _versionController,
          decoration: const InputDecoration(
            labelText: 'Current app version',
            hintText: '2.4.0',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // JSON payload field
        TextField(
          controller: _jsonController,
          maxLines: 8,
          minLines: 6,
          onChanged: _onJsonChanged,
          decoration: InputDecoration(
            labelText: 'Remote Config payload (JSON)',
            hintText:
                '{\n  "min_version": "2.0.0",\n  "latest_version": "2.6.0"\n}',
            border: const OutlineInputBorder(),
            errorText: _validationError,
            errorMaxLines: 3,
            suffixIcon:
                isValid ? Icon(Icons.check_circle, color: cs.primary) : null,
          ),
        ),

        // Recognized key chips
        if (isValid && _recognizedKeys.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _recognizedKeys
                .map(
                  (k) => Chip(
                    label: Text(k, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                  ),
                )
                .toList(),
          ),
        ],

        // Unknown key warning
        if (_unknownKeys.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Unknown keys (ignored): ${_unknownKeys.join(', ')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],

        const SizedBox(height: 12),
        FilledButton(
          onPressed: isValid && !_applying ? _apply : null,
          child: _applying
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : const Text('Apply & preview'),
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
