/// Comprehensive integration test for the single-overlay-at-a-time rule.
///
/// Validates that the presenter enforces:
///
///   maintenance  >  force update  >  optional update
///
/// Every time two or more states collide, exactly one overlay is visible and
/// it is always the highest-priority one.  All state transitions are driven by
/// [FirebaseUpdate.instance.applyPayload], which exercises the same code path
/// as a live Remote Config update (state resolver → presenter → navigator).
///
/// A separate group tests navigator-key timing: payloads applied before the
/// Flutter widget tree is built must still produce an overlay once the
/// navigator becomes available.
///
/// Run from the example/ directory:
///   flutter test integration_test/priority_sequence_test.dart -d <device>
library;

import 'package:firebase_update/firebase_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:firebase_update_example/example_app.dart';

// ---------------------------------------------------------------------------
// Shared payloads (app version is pinned to 2.4.0 in every initXxx call)
// ---------------------------------------------------------------------------

const _optional = {
  'min_version': '1.0.0',
  'latest_version': '2.6.0',
  'optional_update_title': 'Update available',
  'optional_update_message': 'Version 2.6.0 is ready.',
};

const _optionalNewer = {
  'min_version': '1.0.0',
  'latest_version': '2.7.0',
  'optional_update_title': 'Update available',
  'optional_update_message': 'Version 2.7.0 is ready.',
};

const _force = {
  'min_version': '2.5.0',
  'latest_version': '2.6.0',
  'force_update_title': 'Update required',
  'force_update_message': 'You must update to continue.',
};

const _maintenance = {
  'maintenance_title': 'Scheduled maintenance',
  'maintenance_message': 'Back shortly.',
};

// An empty (or null) payload resolves to idle — no overlay.
const _clear = <String, dynamic>{};

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pumps until [finder] is non-empty or [timeout] elapses, then pumpAndSettles.
/// Throws [TestFailure] if the widget never appears.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Pumps until [finder] is empty or [timeout] elapses.
/// Throws [TestFailure] if the widget never disappears.
Future<void> _waitGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for disappearance of: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Applies a payload and pumps a single short frame so that the presenter's
/// async machinery (postFrameCallback, unawaited Future) gets a chance to run
/// without fully settling — simulating a fast but realistic RC update.
Future<void> _fastApply(
  WidgetTester tester,
  Map<String, dynamic> payload,
) async {
  await FirebaseUpdate.instance.applyPayload(payload);
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// Shared init helpers
// ---------------------------------------------------------------------------

Future<void> _initAllDialogs() => initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      useBottomSheetForOptionalUpdate: false,
      useBottomSheetForForceUpdate: false,
      useBottomSheetForMaintenance: false,
    );

Future<void> _initAllSheets() => initializeExampleFirebaseUpdate(
      initializeFirebase: false,
      useBottomSheetForOptionalUpdate: true,
      useBottomSheetForForceUpdate: true,
      useBottomSheetForMaintenance: true,
    );

// ---------------------------------------------------------------------------
// Assertion helpers
// ---------------------------------------------------------------------------

void _expectOnlyOptional() {
  expect(find.text('Update available'), findsOneWidget);
  expect(find.text('Later'), findsOneWidget);
  expect(find.text('Update required'), findsNothing);
  expect(find.text('Scheduled maintenance'), findsNothing);
}

void _expectOnlyForce() {
  expect(find.text('Update required'), findsOneWidget);
  expect(find.text('Later'), findsNothing);
  expect(find.text('Update available'), findsNothing);
  expect(find.text('Scheduled maintenance'), findsNothing);
}

void _expectOnlyMaintenance() {
  expect(find.text('Scheduled maintenance'), findsOneWidget);
  expect(find.text('Later'), findsNothing);
  expect(find.text('Update available'), findsNothing);
  expect(find.text('Update required'), findsNothing);
}

void _expectNoOverlay() {
  expect(find.text('Update available'), findsNothing);
  expect(find.text('Update required'), findsNothing);
  expect(find.text('Scheduled maintenance'), findsNothing);
  expect(find.text('Later'), findsNothing);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  // =========================================================================
  // Group 1 – Priority escalation (dialog forms)
  // Verifies that the higher-priority state always replaces the current one
  // and that at most one overlay is on screen.
  // =========================================================================

  group('priority escalation / dialogs', () {
    testWidgets('optional → force: force replaces optional, Later gone', (
      tester,
    ) async {
      await _initAllDialogs();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_optional);
      await _waitFor(tester, find.text('Update available'));
      _expectOnlyOptional();

      await _fastApply(tester, _force);
      await _waitFor(tester, find.text('Update required'));
      _expectOnlyForce();
    });

    testWidgets('optional → maintenance: maintenance replaces optional', (
      tester,
    ) async {
      await _initAllDialogs();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_optional);
      await _waitFor(tester, find.text('Update available'));

      await _fastApply(tester, _maintenance);
      await _waitFor(tester, find.text('Scheduled maintenance'));
      _expectOnlyMaintenance();
    });

    testWidgets('force → maintenance: maintenance replaces force', (
      tester,
    ) async {
      await _initAllDialogs();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_force);
      await _waitFor(tester, find.text('Update required'));

      await _fastApply(tester, _maintenance);
      await _waitFor(tester, find.text('Scheduled maintenance'));
      _expectOnlyMaintenance();
    });

    testWidgets(
      'maintenance → force: force shows when maintenance clears but min_version is still breached',
      (tester) async {
        await _initAllDialogs();
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await FirebaseUpdate.instance.applyPayload(_maintenance);
        await _waitFor(tester, find.text('Scheduled maintenance'));

        // Maintenance ends but the app version is still below min_version.
        await _fastApply(tester, _force);
        await _waitFor(tester, find.text('Update required'));
        _expectOnlyForce();
      },
    );

    testWidgets(
      'maintenance → optional: optional shows when maintenance clears',
      (tester) async {
        await _initAllDialogs();
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await FirebaseUpdate.instance.applyPayload(_maintenance);
        await _waitFor(tester, find.text('Scheduled maintenance'));

        await _fastApply(tester, _optional);
        await _waitFor(tester, find.text('Update available'));
        _expectOnlyOptional();
      },
    );

    testWidgets('force → optional: optional shows when force requirement drops',
        (
      tester,
    ) async {
      await _initAllDialogs();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_force);
      await _waitFor(tester, find.text('Update required'));

      await _fastApply(tester, _optional);
      await _waitFor(tester, find.text('Update available'));
      _expectOnlyOptional();
    });

    testWidgets('optional → clear: no overlay', (tester) async {
      await _initAllDialogs();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_optional);
      await _waitFor(tester, find.text('Update available'));

      await _fastApply(tester, _clear);
      await _waitGone(tester, find.text('Update available'));
      _expectNoOverlay();
    });

    testWidgets('force → clear: no overlay', (tester) async {
      await _initAllDialogs();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_force);
      await _waitFor(tester, find.text('Update required'));

      await _fastApply(tester, _clear);
      await _waitGone(tester, find.text('Update required'));
      _expectNoOverlay();
    });

    testWidgets('maintenance → clear: no overlay', (tester) async {
      await _initAllDialogs();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_maintenance);
      await _waitFor(tester, find.text('Scheduled maintenance'));

      await _fastApply(tester, _clear);
      await _waitGone(tester, find.text('Scheduled maintenance'));
      _expectNoOverlay();
    });
  });

  // =========================================================================
  // Group 2 – Priority escalation (bottom sheet forms)
  // Same transitions, different presentation style.  The priority rule must
  // hold regardless of whether dialogs or sheets are used.
  // =========================================================================

  group('priority escalation / bottom sheets', () {
    testWidgets('optional sheet → force sheet: only force visible', (
      tester,
    ) async {
      await _initAllSheets();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_optional);
      await _waitFor(tester, find.text('Update available'));
      _expectOnlyOptional();

      await _fastApply(tester, _force);
      await _waitFor(tester, find.text('Update required'));
      _expectOnlyForce();
    });

    testWidgets('optional sheet → maintenance sheet: only maintenance visible',
        (
      tester,
    ) async {
      await _initAllSheets();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_optional);
      await _waitFor(tester, find.text('Update available'));

      await _fastApply(tester, _maintenance);
      await _waitFor(tester, find.text('Scheduled maintenance'));
      _expectOnlyMaintenance();
    });

    testWidgets('force sheet → maintenance sheet: only maintenance visible', (
      tester,
    ) async {
      await _initAllSheets();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_force);
      await _waitFor(tester, find.text('Update required'));

      await _fastApply(tester, _maintenance);
      await _waitFor(tester, find.text('Scheduled maintenance'));
      _expectOnlyMaintenance();
    });

    testWidgets('maintenance sheet → clear: no overlay', (tester) async {
      await _initAllSheets();
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await FirebaseUpdate.instance.applyPayload(_maintenance);
      await _waitFor(tester, find.text('Scheduled maintenance'));

      await _fastApply(tester, _clear);
      await _waitGone(tester, find.text('Scheduled maintenance'));
      _expectNoOverlay();
    });
  });

  // =========================================================================
  // Group 3 – Mixed presentation (dialog ↔ sheet)
  // Ensures transitions work even when config toggles between dialog and sheet.
  // =========================================================================

  group('priority escalation / mixed dialog–sheet', () {
    testWidgets(
      'optional dialog → force sheet: force sheet is the sole visible overlay',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
          useBottomSheetForForceUpdate: true,
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await FirebaseUpdate.instance.applyPayload(_optional);
        await _waitFor(tester, find.text('Update available'));

        await _fastApply(tester, _force);
        await _waitFor(tester, find.text('Update required'));
        _expectOnlyForce();
      },
    );

    testWidgets(
      'force dialog → maintenance sheet: maintenance sheet is sole overlay',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForForceUpdate: false,
          useBottomSheetForMaintenance: true,
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await FirebaseUpdate.instance.applyPayload(_force);
        await _waitFor(tester, find.text('Update required'));

        await _fastApply(tester, _maintenance);
        await _waitFor(tester, find.text('Scheduled maintenance'));
        _expectOnlyMaintenance();
      },
    );
  });

  // =========================================================================
  // Group 4 – Rapid-fire state bursts
  // Simulates very fast RC config updates arriving in quick succession.
  // After the burst the highest-priority active state must win.
  // =========================================================================

  group('rapid-fire state bursts', () {
    testWidgets(
      'optional → force → maintenance burst: maintenance is the final winner',
      (tester) async {
        await _initAllDialogs();
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        // Fire three state changes without fully settling between them.
        await _fastApply(tester, _optional);
        await _fastApply(tester, _force);
        await _fastApply(tester, _maintenance);

        await _waitFor(
          tester,
          find.text('Scheduled maintenance'),
          timeout: const Duration(seconds: 10),
        );
        _expectOnlyMaintenance();
      },
    );

    testWidgets(
      'maintenance → force → optional → clear burst: no overlay remains',
      (tester) async {
        await _initAllDialogs();
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await _fastApply(tester, _maintenance);
        await _fastApply(tester, _force);
        await _fastApply(tester, _optional);
        await _fastApply(tester, _clear);

        await tester.pumpAndSettle(const Duration(seconds: 2));
        _expectNoOverlay();
      },
    );

    testWidgets(
      'five optional versions in quick succession: only the latest is shown',
      (tester) async {
        await _initAllDialogs();
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        // Simulate five RC pushes with incrementing latest versions.
        for (int i = 1; i <= 5; i++) {
          await _fastApply(tester, {
            'min_version': '1.0.0',
            'latest_version': '2.$i.0',
            'optional_update_title': 'Update available',
          });
        }

        await _waitFor(tester, find.text('Update available'));
        _expectOnlyOptional();
      },
    );

    testWidgets(
      'optional → maintenance (sheets) burst: only maintenance sheet visible',
      (tester) async {
        await _initAllSheets();
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await _fastApply(tester, _optional);
        await _fastApply(tester, _maintenance);

        await _waitFor(
          tester,
          find.text('Scheduled maintenance'),
          timeout: const Duration(seconds: 10),
        );
        _expectOnlyMaintenance();
      },
    );
  });

  // =========================================================================
  // Group 5 – Navigator-key timing
  // The presenter defers via postFrameCallback when the navigator context is
  // not yet ready.  Overlays applied before pumpWidget must still appear.
  // =========================================================================

  group('navigator-key timing', () {
    testWidgets(
      'optional payload applied before pumpWidget → overlay appears after pump',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
        );

        // Apply payload BEFORE the widget tree exists.
        // Navigator key has no context at this point.
        await FirebaseUpdate.instance.applyPayload(_optional);

        // Now build the widget tree.
        await tester.pumpWidget(const FirebaseUpdateExampleApp());

        // The presenter must pick up the deferred state and show the overlay.
        await _waitFor(tester, find.text('Update available'));
        _expectOnlyOptional();
      },
    );

    testWidgets(
      'force payload before pumpWidget → blocking dialog appears, no Later',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForForceUpdate: false,
        );

        await FirebaseUpdate.instance.applyPayload(_force);

        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await _waitFor(tester, find.text('Update required'));
        _expectOnlyForce();
      },
    );

    testWidgets(
      'maintenance payload before pumpWidget → blocking dialog appears',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForMaintenance: false,
        );

        await FirebaseUpdate.instance.applyPayload(_maintenance);

        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await _waitFor(tester, find.text('Scheduled maintenance'));
        _expectOnlyMaintenance();
      },
    );

    testWidgets(
      'payload applied immediately after pumpWidget (before pumpAndSettle) → overlay appears',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
        );

        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        // Deliberately do NOT call pumpAndSettle here.

        await FirebaseUpdate.instance.applyPayload(_force);

        await _waitFor(tester, find.text('Update required'));
        _expectOnlyForce();
      },
    );

    testWidgets(
      'maintenance (sheet) payload before pumpWidget → blocking sheet appears',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForMaintenance: true,
        );

        await FirebaseUpdate.instance.applyPayload(_maintenance);

        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await _waitFor(tester, find.text('Scheduled maintenance'));
        _expectOnlyMaintenance();
      },
    );
  });

  // =========================================================================
  // Group 6 – Skip-version interactions under escalation
  // Tapping "Later" skips the current optional version.  This skip must not
  // prevent higher-priority states from appearing.
  // =========================================================================

  group('skip-version interactions', () {
    testWidgets(
      'skip optional → force escalates regardless of skip',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
          useBottomSheetForForceUpdate: false,
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        // Show optional and dismiss via Later.
        await FirebaseUpdate.instance.applyPayload(_optional);
        await _waitFor(tester, find.text('Update available'));
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
        expect(find.text('Update available'), findsNothing);

        // Force update must still appear despite the skip.
        await _fastApply(tester, _force);
        await _waitFor(tester, find.text('Update required'));
        _expectOnlyForce();
      },
    );

    testWidgets(
      'skip optional 2.6.0 → re-emit 2.6.0 → still suppressed',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await FirebaseUpdate.instance.applyPayload(_optional); // 2.6.0
        await _waitFor(tester, find.text('Update available'));
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();

        // Same version re-emitted — must remain suppressed.
        await FirebaseUpdate.instance.applyPayload(_optional);
        await tester.pumpAndSettle();
        expect(find.text('Update available'), findsNothing);
      },
    );

    testWidgets(
      'skip 2.6.0 → maintenance → maintenance ends with 2.7.0 → 2.7.0 re-appears',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
          useBottomSheetForMaintenance: false,
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        // Skip 2.6.0.
        await FirebaseUpdate.instance.applyPayload(_optional); // 2.6.0
        await _waitFor(tester, find.text('Update available'));
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();

        // Maintenance takes over.
        await _fastApply(tester, _maintenance);
        await _waitFor(tester, find.text('Scheduled maintenance'));

        // Maintenance ends — now 2.7.0 is available.
        // The newer version must clear the skip and show the dialog.
        await _fastApply(tester, _optionalNewer); // 2.7.0
        await _waitFor(tester, find.text('Update available'));
        _expectOnlyOptional();
      },
    );

    testWidgets(
      'skip 2.6.0 → newer version 2.7.0 re-shows dialog',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        await FirebaseUpdate.instance.applyPayload(_optional); // 2.6.0
        await _waitFor(tester, find.text('Update available'));
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();

        await _fastApply(tester, _optionalNewer); // 2.7.0
        await _waitFor(tester, find.text('Update available'));
        _expectOnlyOptional();
      },
    );

    testWidgets(
      'skip optional → maintenance → clear resets skip → skipped version re-appears',
      (tester) async {
        await initializeExampleFirebaseUpdate(
          initializeFirebase: false,
          useBottomSheetForOptionalUpdate: false,
          useBottomSheetForMaintenance: false,
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        // Skip 2.6.0.
        await FirebaseUpdate.instance.applyPayload(_optional);
        await _waitFor(tester, find.text('Update available'));
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();

        // Maintenance takes over, then RC is cleared (→ upToDate).
        // Going to upToDate resets _skippedVersion along with _presentedKind.
        await _fastApply(tester, _maintenance);
        await _waitFor(tester, find.text('Scheduled maintenance'));
        await _fastApply(tester, _clear);
        await _waitGone(tester, find.text('Scheduled maintenance'));

        // Re-emit the same version — skip was cleared by upToDate, so it
        // must prompt the user again.
        await FirebaseUpdate.instance.applyPayload(_optional);
        await _waitFor(tester, find.text('Update available'));
        _expectOnlyOptional();
      },
    );
  });
}
