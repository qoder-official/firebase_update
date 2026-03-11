import 'dart:developer';

import 'package:app_review/app_review.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store_launcher.dart';

class AppReviewStoreLauncher implements StoreLauncher {
  const AppReviewStoreLauncher();

  @override
  Future<bool> launch({String? packageName, String? fallbackUrl}) async {
    // Priority 1: URL from Remote Config or fallbackStoreUrls config.
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      final uri = Uri.tryParse(fallbackUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    // Priority 2: Android packageName override opens a specific listing
    // (e.g. production app from a staging build) via the market:// scheme.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        packageName != null) {
      final marketUri = Uri.parse('market://details?id=$packageName');
      if (await canLaunchUrl(marketUri)) {
        return launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
    }

    // Priority 3: Let app_review open the store listing for the running app
    // using its own package name / bundle identifier automatically.
    try {
      await AppReview.storeListing();
      return true;
    } catch (e) {
      log('firebase_update: AppReview.storeListing() failed: $e — '
          'falling back to store home page.');
    }

    // Priority 4: Open the store home page — no specific app required.
    // Used when the app is not yet published (e.g. a staging build) or when
    // AppReview cannot resolve the listing.
    // Skip canLaunchUrl: custom schemes (market://, ms-windows-store://)
    // require LSApplicationQueriesSchemes / intent declarations that host apps
    // may not have; launchUrl itself is the real availability check.
    final storeHomeUri = _storeHomeUri();
    if (storeHomeUri != null) {
      try {
        return await launchUrl(
          storeHomeUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        log('firebase_update: failed to open store home ($storeHomeUri): $e');
      }
    }

    return false;
  }

  static Uri? _storeHomeUri() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // market:// opens the Play Store app directly; falls back to HTTPS
        // in browsers if the Play Store is not installed.
        return Uri.parse('market://search?q=apps');
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // https://apps.apple.com/ is handled natively by the OS — no custom
        // scheme declaration needed in Info.plist.
        return Uri.parse('https://apps.apple.com/');
      case TargetPlatform.windows:
        return Uri.parse('ms-windows-store://');
      default:
        return null;
    }
  }
}
