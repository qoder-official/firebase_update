/// Sets Firebase Remote Config for the firebase_update example project.
///
/// Usage:
///   dart run set_remote_config.dart <scenario> [options]
///
/// Scenarios:
///   clear            Remove all firebase_update fields (idle state)
///   optional         Optional update prompt (app version 2.4.0 < latest 2.6.0)
///   force            Force update (app version 2.4.0 < min 2.5.0)
///   maintenance      Maintenance mode (blocks app)
///   escalate         Optional → force escalation (sets min above current)
///
/// Options:
///   --min-version    Override min_version  (e.g. --min-version 2.5.0)
///   --latest-version Override latest_version
///   --current        Simulated app version for display only (default: 2.4.0)
///   --dry-run        Print the payload without writing to Remote Config
///
/// Examples:
///   dart run set_remote_config.dart optional
///   dart run set_remote_config.dart force --min-version 3.0.0
///   dart run set_remote_config.dart maintenance
///   dart run set_remote_config.dart clear
///   dart run set_remote_config.dart optional --dry-run
///
library;

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _serviceAccountPath = '../test/firebase_config/service-account.json';
const _remoteConfigKey = 'firebase_update_config';
const _rcScope = 'https://www.googleapis.com/auth/firebase.remoteconfig';

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// Builds the JSON payload stored in the firebase_update_config RC key.
Map<String, dynamic> _buildPayload(
  String scenario, {
  String? minVersion,
  String? latestVersion,
}) {
  switch (scenario) {
    case 'clear':
      // Empty object → FirebaseUpdate resolves to idle.
      return {};

    case 'optional':
      return {
        'min_version': minVersion ?? '1.0.0',
        'latest_version': latestVersion ?? '2.6.0',
        'optional_update_title': 'Update available',
        'optional_update_message':
            'A new version (2.6.0) is ready with improvements and bug fixes.',
        'patch_notes':
            'Redesigned home screen\nDark mode support\n40% faster startup',
        'patch_notes_format': 'text',
      };

    case 'force':
      return {
        'min_version': minVersion ?? '2.5.0',
        'latest_version': latestVersion ?? '2.6.0',
        'force_update_title': 'Update required',
        'force_update_message':
            'This version is no longer supported. Please update to continue.',
        'patch_notes':
            'Critical security fix\nRequired API migration\nPerformance improvements',
        'patch_notes_format': 'text',
      };

    case 'maintenance':
      return {
        'maintenance_title': 'Scheduled maintenance',
        'maintenance_message':
            'We are performing scheduled maintenance. Please try again shortly.',
      };

    case 'escalate':
      // Starts as optional, then next call should push force — this sets force
      // directly so you can re-run with 'optional' first to test escalation flow.
      return {
        'min_version': minVersion ?? '2.5.0',
        'latest_version': latestVersion ?? '2.7.0',
        'update_title': 'Critical update required',
        'update_message': 'You must update to continue using the app.',
        'patch_notes': 'Security patch — update immediately.',
        'patch_notes_format': 'text',
      };

    default:
      stderr.writeln('Unknown scenario: $scenario');
      _printUsageAndExit();
  }
}

// ---------------------------------------------------------------------------
// Remote Config REST API helpers
// ---------------------------------------------------------------------------

Future<String> _getEtag(http.Client client, String projectId, String token) async {
  final uri = Uri.parse(
    'https://firebaseremoteconfig.googleapis.com/v1/projects/$projectId/remoteConfig',
  );
  final response = await client.get(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Accept-Encoding': 'gzip',
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
      'GET remoteConfig failed ${response.statusCode}: ${response.body}',
    );
  }

  final etag = response.headers['etag'];
  if (etag == null || etag.isEmpty) {
    throw Exception('No ETag in GET response — cannot safely PUT.');
  }
  return etag;
}

Future<void> _putRemoteConfig({
  required http.Client client,
  required String projectId,
  required String token,
  required String etag,
  required Map<String, dynamic> fullRcBody,
}) async {
  final uri = Uri.parse(
    'https://firebaseremoteconfig.googleapis.com/v1/projects/$projectId/remoteConfig',
  );
  final response = await client.put(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=UTF-8',
      'If-Match': etag,
    },
    body: jsonEncode(fullRcBody),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'PUT remoteConfig failed ${response.statusCode}: ${response.body}',
    );
  }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsageAndExit();
  }

  final scenario = args[0];
  final isDryRun = args.contains('--dry-run');
  final minVersion = _flag(args, '--min-version');
  final latestVersion = _flag(args, '--latest-version');

  // Build the payload for the chosen scenario.
  final payload = _buildPayload(
    scenario,
    minVersion: minVersion,
    latestVersion: latestVersion,
  );

  final payloadJson = const JsonEncoder.withIndent('  ').convert(payload);

  stdout.writeln('');
  stdout.writeln('Scenario  : $scenario');
  stdout.writeln('RC key    : $_remoteConfigKey');
  stdout.writeln('Payload   :');
  for (final line in payloadJson.split('\n')) {
    stdout.writeln('  $line');
  }
  stdout.writeln('');

  if (isDryRun) {
    stdout.writeln('Dry-run mode — Remote Config NOT updated.');
    return;
  }

  // Load service account credentials.
  final serviceAccountFile = File(
    '${File(Platform.script.toFilePath()).parent.path}/$_serviceAccountPath',
  );
  if (!serviceAccountFile.existsSync()) {
    stderr.writeln('Service account not found: ${serviceAccountFile.path}');
    exit(1);
  }

  final serviceAccountJson =
      jsonDecode(serviceAccountFile.readAsStringSync()) as Map<String, dynamic>;
  final projectId = serviceAccountJson['project_id'] as String;
  final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  stdout.writeln('Project   : $projectId');
  stdout.writeln('Authenticating with service account...');

  final client = http.Client();
  try {
    final authClient = await clientViaServiceAccount(
      credentials,
      [_rcScope],
      baseClient: client,
    );

    try {
      // We need a raw access token for the ETag-based PUT flow.
      final token = authClient.credentials.accessToken.data;

      stdout.writeln('Fetching current Remote Config (for ETag)...');
      final etag = await _getEtag(client, projectId, token);
      stdout.writeln('ETag      : $etag');

      // Build the full Remote Config body, merging our key into whatever
      // parameters already exist so we don't accidentally wipe other keys.
      final getUri = Uri.parse(
        'https://firebaseremoteconfig.googleapis.com/v1/projects/$projectId/remoteConfig',
      );
      final getResponse = await client.get(
        getUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept-Encoding': 'gzip',
        },
      );
      final currentBody =
          jsonDecode(getResponse.body) as Map<String, dynamic>;

      final parameters =
          (currentBody['parameters'] as Map<String, dynamic>?) ?? {};

      // Upsert just the firebase_update_config parameter.
      if (payload.isEmpty) {
        // Clear scenario — remove the key entirely.
        parameters.remove(_remoteConfigKey);
        stdout.writeln('Removing $_remoteConfigKey from Remote Config...');
      } else {
        parameters[_remoteConfigKey] = {
          'defaultValue': {
            'value': jsonEncode(payload),
          },
        };
        stdout.writeln('Writing $_remoteConfigKey to Remote Config...');
      }

      currentBody['parameters'] = parameters;

      await _putRemoteConfig(
        client: client,
        projectId: projectId,
        token: token,
        etag: etag,
        fullRcBody: currentBody,
      );

      stdout.writeln('');
      stdout.writeln('Remote Config updated successfully.');
      stdout.writeln(
        'Real-time listener on device should fire within a few seconds.',
      );
    } finally {
      authClient.close();
    }
  } finally {
    client.close();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _flag(List<String> args, String name) {
  final idx = args.indexOf(name);
  if (idx == -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}

Never _printUsageAndExit() {
  stdout.writeln('''
Usage: dart run set_remote_config.dart <scenario> [options]

Scenarios:
  clear        Remove firebase_update key (app goes idle)
  optional     Optional update  (app 2.4.0 < latest 2.6.0)
  force        Force update     (app 2.4.0 < min 2.5.0)
  maintenance  Maintenance mode (app is blocked)
  escalate     Force-level escalation with a newer latest version

Options:
  --min-version <ver>     Override min_version in the payload
  --latest-version <ver>  Override latest_version in the payload
  --dry-run               Print payload without writing to Remote Config
  --help                  Show this help
''');
  exit(0);
}
