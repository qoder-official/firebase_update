import 'package:flutter/foundation.dart';

/// Per-platform fallback store URLs for `firebase_update`.
///
/// The package opens the app's store listing automatically using the running
/// app's package name — no URL required. These URLs are only used if the
/// native store launch fails (e.g. the device has no Play Store / App Store
/// client, or the package name doesn't match the published listing).
///
/// Provide a URL for each platform you want a guaranteed fallback on:
///
/// ```dart
/// FirebaseUpdateStoreUrls(
///   android: 'https://play.google.com/store/apps/details?id=com.example.app',
///   ios: 'https://apps.apple.com/app/id000000000',
/// )
/// ```
@immutable
class FirebaseUpdateStoreUrls {
  const FirebaseUpdateStoreUrls({
    this.android,
    this.ios,
    this.macos,
    this.windows,
    this.linux,
    this.web,
  });

  /// Fallback Google Play listing URL for Android.
  final String? android;

  /// Fallback App Store product URL for iOS.
  final String? ios;

  /// Fallback Mac App Store product URL for macOS.
  final String? macos;

  /// Fallback store URL for Windows.
  final String? windows;

  /// Fallback store URL for Linux.
  final String? linux;

  /// Fallback store URL for Web.
  final String? web;
}
