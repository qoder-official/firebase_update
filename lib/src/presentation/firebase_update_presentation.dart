import 'package:flutter/material.dart';

import '../models/firebase_update_state.dart';

/// Signature for a builder that replaces the default package-managed modal
/// with a custom widget.
typedef FirebaseUpdateViewBuilder =
    Widget Function(BuildContext context, FirebaseUpdatePresentationData data);

/// Signature for a builder that provides a custom icon for the default
/// update panel.
typedef FirebaseUpdateIconBuilder =
    Widget Function(BuildContext context, FirebaseUpdateState state);

/// Controls how the default package-managed presentation looks and which
/// components, if any, are replaced by custom builders.
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

  /// Whether optional updates should be presented as a bottom sheet rather
  /// than a dialog. Defaults to `true`. Can be overridden per-config by
  /// [FirebaseUpdateConfig.useBottomSheetForOptionalUpdate].
  final bool useBottomSheetForOptionalUpdate;

  /// Theme tokens applied to the default presentation widgets.
  final FirebaseUpdatePresentationTheme theme;

  /// Replaces the default optional-update dialog with a custom widget.
  /// Receives [FirebaseUpdatePresentationData] including tap callbacks.
  final FirebaseUpdateViewBuilder? optionalUpdateDialogBuilder;

  /// Replaces the default optional-update bottom sheet with a custom widget.
  final FirebaseUpdateViewBuilder? optionalUpdateBottomSheetBuilder;

  /// Replaces the default force-update dialog with a custom widget.
  final FirebaseUpdateViewBuilder? forceUpdateDialogBuilder;

  /// Replaces the default maintenance dialog with a custom widget.
  final FirebaseUpdateViewBuilder? maintenanceDialogBuilder;

  /// Provides a custom icon widget shown at the top of the default update
  /// panel.
  final FirebaseUpdateIconBuilder? iconBuilder;
}

/// Theme tokens for the default package-managed update and maintenance UI.
///
/// All properties are optional. Unset properties fall back to values derived
/// from the host app's [ThemeData].
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

  /// Color used for primary action buttons and accent elements.
  /// Defaults to `colorScheme.primary`.
  final Color? accentColor;

  /// Foreground color on [accentColor] surfaces.
  /// Defaults to `colorScheme.onPrimary`.
  final Color? accentForegroundColor;

  /// Card and modal surface background color.
  /// Defaults to `colorScheme.surfaceContainerHighest`.
  final Color? surfaceColor;

  /// Primary text and icon color inside the card.
  /// Defaults to `colorScheme.onSurface`.
  final Color? contentColor;

  /// Secondary/muted text color. Not currently applied by the default
  /// presenter but available for custom builders.
  final Color? mutedContentColor;

  /// Border and divider color.
  /// Defaults to `colorScheme.outlineVariant`.
  final Color? outlineColor;

  /// Color of the modal barrier shown behind dialogs and sheets.
  final Color? barrierColor;

  /// Blur sigma applied to the background behind dialogs. `null` or `0`
  /// disables blur.
  final double? dialogBackgroundBlurSigma;

  /// Blur sigma applied to the background behind the optional-update bottom
  /// sheet. `null` or `0` disables blur.
  final double? bottomSheetBackgroundBlurSigma;

  /// Optional hero gradient painted on the inner update card.
  final Gradient? heroGradient;

  /// Border radius applied to the dialog container.
  final BorderRadiusGeometry dialogBorderRadius;

  /// Border radius applied to the bottom sheet container.
  final BorderRadiusGeometry sheetBorderRadius;
}

/// Data provided to custom presentation builders.
///
/// Contains the resolved title, the current [FirebaseUpdateState], button
/// labels, and tap callbacks wired to the correct package behavior.
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

  /// The resolved dialog or sheet title.
  final String title;

  /// The current [FirebaseUpdateState] that triggered this presentation.
  final FirebaseUpdateState state;

  /// Whether the user is blocked from dismissing this presentation.
  final bool isBlocking;

  /// Label for the primary CTA button (e.g. 'Update now').
  final String primaryLabel;

  /// Callback for the primary CTA. Launches the store and pops the modal.
  final VoidCallback? onPrimaryTap;

  /// Label for the secondary/dismiss button (e.g. 'Later').
  final String? secondaryLabel;

  /// Callback for the secondary/dismiss button. Pops the modal.
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
