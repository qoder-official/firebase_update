import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  // ---------------------------------------------------------------------------
  // Core state machine
  // ---------------------------------------------------------------------------

  test('starts in idle state', () {
    expect(FirebaseUpdate.instance.currentState.kind, FirebaseUpdateKind.idle);
  });

  test('initialize stores config and navigator key', () async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final config = FirebaseUpdateConfig(
      currentVersion: '2.4.0',
      preferencesStore: _InMemoryStore(),
    );

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
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        preferencesStore: _InMemoryStore(),
      ),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'update_title': 'Fresh update title',
      'update_message': 'Fresh update body',
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
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        preferencesStore: _InMemoryStore(),
      ),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'maintenance_message': 'Service paused',
    });

    expect(state.kind, FirebaseUpdateKind.maintenance);
    expect(state.isBlocking, isTrue);
    expect(state.maintenanceMessage, 'Service paused');
  });

  test('minimum version breach triggers force update', () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        preferencesStore: _InMemoryStore(),
      ),
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
      fallbackStoreUrls: FirebaseUpdateStoreUrls(
        android: 'https://play.google.com/store/apps/details?id=com.qoder.app',
        ios: 'https://apps.apple.com/app/id123456789',
      ),
    );

    expect(
      config.fallbackStoreUrls.android,
      'https://play.google.com/store/apps/details?id=com.qoder.app',
    );
    expect(
        config.fallbackStoreUrls.ios, 'https://apps.apple.com/app/id123456789');
  });

  // ---------------------------------------------------------------------------
  // v1.0.2 defaults and RC store URLs
  // ---------------------------------------------------------------------------

  test('useBottomSheetForOptionalUpdate defaults to false (dialog)', () {
    const presentation = FirebaseUpdatePresentation();
    expect(presentation.useBottomSheetForOptionalUpdate, isFalse);
  });

  test('RC store URL keys are parsed from payload into state.storeUrls',
      () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        preferencesStore: _InMemoryStore(),
      ),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'store_url_android':
          'https://play.google.com/store/apps/details?id=com.example',
      'store_url_ios': 'https://apps.apple.com/app/id123456789',
    });

    expect(state.kind, FirebaseUpdateKind.optionalUpdate);
    expect(state.storeUrls, isNotNull);
    expect(
      state.storeUrls!.android,
      'https://play.google.com/store/apps/details?id=com.example',
    );
    expect(state.storeUrls!.ios, 'https://apps.apple.com/app/id123456789');
    expect(state.storeUrls!.macos, isNull);
  });

  test('state.storeUrls is null when no store URL keys in payload', () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        preferencesStore: _InMemoryStore(),
      ),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
    });

    expect(state.storeUrls, isNull);
  });

  test('RC store URLs propagate through force update and maintenance states',
      () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        preferencesStore: _InMemoryStore(),
      ),
    );

    final forceState = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
      'store_url_android':
          'https://play.google.com/store/apps/details?id=com.example',
    });
    expect(forceState.kind, FirebaseUpdateKind.forceUpdate);
    expect(
      forceState.storeUrls?.android,
      'https://play.google.com/store/apps/details?id=com.example',
    );

    final maintenanceState = await FirebaseUpdate.instance.applyPayload({
      'maintenance_message': 'Down for maintenance',
      'store_url_android':
          'https://play.google.com/store/apps/details?id=com.example',
    });
    expect(maintenanceState.kind, FirebaseUpdateKind.maintenance);
    expect(
      maintenanceState.storeUrls?.android,
      'https://play.google.com/store/apps/details?id=com.example',
    );
  });

  test('all six RC store URL keys parse correctly', () async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: GlobalKey<NavigatorState>(),
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        preferencesStore: _InMemoryStore(),
      ),
    );

    final state = await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
      'store_url_android': 'https://example.com/android',
      'store_url_ios': 'https://example.com/ios',
      'store_url_macos': 'https://example.com/macos',
      'store_url_windows': 'https://example.com/windows',
      'store_url_linux': 'https://example.com/linux',
      'store_url_web': 'https://example.com/web',
    });

    final urls = state.storeUrls!;
    expect(urls.android, 'https://example.com/android');
    expect(urls.ios, 'https://example.com/ios');
    expect(urls.macos, 'https://example.com/macos');
    expect(urls.windows, 'https://example.com/windows');
    expect(urls.linux, 'https://example.com/linux');
    expect(urls.web, 'https://example.com/web');
  });

  // ---------------------------------------------------------------------------
  // v1.0.1 config defaults
  // ---------------------------------------------------------------------------

  test('snoozeDuration defaults to null (session-only dismiss)', () {
    const config = FirebaseUpdateConfig();
    expect(config.snoozeDuration, isNull);
  });

  test('showSkipVersion defaults to false', () {
    const config = FirebaseUpdateConfig();
    expect(config.showSkipVersion, isFalse);
  });

  test('patchSource defaults to null', () {
    const config = FirebaseUpdateConfig();
    expect(config.patchSource, isNull);
  });

  test('FirebaseUpdateKind includes shorebirdPatch', () {
    expect(
      FirebaseUpdateKind.values,
      contains(FirebaseUpdateKind.shorebirdPatch),
    );
  });

  test('FirebaseUpdateLabels exposes skip and patch labels', () {
    const labels = FirebaseUpdateLabels(
      skipVersion: 'Ignore this release',
      patchAvailableTitle: 'Update ready',
      patchAvailableMessage: 'Restart to apply.',
      applyPatch: 'Apply now',
    );

    expect(labels.skipVersion, 'Ignore this release');
    expect(labels.patchAvailableTitle, 'Update ready');
    expect(labels.patchAvailableMessage, 'Restart to apply.');
    expect(labels.applyPatch, 'Apply now');
  });

  test('FirebaseUpdatePresentationData supports tertiaryLabel and onSkipClick',
      () {
    var tapped = false;
    final data = FirebaseUpdatePresentationData(
      title: 'Test',
      state: const FirebaseUpdateState.idle(),
      isBlocking: false,
      primaryLabel: 'Primary',
      onUpdateClick: () {},
      tertiaryLabel: 'Skip this version',
      onSkipClick: () => tapped = true,
    );

    expect(data.tertiaryLabel, 'Skip this version');
    data.onSkipClick?.call();
    expect(tapped, isTrue);
  });

  test('FirebaseUpdatePresentationData dismiss booleans default to true', () {
    final data = FirebaseUpdatePresentationData(
      title: 'Test',
      state: const FirebaseUpdateState.idle(),
      isBlocking: false,
      primaryLabel: 'Primary',
      onUpdateClick: () {},
    );

    expect(data.dismissOnUpdateClick, isTrue);
    expect(data.dismissOnLaterClick, isTrue);
    expect(data.dismissOnSkipClick, isTrue);
  });

  test('FirebaseUpdatePresentationData.copyWith preserves tertiaryLabel', () {
    var tapped = false;
    final original = FirebaseUpdatePresentationData(
      title: 'Test',
      state: const FirebaseUpdateState.idle(),
      isBlocking: false,
      primaryLabel: 'Primary',
      onUpdateClick: () {},
      tertiaryLabel: 'Skip',
      onSkipClick: () => tapped = true,
    );

    final copied = original.copyWith(title: 'Updated title');
    expect(copied.tertiaryLabel, 'Skip');
    copied.onSkipClick?.call();
    expect(tapped, isTrue);
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _InMemoryStore implements FirebaseUpdatePreferencesStore {
  String? _skippedVersion;
  DateTime? _snoozedUntil;

  @override
  Future<String?> getSkippedVersion() async => _skippedVersion;

  @override
  Future<void> setSkippedVersion(String version) async =>
      _skippedVersion = version;

  @override
  Future<void> clearSkippedVersion() async => _skippedVersion = null;

  @override
  Future<DateTime?> getSnoozedUntil() async => _snoozedUntil;

  @override
  Future<void> setSnoozedUntil(DateTime until) async => _snoozedUntil = until;

  @override
  Future<void> clearSnoozedUntil() async => _snoozedUntil = null;
}
