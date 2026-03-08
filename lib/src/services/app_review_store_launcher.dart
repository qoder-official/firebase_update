import 'package:app_review/app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store_launcher.dart';

class AppReviewStoreLauncher implements StoreLauncher {
  const AppReviewStoreLauncher();

  @override
  Future<bool> launch({String? fallbackUrl}) async {
    try {
      await AppReview.storeListing();
      return true;
    } catch (_) {
      final uri = Uri.tryParse(fallbackUrl ?? '');
      if (uri == null) {
        return false;
      }
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
