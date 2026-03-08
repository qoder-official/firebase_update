import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  test('starts in idle state', () {
    expect(FirebaseUpdate.instance.currentState.kind, FirebaseUpdateKind.idle);
  });

  test('initialize stores config and navigator key', () async {
    final navigatorKey = GlobalKey<NavigatorState>();
    const config = FirebaseUpdateConfig(currentVersion: '2.4.0');

    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: config,
    );

    expect(FirebaseUpdate.instance.navigatorKey, same(navigatorKey));
    expect(FirebaseUpdate.instance.config, same(config));
    expect(
      FirebaseUpdate.instance.currentState.kind,
      FirebaseUpdateKind.upToDate,
    );
  });

  test('applies optional update payload', () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: const FirebaseUpdateConfig(currentVersion: '2.4.0'),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_title': 'Fresh update title',
      'update_message': 'Fresh update body',
      'update_type': 'optional',
      'patch_notes': 'New release available',
      'patch_notes_format': 'text',
    });

    expect(state.kind, FirebaseUpdateKind.optionalUpdate);
    expect(state.latestVersion, '2.6.0');
    expect(state.title, 'Fresh update title');
    expect(state.message, 'Fresh update body');
    expect(state.patchNotes, 'New release available');
  });

  test('maintenance takes precedence over update prompts', () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: const FirebaseUpdateConfig(currentVersion: '2.4.0'),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'maintenance_enabled': true,
      'maintenance_message': 'Service paused',
    });

    expect(state.kind, FirebaseUpdateKind.maintenance);
    expect(state.isBlocking, isTrue);
    expect(state.maintenanceMessage, 'Service paused');
  });

  test('minimum version breach triggers force update', () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: const FirebaseUpdateConfig(currentVersion: '2.4.0'),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
    });

    expect(state.kind, FirebaseUpdateKind.forceUpdate);
    expect(state.minimumVersion, '2.5.0');
  });

  test('realtime listening is enabled by default', () {
    const config = FirebaseUpdateConfig();
    expect(config.listenToRealtimeUpdates, isTrue);
  });

  test('realtime listening can be turned off', () {
    const config = FirebaseUpdateConfig(listenToRealtimeUpdates: false);
    expect(config.listenToRealtimeUpdates, isFalse);
  });

  test('store urls can be configured', () {
    const config = FirebaseUpdateConfig(
      storeUrls: FirebaseUpdateStoreUrls(
        android: 'https://play.google.com/store/apps/details?id=com.qoder.app',
        ios: 'https://apps.apple.com/app/id123456789',
      ),
    );

    expect(
      config.storeUrls.android,
      'https://play.google.com/store/apps/details?id=com.qoder.app',
    );
    expect(config.storeUrls.ios, 'https://apps.apple.com/app/id123456789');
  });
}
