import 'package:flutter/foundation.dart';

/// Per-platform fallback store URLs used when native store-listing launch
/// fails.
///
/// At least one URL should be provided for each platform the app targets.
/// If a platform URL is `null` and native launch fails, the store CTA will
/// show a snackbar error instead.
@immutable
class FirebaseUpdateFallbackStoreUrls {
  const FirebaseUpdateFallbackStoreUrls({
    this.android,
    this.ios,
    this.macos,
    this.windows,
    this.linux,
    this.web,
  });

  /// Fallback URL for Android, typically a Google Play listing URL.
  final String? android;

  /// Fallback URL for iOS, typically an App Store product URL.
  final String? ios;

  /// Fallback URL for macOS, typically a Mac App Store product URL.
  final String? macos;

  /// Fallback URL for Windows.
  final String? windows;

  /// Fallback URL for Linux.
  final String? linux;

  /// Fallback URL for Web.
  final String? web;
}
