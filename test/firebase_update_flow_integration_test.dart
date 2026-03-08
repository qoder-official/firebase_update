import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  testWidgets('optional update sheet appears and can be dismissed', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        remoteConfigKey: 'app_update',
        currentVersion: '2.4.0',
        fields: FirebaseUpdateFieldMapping(
          minimumVersion: 'min_version',
          latestVersion: 'latest_version',
          updateType: 'update_type',
          patchNotes: 'patch_notes',
          storeUrl: 'store_url',
        ),
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_type': 'optional',
      'patch_notes': 'Optional update notes',
      'store_url': 'https://qoder.com/app-update',
    });
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing);
  });

  testWidgets(
    'null payload does not show a prompt when no update data exists',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: const FirebaseUpdateConfig(
          remoteConfigKey: 'app_update',
          currentVersion: '2.4.0',
          fields: FirebaseUpdateFieldMapping(
            minimumVersion: 'min_version',
            latestVersion: 'latest_version',
            maintenanceEnabled: 'maintenance_enabled',
          ),
        ),
      );

      await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(null);
      await tester.pumpAndSettle();

      expect(
        FirebaseUpdate.instance.currentState.kind,
        FirebaseUpdateKind.upToDate,
      );
      expect(find.text('Update available'), findsNothing);
      expect(find.text('Update required'), findsNothing);
      expect(find.text('Maintenance in progress'), findsNothing);
    },
  );

  testWidgets('force update escalates on top of optional update', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        remoteConfigKey: 'app_update',
        currentVersion: '2.4.0',
        fields: FirebaseUpdateFieldMapping(
          minimumVersion: 'min_version',
          latestVersion: 'latest_version',
          updateType: 'update_type',
        ),
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_type': 'optional',
    });
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'update_type': 'force',
    });
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('optional update can be dismissed and shown again', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        remoteConfigKey: 'app_update',
        currentVersion: '2.4.0',
        fields: FirebaseUpdateFieldMapping(
          minimumVersion: 'min_version',
          latestVersion: 'latest_version',
          updateType: 'update_type',
        ),
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_type': 'optional',
    });
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.7.0',
      'update_type': 'optional',
    });
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('custom optional-update dialog builder can replace package UI', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: FirebaseUpdateConfig(
        remoteConfigKey: 'app_update',
        currentVersion: '2.4.0',
        fields: const FirebaseUpdateFieldMapping(
          minimumVersion: 'min_version',
          latestVersion: 'latest_version',
          updateType: 'update_type',
        ),
        useBottomSheetForOptionalUpdate: false,
        presentation: FirebaseUpdatePresentation(
          optionalUpdateDialogBuilder: (context, data) {
            return AlertDialog(
              title: const Text('Qoder custom update'),
              content: Text(data.state.message ?? 'No message'),
              actions: [
                TextButton(
                  onPressed: data.onSecondaryTap,
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: data.onPrimaryTap,
                  child: const Text('Install'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_type': 'optional',
    });
    await tester.pumpAndSettle();

    expect(find.text('Qoder custom update'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Release notes'), findsNothing);
  });

  testWidgets('maintenance can be shown over an active update flow', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        remoteConfigKey: 'app_update',
        currentVersion: '2.4.0',
        fields: FirebaseUpdateFieldMapping(
          minimumVersion: 'min_version',
          latestVersion: 'latest_version',
          maintenanceEnabled: 'maintenance_enabled',
          maintenanceTitle: 'maintenance_title',
          maintenanceMessage: 'maintenance_message',
        ),
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
    });
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);

    await FirebaseUpdate.instance.applyPayload({
      'maintenance_enabled': true,
      'maintenance_title': 'Scheduled maintenance',
      'maintenance_message': 'Please try again shortly.',
    });
    await tester.pumpAndSettle();

    expect(find.text('Scheduled maintenance'), findsOneWidget);
    expect(find.text('Please try again shortly.'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('html patch notes are rendered without raw html tags', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        remoteConfigKey: 'app_update',
        currentVersion: '2.4.0',
        useBottomSheetForOptionalUpdate: false,
        fields: FirebaseUpdateFieldMapping(
          minimumVersion: 'min_version',
          latestVersion: 'latest_version',
          updateType: 'update_type',
          patchNotes: 'patch_notes',
          patchNotesFormat: 'patch_notes_format',
        ),
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'update_type': 'force',
      'patch_notes':
          '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
      'patch_notes_format': 'html',
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('<ul>'), findsNothing);
    expect(find.textContaining('Security fixes'), findsOneWidget);
    expect(
      find.textContaining('Required backend compatibility changes'),
      findsOneWidget,
    );
  });
}

class _HarnessApp extends StatelessWidget {
  const _HarnessApp({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: SizedBox.expand()),
    );
  }
}
