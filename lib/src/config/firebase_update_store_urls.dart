import 'package:flutter/foundation.dart';

/// Per-platform store URLs used when the native store-listing launcher needs
/// a direct URL.
///
/// Provide at least one URL for each platform the app targets. If a platform
/// URL is `null` and native launch also fails, the update CTA shows a snackbar
/// error instead.
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

  /// Google Play listing URL for Android.
  final String? android;

  /// App Store product URL for iOS.
  final String? ios;

  /// Mac App Store product URL for macOS.
  final String? macos;

  /// Store URL for Windows.
  final String? windows;

  /// Store URL for Linux.
  final String? linux;

  /// Store URL for Web.
  final String? web;
}
