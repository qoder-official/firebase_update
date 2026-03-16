import 'dart:async';
import 'dart:convert';

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
  static const forceUpdateDialogButton =
      ValueKey<String>('simulator-force-update-dialog');
  static const forceUpdateBottomSheetButton =
      ValueKey<String>('simulator-force-update-sheet');
  static const maintenanceDialogButton =
      ValueKey<String>('simulator-maintenance-dialog');
  static const maintenanceBottomSheetButton =
      ValueKey<String>('simulator-maintenance-sheet');
  static const maintenanceFullscreenButton =
      ValueKey<String>('simulator-maintenance-fullscreen');
  static const optionalUpdateSnoozeButton =
      ValueKey<String>('simulator-optional-update-snooze');
}

Future<void> initializeExampleFirebaseUpdate({
  bool initializeFirebase = true,
  bool useBottomSheetForOptionalUpdate = true,
  bool useBottomSheetForForceUpdate = false,
  bool useBottomSheetForMaintenance = false,
  bool allowDebugBack = false,
  String currentVersion = '2.4.0',
  Duration? snoozeDuration,
  FirebaseUpdateLabels? labels,
  FirebaseUpdatePresentation? presentation,
  FirebaseUpdateViewBuilder? maintenanceWidget,
  FirebaseUpdateBeforePresentCallback? onBeforePresent,
}) async {
  if (initializeFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await FirebaseUpdate.instance.initialize(
    navigatorKey: rootNavigatorKey,
    config: FirebaseUpdateConfig(
      currentVersion: currentVersion,
      allowDebugBack: allowDebugBack,
      useBottomSheetForOptionalUpdate: useBottomSheetForOptionalUpdate,
      useBottomSheetForForceUpdate: useBottomSheetForForceUpdate,
      useBottomSheetForMaintenance: useBottomSheetForMaintenance,
      snoozeDuration: snoozeDuration,
      presentation: presentation ?? _buildDemoPresentation(labels: labels),
      maintenanceWidget: maintenanceWidget,
      onBeforePresent: onBeforePresent,
    ),
  );
}

FirebaseUpdatePresentation _buildDemoPresentation({
  FirebaseUpdateLabels? labels,
  FirebaseUpdateIconBuilder? iconBuilder,
}) {
  return FirebaseUpdatePresentation(
    contentAlignment: FirebaseUpdateContentAlignment.center,
    patchNotesAlignment: FirebaseUpdateContentAlignment.start,
    iconBuilder: iconBuilder,
    labels: labels ?? const FirebaseUpdateLabels(),
    typography: const FirebaseUpdateTypography(
      titleStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      messageStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      primaryButtonStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      secondaryButtonStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
    theme: const FirebaseUpdatePresentationTheme(
      accentColor: Color(0xFFF26532),
      accentForegroundColor: Colors.white,
      surfaceColor: Color(0xFFFFFCFA),
      contentColor: Color(0xFF201511),
      outlineColor: Color(0xFFE9D8D0),
      barrierColor: Color(0x801B1518),
      heroGlowColor: Color(0xFFFFA178),
      noteBackgroundColor: Color(0xFFF8F1EC),
      statusBackgroundColor: Color(0xFFFDE8DB),
      statusForegroundColor: Color(0xFFB25224),
      panelGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x12FFF3EC),
          Color(0x00FFFFFF),
        ],
      ),
      heroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF8155),
          Color(0xFFFFC365),
        ],
      ),
    ),
  );
}

const _longPlainText = 'Redesigned home screen with cleaner navigation bar\n'
    'Dark mode across all screens and components\n'
    '40% faster app startup time\n'
    'New notifications centre with grouped alerts and filters\n'
    'Improved search with smart suggestions and history\n'
    'Offline mode for core reading and browsing features\n'
    'Full VoiceOver and TalkBack accessibility support\n'
    'Fixed checkout edge cases on older Android devices\n'
    'Apple Pay and Google Pay now available in all regions';

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
    '</ul>';

const _maintenanceHeroGifUrl =
    'https://media.giphy.com/media/3orieTfp1MeFLiBQR2/giphy.gif';

FirebaseUpdateBeforePresentCallback precacheExampleNetworkImages(
  List<String> urls,
) {
  return (context, state) async {
    final uniqueUrls = urls.where((url) => url.trim().isNotEmpty).toSet();
    final configuration = createLocalImageConfiguration(context);

    for (final url in uniqueUrls) {
      final stream = NetworkImage(url).resolve(configuration);
      final completer = Completer<void>();
      late final ImageStreamListener listener;

      listener = ImageStreamListener(
        (image, synchronousCall) {
          if (!completer.isCompleted) completer.complete();
          stream.removeListener(listener);
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) completer.complete();
          stream.removeListener(listener);
        },
      );

      stream.addListener(listener);
      await completer.future;
    }
  };
}

FirebaseUpdateBeforePresentCallback precacheExampleMaintenanceMedia() =>
    precacheExampleNetworkImages([_maintenanceHeroGifUrl]);

Widget buildExampleFullscreenMaintenance(
  BuildContext context,
  FirebaseUpdatePresentationData data,
) {
  return _FullScreenMaintenanceDemo(data: data);
}

class FirebaseUpdateExampleApp extends StatelessWidget {
  const FirebaseUpdateExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF26532);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: brand,
      surface: const Color(0xFFF6F3F1),
      onSurface: const Color(0xFF1F1612),
      outlineVariant: const Color(0xFFE2D7D1),
    );

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'firebase_update example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F3F1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1F1612),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE5DCD7)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2D7D1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2D7D1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: brand),
          ),
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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            _Header(),
            SizedBox(height: 16),
            _CurrentStateCard(),
            SizedBox(height: 16),
            _SectionCard(
              title: 'Simulate Remote Config scenarios',
              subtitle:
                  'Preview optional update, force update, maintenance, and snooze flows using local payloads.',
              child: _SimulatorPanel(),
            ),
            SizedBox(height: 16),
            _SectionCard(
              title: 'Long content & custom surfaces',
              subtitle:
                  'Stress-test release notes layout, read-more behavior, and large custom takeover surfaces.',
              child: _LongContentPanel(),
            ),
            SizedBox(height: 16),
            _SectionCard(
              title: 'Live payload tester',
              subtitle: 'Paste JSON and apply it directly to the example app.',
              child: _LiveConfigTester(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'firebase_update',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Example app',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A clean local testbed for the default overlays, patch notes, and payload-driven state changes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6E625B),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5DCD7)),
          ),
          child: Text(
            'v1 demo',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentStateCard extends StatelessWidget {
  const _CurrentStateCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current state',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FirebaseUpdateBuilder(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stateLabel(state.kind),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message ?? 'No active update or maintenance flow.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6E625B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          label: 'app ${state.currentVersion ?? '2.4.0'}',
                        ),
                        _MetaChip(
                          label: 'latest ${state.latestVersion ?? '-'}',
                        ),
                        _MetaChip(
                          label: 'min ${state.minimumVersion ?? '-'}',
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6E625B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SimulatorPanel extends StatelessWidget {
  const _SimulatorPanel();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionTile(
          key: ExampleAppKeys.upToDateButton,
          title: 'Up to date',
          icon: Icons.verified_rounded,
          onTap: () => FirebaseUpdate.instance.applyPayload({
            'min_version': '2.0.0',
            'latest_version': '2.4.0',
          }),
        ),
        _ActionTile(
          key: ExampleAppKeys.optionalUpdateDialogButton,
          title: 'Optional dialog',
          icon: Icons.system_update_alt_rounded,
          onTap: () => _previewPayload(
            useBottomSheetForOptionalUpdate: false,
            payload: {
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A smoother release is ready with cleaner navigation and faster launch times.',
              'patch_notes':
                  'Version 2.6.0 — faster startup, cleaner onboarding, bug fixes.',
              'patch_notes_format': 'text',
            },
          ),
        ),
        _ActionTile(
          key: ExampleAppKeys.optionalUpdateBottomSheetButton,
          title: 'Optional sheet',
          icon: Icons.view_agenda_rounded,
          onTap: () => _previewPayload(
            useBottomSheetForOptionalUpdate: true,
            payload: {
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A smoother release is ready with cleaner navigation and faster launch times.',
              'patch_notes':
                  'Version 2.6.0 — faster startup, cleaner onboarding, bug fixes.',
              'patch_notes_format': 'text',
            },
          ),
        ),
        _ActionTile(
          key: ExampleAppKeys.forceUpdateDialogButton,
          title: 'Force dialog',
          icon: Icons.priority_high_rounded,
          onTap: () => _previewPayload(
            allowDebugBack: true,
            useBottomSheetForForceUpdate: false,
            payload: {
              'min_version': '2.5.0',
              'latest_version': '2.6.0',
              'force_update_message':
                  'This release contains required backend changes and a migration you cannot skip.',
              'patch_notes':
                  '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
              'patch_notes_format': 'html',
            },
          ),
        ),
        _ActionTile(
          key: ExampleAppKeys.forceUpdateBottomSheetButton,
          title: 'Force sheet',
          icon: Icons.vertical_align_top_rounded,
          onTap: () => _previewPayload(
            allowDebugBack: true,
            useBottomSheetForForceUpdate: true,
            payload: {
              'min_version': '2.5.0',
              'latest_version': '2.6.0',
              'force_update_message':
                  'This release contains required backend changes and a migration you cannot skip.',
              'patch_notes':
                  '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
              'patch_notes_format': 'html',
            },
          ),
        ),
        _ActionTile(
          key: ExampleAppKeys.maintenanceDialogButton,
          title: 'Maintenance dialog',
          icon: Icons.build_circle_rounded,
          onTap: () => _previewPayload(
            allowDebugBack: true,
            useBottomSheetForMaintenance: false,
            payload: {
              'maintenance_title': 'Scheduled maintenance',
              'maintenance_message':
                  'We are refining critical services. You will be back shortly.',
            },
          ),
        ),
        _ActionTile(
          key: ExampleAppKeys.maintenanceBottomSheetButton,
          title: 'Maintenance sheet',
          icon: Icons.vertical_align_bottom_rounded,
          onTap: () => _previewPayload(
            allowDebugBack: true,
            useBottomSheetForMaintenance: true,
            payload: {
              'maintenance_title': 'Scheduled maintenance',
              'maintenance_message':
                  'We are refining critical services. You will be back shortly.',
            },
          ),
        ),
        _ActionTile(
          key: ExampleAppKeys.optionalUpdateSnoozeButton,
          title: 'Snooze demo',
          icon: Icons.timer_rounded,
          onTap: () => _previewPayload(
            useBottomSheetForOptionalUpdate: false,
            snoozeDuration: const Duration(seconds: 10),
            labels: const FirebaseUpdateLabels(later: 'Later (10s)'),
            payload: {
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'Tap "Later (10s)" and the dialog returns automatically.',
            },
          ),
        ),
      ],
    );
  }
}

class _LongContentPanel extends StatelessWidget {
  const _LongContentPanel();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SmallButton(
          title: 'Long text dialog',
          onTap: () => _previewPayload(
            useBottomSheetForOptionalUpdate: false,
            payload: {
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longPlainText,
              'patch_notes_format': 'text',
            },
          ),
        ),
        _SmallButton(
          title: 'Long text sheet',
          onTap: () => _previewPayload(
            useBottomSheetForOptionalUpdate: true,
            payload: {
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longPlainText,
              'patch_notes_format': 'text',
            },
          ),
        ),
        _SmallButton(
          title: 'Long HTML dialog',
          onTap: () => _previewPayload(
            useBottomSheetForOptionalUpdate: false,
            payload: {
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longHtml,
              'patch_notes_format': 'html',
            },
          ),
        ),
        _SmallButton(
          title: 'Long HTML sheet',
          onTap: () => _previewPayload(
            useBottomSheetForOptionalUpdate: true,
            payload: {
              'min_version': '2.0.0',
              'latest_version': '2.6.0',
              'optional_update_title': 'Update available',
              'optional_update_message':
                  'A new version is ready with many improvements.',
              'patch_notes': _longHtml,
              'patch_notes_format': 'html',
            },
          ),
        ),
        _SmallButton(
          key: ExampleAppKeys.maintenanceFullscreenButton,
          title: 'Full-screen maintenance',
          onTap: () => _previewPayload(
            allowDebugBack: true,
            useBottomSheetForMaintenance: false,
            maintenanceWidget: buildExampleFullscreenMaintenance,
            onBeforePresent: precacheExampleMaintenanceMedia(),
            payload: {
              'maintenance_title': 'Platform maintenance',
              'maintenance_message':
                  'Core systems are temporarily offline while we roll out backend upgrades.',
            },
          ),
        ),
      ],
    );
  }
}

class _LiveConfigTester extends StatefulWidget {
  const _LiveConfigTester();

  @override
  State<_LiveConfigTester> createState() => _LiveConfigTesterState();
}

class _LiveConfigTesterState extends State<_LiveConfigTester> {
  final _versionController = TextEditingController(text: '2.4.0');
  final _jsonController = TextEditingController(
    text: '{\n'
        '  "min_version": "2.0.0",\n'
        '  "latest_version": "2.6.0",\n'
        '  "optional_update_title": "Update available",\n'
        '  "optional_update_message": "A new version is ready.",\n'
        '  "patch_notes": "Bug fixes and performance improvements.",\n'
        '  "patch_notes_format": "text"\n'
        '}',
  );

  String? _validationError;
  Map<String, dynamic>? _parsedPayload;
  bool _applying = false;

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
  void initState() {
    super.initState();
    _onJsonChanged(_jsonController.text);
  }

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
    } catch (error) {
      setState(() {
        _validationError =
            error.toString().replaceFirst('FormatException: ', '');
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
        allowDebugBack: true,
        currentVersion: version.isEmpty ? '2.4.0' : version,
      );
      await FirebaseUpdate.instance.applyPayload(_parsedPayload!);
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  List<String> get _unknownKeys => _parsedPayload == null
      ? []
      : _parsedPayload!.keys.where((key) => !_knownKeys.contains(key)).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _versionController,
          decoration: const InputDecoration(
            labelText: 'Current app version',
            hintText: '2.4.0',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _jsonController,
          maxLines: 8,
          minLines: 6,
          onChanged: _onJsonChanged,
          style: const TextStyle(
            height: 1.45,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            labelText: 'Remote Config payload (JSON)',
            errorText: _validationError,
            errorMaxLines: 3,
          ),
        ),
        if (_unknownKeys.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Unknown keys (ignored): ${_unknownKeys.join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6E625B),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _parsedPayload != null && !_applying ? _apply : null,
          child: _applying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('Apply & preview'),
        ),
      ],
    );
  }
}

Future<void> _previewPayload({
  required Map<String, dynamic> payload,
  bool useBottomSheetForOptionalUpdate = true,
  bool useBottomSheetForForceUpdate = false,
  bool useBottomSheetForMaintenance = false,
  bool allowDebugBack = false,
  Duration? snoozeDuration,
  FirebaseUpdateLabels? labels,
  FirebaseUpdatePresentation? presentation,
  FirebaseUpdateViewBuilder? maintenanceWidget,
  FirebaseUpdateBeforePresentCallback? onBeforePresent,
}) async {
  await initializeExampleFirebaseUpdate(
    initializeFirebase: false,
    useBottomSheetForOptionalUpdate: useBottomSheetForOptionalUpdate,
    useBottomSheetForForceUpdate: useBottomSheetForForceUpdate,
    useBottomSheetForMaintenance: useBottomSheetForMaintenance,
    allowDebugBack: allowDebugBack,
    snoozeDuration: snoozeDuration,
    labels: labels,
    presentation: presentation,
    maintenanceWidget: maintenanceWidget,
    onBeforePresent: onBeforePresent,
  );
  await FirebaseUpdate.instance.applyPayload(payload);
}

class _FullScreenMaintenanceDemo extends StatelessWidget {
  const _FullScreenMaintenanceDemo({required this.data});

  final FirebaseUpdatePresentationData data;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final title = data.title;
    final message = data.state.message ?? 'The app is temporarily unavailable.';

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFCF8F4),
                  Color(0xFFF4E7DC),
                  Color(0xFFE7D3C5),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -10,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x33FFD29A),
                          Color(0x00FFD29A),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 220,
                  left: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x22FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 84),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1FF26532),
                              borderRadius: BorderRadius.circular(999),
                              border:
                                  Border.all(color: const Color(0x33F26532)),
                            ),
                            child: const Text(
                              'Status: under maintenance',
                              style: TextStyle(
                                color: Color(0xFF9D4A26),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0x1FFFFFFF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 32,
                                offset: Offset(0, 18),
                              ),
                            ],
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  _maintenanceHeroGifUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFFF8C63),
                                            Color(0xFFF2BB6C),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.construction_rounded,
                                          size: 54,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x12000000),
                                        Color(0x66160F0B),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 14,
                                  left: 14,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.16),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cloud_sync_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Core services syncing',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.9,
                                color: const Color(0xFF1F1612),
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                    color: const Color(0xFF544842),
                                  ),
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          children: [
                            Expanded(
                              child: _MaintenanceInfoTile(
                                icon: Icons.schedule_rounded,
                                label: 'Estimated back',
                                value: '~35 min',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _MaintenanceInfoTile(
                                icon: Icons.insights_rounded,
                                label: 'Current mode',
                                value: 'Read-only paused',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.66),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0x1AE0CFC3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0x14F26532),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.support_agent_rounded,
                                  color: Color(0xFFB15326),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Upgrade jobs are running and incident monitors are active. Once checks pass, the app resumes without a client update.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Color(0xFF6B5B53),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceInfoTile extends StatelessWidget {
  const _MaintenanceInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1AE0CFC3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFB15326)),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7C6B62),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF241814),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(14),
          foregroundColor: const Color(0xFF1F1612),
          side: const BorderSide(color: Color(0xFFE2D7D1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F1612),
        side: const BorderSide(color: Color(0xFFE2D7D1)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(title),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2ECE8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6E625B),
            ),
      ),
    );
  }
}

String _stateLabel(FirebaseUpdateKind kind) {
  return switch (kind) {
    FirebaseUpdateKind.forceUpdate => 'Force update',
    FirebaseUpdateKind.maintenance => 'Maintenance',
    FirebaseUpdateKind.optionalUpdate => 'Optional update',
    FirebaseUpdateKind.shorebirdPatch => 'Patch ready',
    FirebaseUpdateKind.upToDate => 'Up to date',
    FirebaseUpdateKind.idle => 'Idle',
  };
}
