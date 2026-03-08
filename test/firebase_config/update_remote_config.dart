#!/usr/bin/env dart
// ignore_for_file: avoid_print
/// Updates the firebase_update_config parameter in Firebase Remote Config using
/// a service-account JSON file, leaving all other parameters untouched.
///
/// Usage:
///   dart run update_remote_config.dart <scenario> [--key <remote_config_key>]
///
/// Scenarios:
///   clear       - No update (app is up to date)
///   optional    - Optional update available (latest: 2.6.0)
///   force       - Force update required (min: 2.5.0)
///   maintenance - Maintenance mode enabled
///
/// Options:
///   --key   Override the Remote Config parameter name.
///           Defaults to 'firebase_update_config' (the package default).

import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

const _serviceAccountFile = 'service-account.json';
const _defaultRcKey = 'firebase_update_config';
const _tokenUrl = 'https://oauth2.googleapis.com/token';
const _scope = 'https://www.googleapis.com/auth/firebase.remoteconfig';

// ---------------------------------------------------------------------------
// Scenario payloads
// ---------------------------------------------------------------------------

final _scenarios = <String, Map<String, dynamic>>{
  'clear': {
    'min_version': '',
    'latest_version': '',
    'update_type': '',
    'optional_update_title': '',
    'optional_update_message': '',
    'patch_notes': '',
    'patch_notes_format': 'text',
    'maintenance_enabled': false,
    'maintenance_title': '',
    'maintenance_message': '',
  },
  'optional': {
    'min_version': '1.0.0',
    'latest_version': '2.6.0',
    'update_type': 'optional',
    'optional_update_title': 'Update available',
    'optional_update_message': 'A new version is ready to install.',
    'patch_notes': '• Bug fixes\n• Performance improvements\n• New dark mode support',
    'patch_notes_format': 'text',
    'maintenance_enabled': false,
    'maintenance_title': '',
    'maintenance_message': '',
  },
  'force': {
    'min_version': '2.5.0',
    'latest_version': '2.6.0',
    'update_type': 'force',
    'optional_update_title': '',
    'optional_update_message': 'Critical security update required.',
    'patch_notes':
        '<ul><li>Security fixes</li><li>Required backend compatibility changes</li></ul>',
    'patch_notes_format': 'html',
    'maintenance_enabled': false,
    'maintenance_title': '',
    'maintenance_message': '',
  },
  'maintenance': {
    'min_version': '',
    'latest_version': '',
    'update_type': '',
    'optional_update_title': '',
    'optional_update_message': '',
    'patch_notes': '',
    'patch_notes_format': 'text',
    'maintenance_enabled': true,
    'maintenance_title': 'Scheduled maintenance',
    'maintenance_message': "We'll be back shortly. Thanks for your patience.",
  },
};

// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exit(1);
  }

  final scenario = args[0].toLowerCase().trim();
  var rcKey = _defaultRcKey;

  final keyIdx = args.indexOf('--key');
  if (keyIdx != -1) {
    if (keyIdx + 1 >= args.length) {
      print('--key requires a value');
      exit(1);
    }
    rcKey = args[keyIdx + 1];
  }

  if (!_scenarios.containsKey(scenario)) {
    print("Unknown scenario '$scenario'. Choose from: ${_scenarios.keys.join(', ')}");
    exit(1);
  }

  // Load service account
  final sa = jsonDecode(File(_serviceAccountFile).readAsStringSync()) as Map<String, dynamic>;
  final projectId = sa['project_id'] as String;
  final clientEmail = sa['client_email'] as String;
  final privateKey = sa['private_key'] as String;

  print('Authenticating with service account …');
  final accessToken = await _getAccessToken(clientEmail, privateKey);

  final rcBase =
      'https://firebaseremoteconfig.googleapis.com/v1/projects/$projectId/remoteConfig';

  print('Fetching current Remote Config …');
  final (etag, currentBody) = await _fetchConfig(rcBase, accessToken);
  print('  ETag: $etag');

  // Merge: keep all existing parameters, only upsert our key.
  final parameters =
      (currentBody['parameters'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  parameters[rcKey] = {
    'defaultValue': {'value': jsonEncode(_scenarios[scenario])},
  };

  final body = {
    'conditions': currentBody['conditions'] ?? [],
    'parameters': parameters,
    if (currentBody['parameterGroups'] != null)
      'parameterGroups': currentBody['parameterGroups'],
    'version': {
      'description': 'firebase_update scenario=$scenario key=$rcKey',
    },
  };

  print("Writing scenario '$scenario' to parameter '$rcKey' …");
  final resp = await http.put(
    Uri.parse(rcBase),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'If-Match': etag,
    },
    body: jsonEncode(body),
  );

  if (resp.statusCode == 200) {
    final newEtag = resp.headers['etag'] ?? '?';
    print('✅  Remote Config updated successfully!');
    print('   Parameter  : $rcKey');
    print('   Scenario   : $scenario');
    print('   New ETag   : $newEtag');
    print('\nThe app will receive the change in real time if listenToRealtimeUpdates is true.');
  } else {
    print('❌  Update failed: ${resp.statusCode}');
    print(resp.body);
    exit(1);
  }
}

/// Builds a short-lived OAuth2 access token from a service-account private key.
Future<String> _getAccessToken(String clientEmail, String privateKey) async {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final jwt = JWT(
    {
      'iss': clientEmail,
      'sub': clientEmail,
      'scope': _scope,
      'aud': _tokenUrl,
      'iat': now,
      'exp': now + 3600,
    },
  );

  final signed = jwt.sign(
    RSAPrivateKey(privateKey),
    algorithm: JWTAlgorithm.RS256,
  );

  final resp = await http.post(
    Uri.parse(_tokenUrl),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      'assertion': signed,
    },
  );

  if (resp.statusCode != 200) {
    throw Exception('Token exchange failed ${resp.statusCode}: ${resp.body}');
  }

  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  return json['access_token'] as String;
}

Future<(String, Map<String, dynamic>)> _fetchConfig(
  String rcBase,
  String token,
) async {
  final resp = await http.get(
    Uri.parse(rcBase),
    headers: {'Authorization': 'Bearer $token', 'Accept-Encoding': 'identity'},
  );

  if (resp.statusCode != 200) {
    throw Exception('Fetch failed ${resp.statusCode}: ${resp.body}');
  }

  final etag = resp.headers['etag'] ?? '*';
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  return (etag, body);
}

void _printUsage() {
  print('''
Usage: dart run update_remote_config.dart <scenario> [--key <remote_config_key>]

Scenarios: ${_scenarios.keys.join(', ')}

Options:
  --key   Remote Config parameter name (default: $_defaultRcKey)
''');
}
