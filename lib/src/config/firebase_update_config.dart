import 'package:flutter/foundation.dart';

import '../presentation/firebase_update_presentation.dart';
import 'firebase_update_fallback_store_urls.dart';
import 'firebase_update_field_mapping.dart';

@immutable
class FirebaseUpdateConfig {
  const FirebaseUpdateConfig({
    required this.remoteConfigKey,
    required this.fields,
    this.currentVersion,
    this.fallbackStoreUrls = const FirebaseUpdateFallbackStoreUrls(),
    this.fetchTimeout = const Duration(seconds: 60),
    this.minimumFetchInterval = const Duration(hours: 12),
    this.listenToRealtimeUpdates = true,
    this.enableDefaultPresentation = true,
    this.useBottomSheetForOptionalUpdate,
    this.presentation = const FirebaseUpdatePresentation(),
  });

  final String remoteConfigKey;
  final FirebaseUpdateFieldMapping fields;
  final String? currentVersion;
  final FirebaseUpdateFallbackStoreUrls fallbackStoreUrls;
  final Duration fetchTimeout;
  final Duration minimumFetchInterval;
  final bool listenToRealtimeUpdates;
  final bool enableDefaultPresentation;
  final bool? useBottomSheetForOptionalUpdate;
  final FirebaseUpdatePresentation presentation;

  bool get resolvesOptionalUpdateAsBottomSheet =>
      useBottomSheetForOptionalUpdate ??
      presentation.useBottomSheetForOptionalUpdate;
}
