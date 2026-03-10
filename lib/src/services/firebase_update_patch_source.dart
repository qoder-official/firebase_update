/// Abstract interface for code-push patch availability.
///
/// Implement this with `shorebird_code_push` (or any other code-push provider)
/// to enable patch updates via [FirebaseUpdateKind.shorebirdPatch].
///
/// Inject an instance via [FirebaseUpdateConfig.patchSource].
///
/// Example:
/// ```dart
/// class ShorebirdPatchSource implements FirebaseUpdatePatchSource {
///   final _updater = ShorebirdUpdater();
///
///   @override
///   Future<bool> isPatchAvailable() async {
///     final status = await _updater.checkForUpdate();
///     return status == UpdateStatus.outdated;
///   }
///
///   @override
///   Future<void> downloadAndApplyPatch() => _updater.update();
/// }
/// ```
abstract class FirebaseUpdatePatchSource {
  /// Returns `true` if a new patch is available for download.
  Future<bool> isPatchAvailable();

  /// Downloads and applies the available patch.
  ///
  /// The app must be restarted after this completes for the patch to take
  /// effect. If [FirebaseUpdateConfig.onPatchApplied] is set, it will be
  /// called immediately after this returns successfully — use it to trigger
  /// a hot restart. If no callback is set, a snackbar is shown instead.
  Future<void> downloadAndApplyPatch();
}
