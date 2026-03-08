import 'package:flutter/material.dart';

import '../models/firebase_update_state.dart';

typedef FirebaseUpdateViewBuilder =
    Widget Function(BuildContext context, FirebaseUpdatePresentationData data);
typedef FirebaseUpdateIconBuilder =
    Widget Function(BuildContext context, FirebaseUpdateState state);

@immutable
class FirebaseUpdatePresentation {
  const FirebaseUpdatePresentation({
    this.useBottomSheetForOptionalUpdate = true,
    this.theme = const FirebaseUpdatePresentationTheme(),
    this.optionalUpdateDialogBuilder,
    this.optionalUpdateBottomSheetBuilder,
    this.forceUpdateDialogBuilder,
    this.maintenanceDialogBuilder,
    this.iconBuilder,
  });

  final bool useBottomSheetForOptionalUpdate;
  final FirebaseUpdatePresentationTheme theme;
  final FirebaseUpdateViewBuilder? optionalUpdateDialogBuilder;
  final FirebaseUpdateViewBuilder? optionalUpdateBottomSheetBuilder;
  final FirebaseUpdateViewBuilder? forceUpdateDialogBuilder;
  final FirebaseUpdateViewBuilder? maintenanceDialogBuilder;
  final FirebaseUpdateIconBuilder? iconBuilder;
}

@immutable
class FirebaseUpdatePresentationTheme {
  const FirebaseUpdatePresentationTheme({
    this.accentColor,
    this.accentForegroundColor,
    this.surfaceColor,
    this.contentColor,
    this.mutedContentColor,
    this.outlineColor,
    this.barrierColor,
    this.dialogBackgroundBlurSigma,
    this.bottomSheetBackgroundBlurSigma,
    this.heroGradient,
    this.dialogBorderRadius = const BorderRadius.all(Radius.circular(28)),
    this.sheetBorderRadius = const BorderRadius.vertical(
      top: Radius.circular(32),
    ),
  });

  final Color? accentColor;
  final Color? accentForegroundColor;
  final Color? surfaceColor;
  final Color? contentColor;
  final Color? mutedContentColor;
  final Color? outlineColor;
  final Color? barrierColor;
  final double? dialogBackgroundBlurSigma;
  final double? bottomSheetBackgroundBlurSigma;
  final Gradient? heroGradient;
  final BorderRadiusGeometry dialogBorderRadius;
  final BorderRadiusGeometry sheetBorderRadius;
}

@immutable
class FirebaseUpdatePresentationData {
  const FirebaseUpdatePresentationData({
    required this.title,
    required this.state,
    required this.isBlocking,
    required this.primaryLabel,
    required this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  final String title;
  final FirebaseUpdateState state;
  final bool isBlocking;
  final String primaryLabel;
  final VoidCallback? onPrimaryTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  FirebaseUpdatePresentationData copyWith({
    String? title,
    FirebaseUpdateState? state,
    bool? isBlocking,
    String? primaryLabel,
    VoidCallback? onPrimaryTap,
    String? secondaryLabel,
    VoidCallback? onSecondaryTap,
  }) {
    return FirebaseUpdatePresentationData(
      title: title ?? this.title,
      state: state ?? this.state,
      isBlocking: isBlocking ?? this.isBlocking,
      primaryLabel: primaryLabel ?? this.primaryLabel,
      onPrimaryTap: onPrimaryTap ?? this.onPrimaryTap,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      onSecondaryTap: onSecondaryTap ?? this.onSecondaryTap,
    );
  }
}
