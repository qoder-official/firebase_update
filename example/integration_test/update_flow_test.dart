import 'package:firebase_update/firebase_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:firebase_update_example/example_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  testWidgets('optional dialog can be shown and dismissed in the example app', (
    tester,
  ) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      useBottomSheetForOptionalUpdate: false,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(ExampleAppKeys.optionalUpdateDialogButton),
    );
    await tester.tap(find.byKey(ExampleAppKeys.optionalUpdateDialogButton));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing);
  });

  testWidgets(
    'optional bottom sheet can be shown and dismissed in the example app',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: true,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(ExampleAppKeys.optionalUpdateBottomSheetButton),
      );
      await tester.tap(
        find.byKey(ExampleAppKeys.optionalUpdateBottomSheetButton),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    'force update can escalate after optional update in the example app',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(ExampleAppKeys.optionalUpdateDialogButton),
      );
      await tester.tap(find.byKey(ExampleAppKeys.optionalUpdateDialogButton));
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
    },
  );

  testWidgets(
    'optional update can be dismissed and triggered again in the example app',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(ExampleAppKeys.optionalUpdateDialogButton),
      );
      await tester.tap(find.byKey(ExampleAppKeys.optionalUpdateDialogButton));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      await tester.ensureVisible(
        find.byKey(ExampleAppKeys.optionalUpdateDialogButton),
      );
      await tester.tap(find.byKey(ExampleAppKeys.optionalUpdateDialogButton));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets(
    'maintenance can appear over an active update flow in the example app',
    (tester) async {
      await initializeExampleFirebaseUpdate(
        initializeFirebase: false,
        useBottomSheetForOptionalUpdate: false,
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(ExampleAppKeys.forceUpdateButton));
      await tester.tap(find.byKey(ExampleAppKeys.forceUpdateButton));
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
    },
  );
}
