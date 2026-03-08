import 'package:package_info_plus/package_info_plus.dart';

import 'app_version_provider.dart';

class PackageInfoAppVersionProvider implements AppVersionProvider {
  const PackageInfoAppVersionProvider();

  @override
  Future<String?> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version.trim();
    if (version.isEmpty) {
      return null;
    }
    return version;
  }
}
