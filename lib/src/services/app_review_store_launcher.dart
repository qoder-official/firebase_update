import 'package:app_review/app_review.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store_launcher.dart';

class AppReviewStoreLauncher implements StoreLauncher {
  const AppReviewStoreLauncher();

  @override
  Future<bool> launch({String? packageName, String? fallbackUrl}) async {
    // On Android, a packageName override lets us open a specific listing
    // (e.g. production app from a staging build) via the market:// scheme.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        packageName != null) {
      final marketUri = Uri.parse('market://details?id=$packageName');
      if (await canLaunchUrl(marketUri)) {
        return launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
    }

    // Default: let app_review open the store listing for the running app
    // using its own package name / bundle identifier automatically.
    try {
      await AppReview.storeListing();
      return true;
    } catch (_) {
      // Native launch failed — try the fallback URL.
      final uri = Uri.tryParse(fallbackUrl ?? '');
      if (uri == null) return false;
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
