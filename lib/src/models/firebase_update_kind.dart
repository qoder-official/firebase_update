/// The resolved update state kind emitted by `firebase_update`.
enum FirebaseUpdateKind {
  /// The package has not been initialized yet.
  idle,

  /// The current app version meets or exceeds all version requirements and
  /// maintenance mode is not active.
  upToDate,

  /// A newer version is available but the current version is still usable.
  optionalUpdate,

  /// The current version is below the minimum supported version. The user
  /// must update before continuing to use the app.
  forceUpdate,

  /// The app is temporarily unavailable due to a maintenance event. This
  /// state is independent of the app version.
  maintenance,

  /// A Shorebird code-push patch is available and has been downloaded.
  /// The user should restart the app to apply it.
  shorebirdPatch,
}
