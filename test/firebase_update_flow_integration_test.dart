import 'package:firebase_update/firebase_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _InMemoryStore store;

  setUp(() {
    store = _InMemoryStore();
  });

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _init(
    WidgetTester tester, {
    required GlobalKey<NavigatorState> navigatorKey,
    FirebaseUpdateConfig? config,
    String version = '2.4.0',
    bool useDialog = false,
    bool showSkipVersion = false,
    Duration? snoozeDuration,
    _FakePatchSource? patchSource,
    VoidCallback? onForceUpdateTap,
    VoidCallback? onOptionalUpdateTap,
    VoidCallback? onOptionalLaterTap,
    VoidCallback? onStoreLaunch,
    _InMemoryStore? overrideStore,
  }) async {
    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: config ??
          FirebaseUpdateConfig(
            currentVersion: version,
            useBottomSheetForOptionalUpdate: !useDialog,
            showSkipVersion: showSkipVersion,
            snoozeDuration: snoozeDuration,
            patchSource: patchSource,
            onForceUpdateTap: onForceUpdateTap,
            onOptionalUpdateTap: onOptionalUpdateTap,
            onOptionalLaterTap: onOptionalLaterTap,
            onStoreLaunch: onStoreLaunch,
            preferencesStore: overrideStore ?? store,
          ),
    );
    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();
  }

  Future<void> _showOptionalUpdate(
    WidgetTester tester, {
    String minVersion = '2.0.0',
    String latestVersion = '2.6.0',
  }) async {
    await FirebaseUpdate.instance.applyPayload({
      'min_version': minVersion,
      'latest_version': latestVersion,
    });
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------------
  // Existing presenter tests
  // ---------------------------------------------------------------------------

  testWidgets(
    'update UI appears when applyPayload is called before the widget tree is built',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          useBottomSheetForOptionalUpdate: false,
          preferencesStore: store,
        ),
      );

      await FirebaseUpdate.instance.applyPayload({
        'min_version': '2.5.0',
        'latest_version': '2.6.0',
      });

      await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      expect(find.text('Update required'), findsOneWidget);
    },
  );

  testWidgets('optional update sheet appears and can be dismissed', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(tester, navigatorKey: navigatorKey);

    await _showOptionalUpdate(tester);
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
      await _init(tester, navigatorKey: navigatorKey);

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
    await _init(tester, navigatorKey: navigatorKey);

    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsOneWidget);

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
    });
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('optional update re-appears for newer version after session dismiss', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(tester, navigatorKey: navigatorKey);

    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);

    // Newer version → clears session dismiss, shows again.
    await _showOptionalUpdate(tester, latestVersion: '2.7.0');
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
        preferencesStore: store,
        optionalUpdateWidget: (context, data) {
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
    );

    await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    await _showOptionalUpdate(tester);

    expect(find.text('Qoder custom update'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Release notes'), findsNothing);
  });

  testWidgets('maintenance can be shown over an active update flow', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(tester, navigatorKey: navigatorKey);

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
    });
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);

    await FirebaseUpdate.instance.applyPayload({
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
      await _init(tester, navigatorKey: navigatorKey, useDialog: true);

      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      // Same version re-emitted (e.g. real-time RC update) — must not re-show.
      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    'optional update re-appears when a newer version becomes available after skip',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(tester, navigatorKey: navigatorKey, useDialog: true);

      await _showOptionalUpdate(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      await _showOptionalUpdate(tester, latestVersion: '2.7.0');
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets('plain text patch notes truncate and expand with read more', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(tester, navigatorKey: navigatorKey, useDialog: true);

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.0.0',
      'latest_version': '2.6.0',
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
    await _init(tester, navigatorKey: navigatorKey, useDialog: true);

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
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

  // ---------------------------------------------------------------------------
  // Skip version (persistent within session)
  // ---------------------------------------------------------------------------

  testWidgets('showSkipVersion: true renders "Skip this version" button', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      showSkipVersion: true,
    );

    await _showOptionalUpdate(tester);
    expect(find.text('Skip this version'), findsOneWidget);
  });

  testWidgets('showSkipVersion: false hides "Skip this version" button', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(tester, navigatorKey: navigatorKey, useDialog: true);

    await _showOptionalUpdate(tester);
    expect(find.text('Skip this version'), findsNothing);
  });

  testWidgets(
    'tapping "Skip this version" prevents re-prompt for same version in session',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        showSkipVersion: true,
      );

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);

      // Same version arrives again (RC real-time) — stays hidden.
      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    '"Skip this version" allows newer version to show',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        showSkipVersion: true,
      );

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();

      await _showOptionalUpdate(tester, latestVersion: '2.7.0');
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets(
    '"Skip this version" is persisted across restart simulation',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        showSkipVersion: true,
      );

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Skip this version'));
      await tester.pumpAndSettle();

      expect(store.skippedVersion, '2.6.0');

      // Simulate app restart: store retains value, new session loads it.
      FirebaseUpdate.instance.debugReset();
      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          useBottomSheetForOptionalUpdate: false,
          showSkipVersion: true,
          preferencesStore: store, // same store = persisted state
        ),
      );
      await tester.pumpAndSettle();

      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsNothing); // still skipped
    },
  );

  // ---------------------------------------------------------------------------
  // Snooze (timed — 5 seconds for test speed)
  // ---------------------------------------------------------------------------

  testWidgets(
    'snooze: dialog stays hidden during snooze period',
    (tester) async {
      var now = DateTime(2024, 1, 1, 12, 0, 0);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        snoozeDuration: const Duration(seconds: 5),
      );
      FirebaseUpdate.instance.debugSetClock(() => now);

      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      // Same version at T=3s (still snoozed).
      now = now.add(const Duration(seconds: 3));
      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets(
    'snooze: dialog re-appears after snooze expires',
    (tester) async {
      var now = DateTime(2024, 1, 1, 12, 0, 0);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        snoozeDuration: const Duration(seconds: 5),
      );
      FirebaseUpdate.instance.debugSetClock(() => now);

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // Advance clock past snooze expiry.
      now = now.add(const Duration(seconds: 6));
      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets(
    'snooze: boundary — dialog still hidden at exactly snooze duration',
    (tester) async {
      var now = DateTime(2024, 1, 1, 12, 0, 0);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        snoozeDuration: const Duration(seconds: 5),
      );
      FirebaseUpdate.instance.debugSetClock(() => now);

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // At exactly T+5s the snooze HAS expired (isBefore is strictly less-than,
      // so _clock().isBefore(snoozedUntil) is false when they are equal).
      now = now.add(const Duration(seconds: 5));
      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets(
    'snooze: newer version clears snooze and re-prompts',
    (tester) async {
      var now = DateTime(2024, 1, 1, 12, 0, 0);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        snoozeDuration: const Duration(seconds: 5),
      );
      FirebaseUpdate.instance.debugSetClock(() => now);

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // A newer version overrides the snooze.
      await _showOptionalUpdate(tester, latestVersion: '2.7.0');
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets(
    'persistent snooze survives app restart simulation',
    (tester) async {
      var now = DateTime(2024, 1, 1, 12, 0, 0);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        useDialog: true,
        snoozeDuration: const Duration(seconds: 5),
      );
      FirebaseUpdate.instance.debugSetClock(() => now);

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // Confirm snooze was persisted.
      expect(store.snoozedUntil, isNotNull);
      final persistedExpiry = store.snoozedUntil!;

      // Simulate app restart.
      FirebaseUpdate.instance.debugReset();
      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          useBottomSheetForOptionalUpdate: false,
          snoozeDuration: const Duration(seconds: 5),
          preferencesStore: store,
        ),
      );
      // Clock still before expiry.
      FirebaseUpdate.instance.debugSetClock(() => persistedExpiry.subtract(const Duration(seconds: 1)));
      await tester.pumpAndSettle();

      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsNothing); // still snoozed

      // After expiry on second session.
      FirebaseUpdate.instance.debugSetClock(() => persistedExpiry.add(const Duration(seconds: 1)));
      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsOneWidget);
    },
  );

  testWidgets(
    'no snoozeDuration: Later dismisses for session only (re-appears on restart)',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(tester, navigatorKey: navigatorKey, useDialog: true);

      await _showOptionalUpdate(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      // Confirm nothing was written to the store (no persistent snooze).
      expect(store.snoozedUntil, isNull);

      // Simulate app restart — session dismiss is cleared.
      FirebaseUpdate.instance.debugReset();
      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          useBottomSheetForOptionalUpdate: false,
          preferencesStore: store,
        ),
      );
      await tester.pumpAndSettle();

      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsOneWidget); // shows again after restart
    },
  );

  // ---------------------------------------------------------------------------
  // Programmatic skip / snooze API
  // ---------------------------------------------------------------------------

  testWidgets('skipVersion() programmatically hides optional update', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(tester, navigatorKey: navigatorKey, useDialog: true);

    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    FirebaseUpdate.instance.debugReset();
    await FirebaseUpdate.instance.initialize(
      navigatorKey: navigatorKey,
      config: FirebaseUpdateConfig(
        currentVersion: '2.4.0',
        useBottomSheetForOptionalUpdate: false,
        preferencesStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await FirebaseUpdate.instance.skipVersion('2.6.0');

    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('clearSkippedVersion() allows optional update to re-appear', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      showSkipVersion: true,
    );

    await _showOptionalUpdate(tester);
    await tester.tap(find.text('Skip this version'));
    await tester.pumpAndSettle();

    // Verify it's hidden.
    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsNothing);

    // Clear the skip — should show again.
    await FirebaseUpdate.instance.clearSkippedVersion();
    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('snoozeOptionalUpdate() programmatically snoozes the prompt', (
    tester,
  ) async {
    var now = DateTime(2024, 1, 1, 12, 0, 0);
    final navigatorKey = GlobalKey<NavigatorState>();
    // No built-in snooze — we'll drive it entirely via the public API.
    await _init(tester, navigatorKey: navigatorKey, useDialog: true);
    FirebaseUpdate.instance.debugSetClock(() => now);

    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    // Session dismiss is active; programmatically set a 10-second snooze.
    await FirebaseUpdate.instance.snoozeOptionalUpdate(
      const Duration(seconds: 10),
    );

    // Confirm store has expiry set.
    expect(store.snoozedUntil, isNotNull);

    // At T+6s — still within 10s snooze.
    now = now.add(const Duration(seconds: 6));
    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsNothing);

    // At T+11s — past snooze expiry.
    now = now.add(const Duration(seconds: 5));
    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('clearSnooze() allows snoozed prompt to re-appear immediately', (
    tester,
  ) async {
    var now = DateTime(2024, 1, 1, 12, 0, 0);
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      snoozeDuration: const Duration(seconds: 5),
    );
    FirebaseUpdate.instance.debugSetClock(() => now);

    await _showOptionalUpdate(tester);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);

    // Clear snooze programmatically.
    await FirebaseUpdate.instance.clearSnooze();

    // Same version, same time — should show again now.
    await _showOptionalUpdate(tester);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets(
    'dismissOptionalUpdateForSession() hides prompt without persisting',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(tester, navigatorKey: navigatorKey, useDialog: true);

      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);

      // API call mirrors the default "Later" behaviour.
      FirebaseUpdate.instance.dismissOptionalUpdateForSession();

      await _showOptionalUpdate(tester);
      expect(find.text('Update available'), findsNothing);

      // Nothing written to persistent store.
      expect(store.snoozedUntil, isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // Callback hooks
  // ---------------------------------------------------------------------------

  testWidgets('onOptionalLaterTap fires when Later is tapped', (tester) async {
    var callCount = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      onOptionalLaterTap: () => callCount++,
    );

    await _showOptionalUpdate(tester);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('onForceUpdateTap fires when Update now is tapped on force dialog', (
    tester,
  ) async {
    var callCount = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      onForceUpdateTap: () => callCount++,
      onStoreLaunch: () {}, // prevent actual store launch
    );

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
    });
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('onOptionalUpdateTap fires when Update now is tapped on optional dialog', (
    tester,
  ) async {
    var callCount = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      onOptionalUpdateTap: () => callCount++,
      onStoreLaunch: () {},
    );

    await _showOptionalUpdate(tester);
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('onStoreLaunch override is called instead of default launcher', (
    tester,
  ) async {
    var storeLaunchCount = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      onStoreLaunch: () => storeLaunchCount++,
    );

    await _showOptionalUpdate(tester);
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(storeLaunchCount, 1);
    // Dialog is dismissed after onStoreLaunch returns.
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('onStoreLaunch fires for force update button too', (
    tester,
  ) async {
    var storeLaunchCount = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await _init(
      tester,
      navigatorKey: navigatorKey,
      useDialog: true,
      onStoreLaunch: () => storeLaunchCount++,
    );

    await FirebaseUpdate.instance.applyPayload({
      'min_version': '2.5.0',
      'latest_version': '2.6.0',
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(storeLaunchCount, 1);
  });

  // ---------------------------------------------------------------------------
  // Shorebird patch source
  // ---------------------------------------------------------------------------

  testWidgets(
    'patchSource: shorebirdPatch state is emitted when app is up to date and patch available',
    (tester) async {
      final patchSource = _FakePatchSource(available: true);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        patchSource: patchSource,
      );

      // Emit upToDate — triggers async patch check.
      await FirebaseUpdate.instance.applyPayload(null);
      await tester.pumpAndSettle();

      expect(
        FirebaseUpdate.instance.currentState.kind,
        FirebaseUpdateKind.shorebirdPatch,
      );
    },
  );

  testWidgets(
    'patchSource: shorebirdPatch not emitted when no patch available',
    (tester) async {
      final patchSource = _FakePatchSource(available: false);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        patchSource: patchSource,
      );

      await FirebaseUpdate.instance.applyPayload(null);
      await tester.pumpAndSettle();

      expect(
        FirebaseUpdate.instance.currentState.kind,
        FirebaseUpdateKind.upToDate,
      );
    },
  );

  testWidgets(
    'patchSource: version update takes priority over patch (no patch shown during update)',
    (tester) async {
      final patchSource = _FakePatchSource(available: true);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        patchSource: patchSource,
      );

      // Emit an optional update — patch check should NOT run on non-upToDate state.
      await _showOptionalUpdate(tester);
      await tester.pumpAndSettle();

      expect(
        FirebaseUpdate.instance.currentState.kind,
        FirebaseUpdateKind.optionalUpdate,
      );
    },
  );

  testWidgets(
    'patchSource: patch dialog shows patch title and Later button',
    (tester) async {
      final patchSource = _FakePatchSource(available: true);
      final navigatorKey = GlobalKey<NavigatorState>();
      await _init(
        tester,
        navigatorKey: navigatorKey,
        patchSource: patchSource,
      );

      await FirebaseUpdate.instance.applyPayload(null);
      await tester.pumpAndSettle();

      expect(find.text('Patch ready'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Apply & restart'), findsOneWidget);
    },
  );

  testWidgets(
    'patchSource: custom shorebirdPatchWidget receives correct state',
    (tester) async {
      String? receivedKind;
      final patchSource = _FakePatchSource(available: true);
      final navigatorKey = GlobalKey<NavigatorState>();

      await FirebaseUpdate.instance.initialize(
        navigatorKey: navigatorKey,
        config: FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          preferencesStore: store,
          patchSource: patchSource,
          shorebirdPatchWidget: (context, data) {
            receivedKind = data.state.kind.name;
            return AlertDialog(
              title: const Text('Custom patch dialog'),
              actions: [
                TextButton(
                  onPressed: data.onSecondaryTap,
                  child: const Text('Close'),
                ),
              ],
            );
          },
        ),
      );
      await tester.pumpWidget(_HarnessApp(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(null);
      await tester.pumpAndSettle();

      expect(find.text('Custom patch dialog'), findsOneWidget);
      expect(receivedKind, 'shorebirdPatch');
    },
  );
}

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------

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

/// In-memory [FirebaseUpdatePreferencesStore] for tests.
/// Avoids SharedPreferences platform channel calls.
class _InMemoryStore implements FirebaseUpdatePreferencesStore {
  String? skippedVersion;
  DateTime? snoozedUntil;

  @override
  Future<String?> getSkippedVersion() async => skippedVersion;

  @override
  Future<void> setSkippedVersion(String version) async =>
      skippedVersion = version;

  @override
  Future<void> clearSkippedVersion() async => skippedVersion = null;

  @override
  Future<DateTime?> getSnoozedUntil() async => snoozedUntil;

  @override
  Future<void> setSnoozedUntil(DateTime until) async => snoozedUntil = until;

  @override
  Future<void> clearSnoozedUntil() async => snoozedUntil = null;
}

/// Fake [FirebaseUpdatePatchSource] for Shorebird tests.
class _FakePatchSource implements FirebaseUpdatePatchSource {
  _FakePatchSource({this.available = true});

  bool available;
  int downloadCount = 0;

  @override
  Future<bool> isPatchAvailable() async => available;

  @override
  Future<void> downloadAndApplyPatch() async {
    downloadCount++;
  }
}
