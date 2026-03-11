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
    } catch (_) {
      return false;
    }
  }
}
