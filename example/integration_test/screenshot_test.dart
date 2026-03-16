import 'package:firebase_update/firebase_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:firebase_update_example/example_app.dart';

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

Future<void> _captureScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  testWidgets('screenshot: home screen', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();
    await _captureScreenshot(binding, tester, 'home_screen');
  });

  testWidgets('screenshot: optional update dialog', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForOptionalUpdate: false,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'optional_update_title': 'Update available',
      'optional_update_message':
          'Version 2.6.0 is ready with a smoother experience.',
      'patch_notes': 'Faster startup · Cleaner onboarding · Bug fixes.',
      'patch_notes_format': 'text',
    });
    await _waitFor(tester, find.text('Update available'));
    await _captureScreenshot(binding, tester, 'optional_update_dialog');
  });

  testWidgets('screenshot: optional update sheet', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForOptionalUpdate: true,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'optional_update_title': 'Update available',
      'optional_update_message':
          'Version 2.6.0 is ready with a smoother experience.',
      'patch_notes': 'Faster startup · Cleaner onboarding · Bug fixes.',
      'patch_notes_format': 'text',
    });
    await _waitFor(tester, find.text('Update available'));
    await _captureScreenshot(binding, tester, 'optional_update_sheet');
  });

  testWidgets('screenshot: force update dialog', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForForceUpdate: false,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'force_update_message': 'This release contains required security fixes.',
      'patch_notes':
          '<ul><li>Critical security patches</li><li>Required backend compatibility</li></ul>',
      'patch_notes_format': 'html',
    });
    await _waitFor(tester, find.text('Update required'));
    expect(find.text('Debug back'), findsNothing);
    await _captureScreenshot(binding, tester, 'force_update_dialog');
  });

  testWidgets('screenshot: force update sheet', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForForceUpdate: true,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'force_update_message': 'This release contains required security fixes.',
      'patch_notes':
          '<ul><li>Critical security patches</li><li>Required backend compatibility</li></ul>',
      'patch_notes_format': 'html',
    });
    await _waitFor(tester, find.text('Update required'));
    expect(find.text('Debug back'), findsNothing);
    await _captureScreenshot(binding, tester, 'force_update_sheet');
  });

  testWidgets('screenshot: maintenance dialog', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForMaintenance: false,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'maintenance_title': 'Scheduled maintenance',
      'maintenance_message':
          "We're upgrading our servers. We'll be back shortly.",
    });
    await _waitFor(tester, find.text('Scheduled maintenance'));
    expect(find.text('Debug back'), findsNothing);
    await _captureScreenshot(binding, tester, 'maintenance_dialog');
  });

  testWidgets('screenshot: maintenance sheet', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForMaintenance: true,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'maintenance_title': 'Scheduled maintenance',
      'maintenance_message':
          "We're upgrading our servers. We'll be back shortly.",
    });
    await _waitFor(tester, find.text('Scheduled maintenance'));
    expect(find.text('Debug back'), findsNothing);
    await _captureScreenshot(binding, tester, 'maintenance_sheet');
  });

  testWidgets('screenshot: maintenance fullscreen', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForMaintenance: false,
      maintenanceWidget: buildExampleFullscreenMaintenance,
      onBeforePresent: precacheExampleMaintenanceMedia(),
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'maintenance_title': 'Platform maintenance',
      'maintenance_message':
          'Core systems are temporarily offline while we roll out backend upgrades.',
    });
    await _waitFor(tester, find.text('Platform maintenance'));
    expect(find.text('Debug back'), findsNothing);
    await _captureScreenshot(binding, tester, 'maintenance_fullscreen');
  });

  testWidgets('screenshot: patch notes expanded', (tester) async {
    await initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      allowDebugBack: false,
      useBottomSheetForOptionalUpdate: false,
    );
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'optional_update_title': 'Update available',
      'optional_update_message': 'Version 2.6.0 has arrived.',
      'patch_notes': 'Redesigned home screen with cleaner navigation bar\n'
          'Dark mode across all screens and components\n'
          '40% faster app startup time\n'
          'New notifications centre with grouped alerts and filters\n'
          'Improved search with smart suggestions and history\n'
          'Offline mode for core reading and browsing features\n'
          'Full VoiceOver and TalkBack accessibility support\n'
          'Fixed checkout edge cases on older Android devices\n'
          'Apple Pay and Google Pay now available in all regions',
      'patch_notes_format': 'text',
    });
    await _waitFor(tester, find.text('Update available'));
    final readMore = find.text('Read more');
    if (readMore.evaluate().isNotEmpty) {
      await tester.tap(readMore);
      await tester.pumpAndSettle();
    }
    await _captureScreenshot(binding, tester, 'patch_notes_expanded');
  });
}
