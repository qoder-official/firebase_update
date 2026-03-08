import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  testWidgets(
    'update UI appears when applyPayload is called before the widget tree is built',
    (tester) async {
      // This exercises the addPostFrameCallback fallback path that handles
      // the window where the navigatorKey has no context yet because
      // MaterialApp hasn't rendered its first frame.
      final navigatorKey = GlobalKey<NavigatorState>();

      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: const FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          useBottomSheetForOptionalUpdate: false,
        ),
      );

      // Emit a force-update state BEFORE the widget tree exists.
      // The presenter has no context yet and must defer via postFrameCallback.
      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.5.0',
        'latest_version': '2.6.0',
        'update_type': 'force',
      });

      // Build the widget tree now — the deferred callback should fire.
      await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      expect(find.text('Update required'), findsOneWidget);
    },
  );

  testWidgets('optional update sheet appears and can be dismissed', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        currentVersion: '2.4.0',
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_type': 'optional',
      'patch_notes': 'Optional update notes',
      'store_url': 'https://qoder.in/app-update',
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
          currentVersion: '2.4.0',
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
        currentVersion: '2.4.0',
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
        currentVersion: '2.4.0',
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
        currentVersion: '2.4.0',
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
        currentVersion: '2.4.0',
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

  testWidgets(
    'optional update is not re-shown after user dismisses the same version',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: const FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          useBottomSheetForOptionalUpdate: false,
        ),
      );

      await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      // Show the optional update dialog for version 2.6.0.
      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
        'update_type': 'optional',
      });
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);

      // User taps Later — skips version 2.6.0.
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      // Real-time config fires again with the same version — should not re-show.
      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
        'update_type': 'optional',
      });
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    'optional update re-appears when a newer version becomes available after skip',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: const FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          useBottomSheetForOptionalUpdate: false,
        ),
      );

      await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      // Show and skip version 2.6.0.
      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
        'update_type': 'optional',
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // A newer version 2.7.0 is released — dialog should appear again.
      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.7.0',
        'update_type': 'optional',
      });
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets('plain text patch notes truncate and expand with read more', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        useBottomSheetForOptionalUpdate: false,
      ),
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    // Six lines of patch notes — the default collapsed threshold is 5.
    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_type': 'optional',
      'patch_notes': 'Line one\nLine two\nLine three\nLine four\nLine five\nLine six',
    });
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('Line five'), findsOneWidget);
    expect(find.textContaining('Line six'), findsNothing);
    expect(find.text('Read more'), findsOneWidget);

    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Line six'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('html patch notes are rendered without raw html tags', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: const FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        useBottomSheetForOptionalUpdate: false,
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
