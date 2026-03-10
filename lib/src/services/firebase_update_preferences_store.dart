import 'package:shared_preferences/shared_preferences.dart';

/// Abstract interface for persisting skip-version and snooze state across
/// app restarts.
///
/// The default implementation [SharedPreferencesFirebaseUpdateStore] uses
/// `shared_preferences`. Inject a custom implementation via
/// [FirebaseUpdateConfig.preferencesStore] to use a different storage backend,
/// for example secure storage or a database.
abstract class FirebaseUpdatePreferencesStore {
  /// Returns the version string that the user chose to skip permanently,
  /// or `null` if no version has been skipped.
  Future<String?> getSkippedVersion();

  /// Persists [version] as the permanently skipped version.
  Future<void> setSkippedVersion(String version);

  /// Clears any persisted skipped version.
  Future<void> clearSkippedVersion();

  /// Returns the [DateTime] until which optional update prompts are snoozed,
  /// or `null` if no snooze is active.
  Future<DateTime?> getSnoozedUntil();

  /// Persists [until] as the snooze expiry timestamp.
  Future<void> setSnoozedUntil(DateTime until);

  /// Clears any persisted snooze state.
  Future<void> clearSnoozedUntil();
}

/// Default [FirebaseUpdatePreferencesStore] backed by `shared_preferences`.
class SharedPreferencesFirebaseUpdateStore
    implements FirebaseUpdatePreferencesStore {
  static const String _skippedVersionKey = 'firebase_update_skipped_version';
  static const String _snoozedUntilMsKey = 'firebase_update_snoozed_until_ms';

  @override
  Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_skippedVersionKey);
  }

  @override
  Future<void> setSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }

  @override
  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skippedVersionKey);
  }

  @override
  Future<DateTime?> getSnoozedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_snoozedUntilMsKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setSnoozedUntil(DateTime until) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozedUntilMsKey, until.millisecondsSinceEpoch);
  }

  @override
  Future<void> clearSnoozedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snoozedUntilMsKey);
  }
}
