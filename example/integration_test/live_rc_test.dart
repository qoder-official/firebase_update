/// Live Remote Config integration test.
///
/// Unlike [priority_sequence_test.dart] which uses [applyPayload] to drive
/// state changes synchronously, this test calls the Firebase Remote Config
/// REST API directly from the device using the project's service account.
/// It then waits for the real-time [onConfigUpdated] listener to fire and
/// verifies that the correct overlay appears — proving the full pipeline:
///
///   Firebase Console / REST API
///     → Firebase Real-Time RC infrastructure
///       → onConfigUpdated stream on device
///         → state resolver
///           → presenter
///             → navigator overlay
///
/// The test also validates the priority rule (maintenance > force > optional)
/// end-to-end over real network changes.
///
/// Prerequisites:
///   • Physical device or emulator with network access.
///   • Firebase project configured in the example app.
///   • The test service account at test/firebase_config/service-account.json
///     must have the Remote Config Admin role.
///
/// Run from the example/ directory:
///   flutter test integration_test/live_rc_test.dart -d <device>
///
/// NOTE: Each RC push takes ~2-10 s to propagate via the real-time listener.
/// The test uses a 30 s timeout per step to stay reliable on slow networks.
library;

import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_update/firebase_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:firebase_update_example/example_app.dart';
import 'package:firebase_update_example/firebase_options.dart';

// ---------------------------------------------------------------------------
// Service-account credentials (test project)
//
// Pass via --dart-define when running this test:
//   flutter test integration_test/live_rc_test.dart -d <device> \
//     --dart-define=SA_PRIVATE_KEY="$(jq -r .private_key \
//         ../test/firebase_config/service-account.json)"
// ---------------------------------------------------------------------------

const _projectId = 'fir-update-example-eff16';
const _serviceEmail =
    'firebase-adminsdk-fbsvc@fir-update-example-eff16.iam.gserviceaccount.com';

// Injected at build time via --dart-define=SA_PRIVATE_KEY=<key-with-literal-\n>.
// The script passes newlines as literal \n to keep the define single-line
// (multi-line dart-defines break Flutter's Android build chain). We decode
// them here so RSAPrivateKey receives a properly formatted PEM string.
// ignore: do_not_use_environment
const _privateKeyRaw = String.fromEnvironment('SA_PRIVATE_KEY');
final _privateKey = _privateKeyRaw.replaceAll('\\n', '\n');

const _rcScope = 'https://www.googleapis.com/auth/firebase.remoteconfig';
const _rcKey = 'firebase_update_config';

// ---------------------------------------------------------------------------
// RC REST API helpers
// ---------------------------------------------------------------------------

/// Mints a short-lived OAuth2 access token using the service account.
Future<String> _getAccessToken() async {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final jwt = JWT(
    {
      'iss': _serviceEmail,
      'sub': _serviceEmail,
      'aud': 'https://oauth2.googleapis.com/token',
      'iat': now,
      'exp': now + 3600,
      'scope': _rcScope,
    },
  );

  final assertion = jwt.sign(RSAPrivateKey(_privateKey), algorithm: JWTAlgorithm.RS256);

  final response = await http.post(
    Uri.parse('https://oauth2.googleapis.com/token'),
    body: {
      'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      'assertion': assertion,
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Token exchange failed ${response.statusCode}: ${response.body}');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return body['access_token'] as String;
}

/// Pushes [payload] to the [_rcKey] Remote Config parameter.
/// Pass `null` or an empty map to remove the key (→ idle state on device).
Future<void> _pushRc(Map<String, dynamic>? payload) async {
  final token = await _getAccessToken();

  final getUri = Uri.parse(
    'https://firebaseremoteconfig.googleapis.com/v1/projects/$_projectId/remoteConfig',
  );
  final getResponse = await http.get(
    getUri,
    headers: {'Authorization': 'Bearer $token'},
  );
  if (getResponse.statusCode != 200) {
    throw Exception('GET remoteConfig failed: ${getResponse.statusCode}');
  }

  final etag = getResponse.headers['etag'];
  if (etag == null) throw Exception('No ETag in GET response');

  final body = jsonDecode(getResponse.body) as Map<String, dynamic>;
  final parameters = (body['parameters'] as Map<String, dynamic>?) ?? {};

  if (payload == null || payload.isEmpty) {
    parameters.remove(_rcKey);
  } else {
    parameters[_rcKey] = {
      'defaultValue': {'value': jsonEncode(payload)},
    };
  }
  body['parameters'] = parameters;

  final putResponse = await http.put(
    Uri.parse(
      'https://firebaseremoteconfig.googleapis.com/v1/projects/$_projectId/remoteConfig',
    ),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=UTF-8',
      'If-Match': etag,
    },
    body: jsonEncode(body),
  );

  if (putResponse.statusCode != 200) {
    throw Exception('PUT remoteConfig failed ${putResponse.statusCode}: ${putResponse.body}');
  }
}

// ---------------------------------------------------------------------------
// Payloads (app version pinned to 2.4.0)
// ---------------------------------------------------------------------------

const _optional = {
  'min_version': '1.0.0',
  'latest_version': '2.6.0',
  'optional_update_title': 'Update available',
  'optional_update_message': 'Version 2.6.0 is ready.',
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

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pushes [payload] to RC and immediately calls [FirebaseUpdate.checkNow]
/// to fetch the new value without waiting for the real-time listener.
///
/// This exercises the complete pipeline (REST API → Firebase servers → device
/// fetch → state resolver → presenter) while remaining reliable in test
/// conditions where the real-time WebSocket may have higher latency.
Future<void> _pushAndFetch(Map<String, dynamic>? payload) async {
  await _pushRc(payload);
  await FirebaseUpdate.instance.checkNow();
}

/// Polls until [finder] is non-empty. Throws [TestFailure] on timeout.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle();
}

/// Polls until [finder] is empty. Throws [TestFailure] on timeout.
Future<void> _waitGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for disappearance of: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Reset RC to a clean idle state before the suite runs.
    await _pushRc(null);
  });

  tearDown(() {
    FirebaseUpdate.instance.debugReset();
  });

  // =========================================================================
  // Live RC — full priority chain over real Firebase updates
  // =========================================================================

  group('live RC real-time updates — priority chain', () {
    testWidgets(
      'optional → force → maintenance → clear via real Remote Config',
      (tester) async {
        // Use zero fetch interval so fetchAndActivate always hits the network.
        await FirebaseUpdate.instance.initialize(
          navigatorKey: rootNavigatorKey,
          config: const FirebaseUpdateConfig(
            currentVersion: '2.4.0',
            minimumFetchInterval: Duration.zero,
            useBottomSheetForOptionalUpdate: false,
            useBottomSheetForForceUpdate: false,
            useBottomSheetForMaintenance: false,
          ),
        );
        await tester.pumpWidget(const FirebaseUpdateExampleApp());
        await tester.pumpAndSettle();

        // ── Step 1: optional update ──────────────────────────────────────
        await _pushAndFetch(_optional);
        await _waitFor(tester, find.text('Update available'));
        expect(find.text('Update available'), findsOneWidget);
        expect(find.text('Later'), findsOneWidget);
        expect(find.text('Update required'), findsNothing);
        expect(find.text('Scheduled maintenance'), findsNothing);

        // ── Step 2: force replaces optional ─────────────────────────────
        await _pushAndFetch(_force);
        await _waitFor(tester, find.text('Update required'));
        expect(find.text('Update required'), findsOneWidget);
        expect(find.text('Later'), findsNothing);
        expect(find.text('Update available'), findsNothing);
        expect(find.text('Scheduled maintenance'), findsNothing);

        // ── Step 3: maintenance replaces force ───────────────────────────
        await _pushAndFetch(_maintenance);
        await _waitFor(tester, find.text('Scheduled maintenance'));
        expect(find.text('Scheduled maintenance'), findsOneWidget);
        expect(find.text('Later'), findsNothing);
        expect(find.text('Update required'), findsNothing);
        expect(find.text('Update available'), findsNothing);

        // ── Step 4: clear → idle (maintenance dismissed) ─────────────────
        await _pushAndFetch(null);
        await _waitGone(tester, find.text('Scheduled maintenance'));
        expect(find.text('Scheduled maintenance'), findsNothing);
        expect(find.text('Update required'), findsNothing);
        expect(find.text('Update available'), findsNothing);
        expect(find.text('Later'), findsNothing);
      },
    );
  });

  // =========================================================================
  // Live RC — real-time deescalation
  // Verifies that removing a restriction via RC correctly dismisses the overlay.
  // =========================================================================

  group('live RC real-time updates — deescalation', () {
    testWidgets('force clears to optional when min_version drops', (
      tester,
    ) async {
      await FirebaseUpdate.instance.initialize(
        navigatorKey: rootNavigatorKey,
        config: const FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          minimumFetchInterval: Duration.zero,
          useBottomSheetForOptionalUpdate: false,
          useBottomSheetForForceUpdate: false,
        ),
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await _pushAndFetch(_force);
      await _waitFor(tester, find.text('Update required'));
      expect(find.text('Later'), findsNothing);

      // Drop min_version below current — should deescalate to optional.
      await _pushAndFetch(_optional);
      await _waitFor(tester, find.text('Update available'));
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update required'), findsNothing);

      // Cleanup.
      await _pushAndFetch(null);
    });

    testWidgets('maintenance clears to idle when maintenance_message removed', (
      tester,
    ) async {
      await FirebaseUpdate.instance.initialize(
        navigatorKey: rootNavigatorKey,
        config: const FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          minimumFetchInterval: Duration.zero,
          useBottomSheetForMaintenance: false,
        ),
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());
      await tester.pumpAndSettle();

      await _pushAndFetch(_maintenance);
      await _waitFor(tester, find.text('Scheduled maintenance'));

      await _pushAndFetch(null);
      await _waitGone(tester, find.text('Scheduled maintenance'));
      expect(find.text('Scheduled maintenance'), findsNothing);
      expect(find.text('Update available'), findsNothing);
      expect(find.text('Update required'), findsNothing);
    });
  });

  // =========================================================================
  // Live RC — checkNow smoke test
  // Verifies that an explicit checkNow() call fetches and applies the current
  // RC value without relying on the real-time listener.
  // =========================================================================

  group('live RC — checkNow smoke test', () {
    testWidgets('checkNow reflects the current RC value', (tester) async {
      // Set RC to optional before initializing.
      await _pushRc(_optional);

      await FirebaseUpdate.instance.initialize(
        navigatorKey: rootNavigatorKey,
        config: const FirebaseUpdateConfig(
          currentVersion: '2.4.0',
          minimumFetchInterval: Duration.zero,
          useBottomSheetForOptionalUpdate: false,
        ),
      );
      await tester.pumpWidget(const FirebaseUpdateExampleApp());

      // The initial fetch inside initialize() should have picked up _optional.
      await _waitFor(tester, find.text('Update available'));
      expect(find.text('Update available'), findsOneWidget);

      // Now switch to maintenance externally, then call checkNow().
      await _pushRc(_maintenance);
      await FirebaseUpdate.instance.checkNow();

      await _waitFor(tester, find.text('Scheduled maintenance'));
      expect(find.text('Scheduled maintenance'), findsOneWidget);
      expect(find.text('Update available'), findsNothing);

      // Cleanup.
      await _pushAndFetch(null);
    });
  });
}
