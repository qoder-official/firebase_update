import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:firebase_update_example/example_app.dart';

// On a real device the onPressed callback from a button is async and the
// driver's pumpAndSettle cannot observe when it finishes. Poll for a widget
// matching [finder] in short intervals until it appears or the timeout elapses.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  testWidgets(
    'optional update dialog appears and dismisses via Later',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
        'optional_update_title': 'Update available',
        'optional_update_message': 'A new version is ready.',
        'patch_notes': 'Bug fixes and performance improvements.',
        'patch_notes_format': 'text',
      });
      await _waitFor(tester, find.text('Update available'));

      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    'optional update bottom sheet appears and dismisses via Later',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: true,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
        'optional_update_title': 'Update available',
        'optional_update_message': 'A new version is ready.',
        'patch_notes': 'Bug fixes and performance improvements.',
        'patch_notes_format': 'text',
      });
      await _waitFor(tester, find.text('Update available'));

      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    'force update dialog appears via simulator button and blocks dismissal',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForForceUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(ExampleAppKeys.forceUpdateDialogButton),
      );
      await tester.tap(find.byKey(ExampleAppKeys.forceUpdateDialogButton));
      await _waitFor(tester, find.text('Update required'));

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Debug back'), findsOneWidget);
      expect(find.text('Later'), findsNothing);

      await tester.tap(find.text('Debug back'));
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsNothing);
    },
  );

  testWidgets(
    'force update sheet appears via simulator button and blocks dismissal',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForForceUpdate: true,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(ExampleAppKeys.forceUpdateBottomSheetButton),
      );
      await tester.tap(find.byKey(ExampleAppKeys.forceUpdateBottomSheetButton));
      await _waitFor(tester, find.text('Update required'));

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Debug back'), findsOneWidget);
      expect(find.text('Later'), findsNothing);

      await tester.tap(find.text('Debug back'));
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsNothing);
    },
  );

  testWidgets(
    'force update escalates over an active optional update',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
      });
      await _waitFor(tester, find.text('Update available'));
      expect(find.text('Update available'), findsOneWidget);

      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.5.0',
        'latest_version': '2.6.0',
      });
      await _waitFor(tester, find.text('Update required'));

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
    },
  );

  testWidgets(
    'skip-version: same version is not re-shown after Later tap',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
      });
      await _waitFor(tester, find.text('Update available'));
      expect(find.text('Update available'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // Re-emit same version — skip-version must suppress the dialog.
      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
      });
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    'skip-version: newer version re-shows dialog after previous skip',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.6.0',
      });
      await _waitFor(tester, find.text('Update available'));
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // A newer version should clear the skip and prompt again.
      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.0.0',
        'latest_version': '2.7.0',
      });
      await _waitFor(tester, find.text('Update available'));

      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets(
    'maintenance blocks the app and replaces an active force update',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForForceUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(ExampleAppKeys.forceUpdateDialogButton),
      );
      await tester.tap(find.byKey(ExampleAppKeys.forceUpdateDialogButton));
      await _waitFor(tester, find.text('Update required'));
      expect(find.text('Update required'), findsOneWidget);

      await FirebaseUpdate.instance.applyPayload({
        'maintenance_title': 'Scheduled maintenance',
        'maintenance_message': 'Please try again shortly.',
      });
      await _waitFor(tester, find.text('Scheduled maintenance'));

      expect(find.text('Scheduled maintenance'), findsOneWidget);
      expect(find.text('Please try again shortly.'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
    },
  );

  testWidgets(
    'full-screen maintenance example covers the app with a blocking custom surface',
    (tester) async {
      await initializeExampleFirebaseUpdate(initializeFirebase: false);
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      final button = find.byKey(ExampleAppKeys.maintenanceFullscreenButton);
      await tester.dragUntilVisible(
        button,
        find.byType(Scrollable).first,
        const Offset(0, -220),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await _waitFor(
        tester,
        find.text('Platform maintenance'),
        timeout: const Duration(seconds: 15),
      );

      expect(find.text('Platform maintenance'), findsOneWidget);
      expect(find.text('Status: under maintenance'), findsOneWidget);
      expect(find.text('Debug back'), findsOneWidget);

      await tester.tap(find.text('Debug back'));
      await tester.pumpAndSettle();
      expect(find.text('Platform maintenance'), findsNothing);
    },
  );
}
