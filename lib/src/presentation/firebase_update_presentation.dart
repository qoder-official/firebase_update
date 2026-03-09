import 'package:flutter/material.dart';

import '../models/firebase_update_state.dart';

/// Content alignment for the icon, title, and body text inside the default
/// update and maintenance panels.
///
/// See also [FirebaseUpdatePresentation.patchNotesAlignment] to control the
/// alignment of the release notes block independently.
enum FirebaseUpdateContentAlignment {
  /// Left-align content.
  start,

  /// Center-align content. This is the default for dialogs.
  center,

  /// Right-align content.
  end,
}

/// Fine-grained text style overrides for each text element in the default
/// update and maintenance panels.
///
/// Each property is **merged** on top of the computed base style — only the
/// properties you set are applied; everything else falls through to the app's
/// theme default.
///
/// ```dart
/// FirebaseUpdateTypography(
///   titleStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
///   primaryButtonStyle: TextStyle(letterSpacing: 0.5),
/// )
/// ```
@immutable
class FirebaseUpdateTypography {
  const FirebaseUpdateTypography({
    this.titleStyle,
    this.messageStyle,
    this.releaseNotesHeadingStyle,
    this.patchNotesStyle,
    this.readMoreStyle,
    this.primaryButtonStyle,
    this.secondaryButtonStyle,
  });

  /// Merged on top of [TextTheme.headlineSmall] + `contentColor` for the
  /// dialog / sheet title.
  final TextStyle? titleStyle;

  /// Merged on top of [TextTheme.bodyLarge] + `contentColor` for the body
  /// message.
  final TextStyle? messageStyle;

  /// Merged on top of [TextTheme.titleSmall] bold + `contentColor` for the
  /// 'Release notes' section heading.
  final TextStyle? releaseNotesHeadingStyle;

  /// Merged on top of [TextTheme.bodyMedium] + `contentColor` for the patch
  /// notes body text.
  final TextStyle? patchNotesStyle;

  /// Overrides the style of the 'Read more' / 'Show less' toggle link.
  /// The base style derives from [patchNotesStyle] with `accentColor` and
  /// semibold weight applied first, then this override is merged on top.
  final TextStyle? readMoreStyle;

  /// Text style applied to the primary action button label (e.g. 'Update now').
  final TextStyle? primaryButtonStyle;

  /// Text style applied to the secondary action button label (e.g. 'Later').
  final TextStyle? secondaryButtonStyle;
}

/// Customises every static string shown by the default update and maintenance
/// UI.
///
/// All properties are optional — unset properties fall back to the built-in
/// English defaults.
///
/// ```dart
/// FirebaseUpdateLabels(
///   updateNow: 'Install update',
///   later: 'Not now',
///   releaseNotesHeading: "What's new",
/// )
/// ```
@immutable
class FirebaseUpdateLabels {
  const FirebaseUpdateLabels({
    this.optionalUpdateTitle,
    this.forceUpdateTitle,
    this.maintenanceTitle,
    this.updateNow,
    this.later,
    this.okay,
    this.releaseNotesHeading,
    this.readMore,
    this.showLess,
  });

  /// Fallback title for optional update prompts when the Remote Config payload
  /// does not provide an `optional_update_title`.
  /// Defaults to `'Update available'`.
  final String? optionalUpdateTitle;

  /// Fallback title for force update prompts when the Remote Config payload
  /// does not provide a `force_update_title`.
  /// Defaults to `'Update required'`.
  final String? forceUpdateTitle;

  /// Fallback title for maintenance prompts when the Remote Config payload
  /// does not provide a `maintenance_title`.
  /// Defaults to `'Maintenance in progress'`.
  final String? maintenanceTitle;

  /// Label for the primary CTA on update prompts.
  /// Defaults to `'Update now'`.
  final String? updateNow;

  /// Label for the dismiss button on optional update prompts.
  /// Defaults to `'Later'`.
  final String? later;

  /// Label for the dismiss button on maintenance prompts (the modal stays
  /// until the Remote Config value changes).
  /// Defaults to `'Okay'`.
  final String? okay;

  /// Heading shown above the patch notes block.
  /// Defaults to `'Release notes'`.
  final String? releaseNotesHeading;

  /// Label for the expand link when patch notes are truncated.
  /// Defaults to `'Read more'`.
  final String? readMore;

  /// Label for the collapse link when patch notes are expanded.
  /// Defaults to `'Show less'`.
  final String? showLess;
}

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
    this.contentAlignment,
    this.patchNotesAlignment,
    this.typography = const FirebaseUpdateTypography(),
    this.labels = const FirebaseUpdateLabels(),
    this.theme = const FirebaseUpdatePresentationTheme(),
    this.iconBuilder,
  });

  /// Whether optional updates should be presented as a bottom sheet rather
  /// than a dialog. Defaults to `true`. Can be overridden per-config by
  /// [FirebaseUpdateConfig.useBottomSheetForOptionalUpdate].
  final bool useBottomSheetForOptionalUpdate;

  /// Alignment applied to the icon, title, and body text inside all default
  /// update and maintenance panels.
  ///
  /// When `null`, dialogs default to [FirebaseUpdateContentAlignment.center]
  /// and bottom sheets default to [FirebaseUpdateContentAlignment.start].
  final FirebaseUpdateContentAlignment? contentAlignment;

  /// Alignment applied specifically to the release notes block.
  ///
  /// Defaults to [FirebaseUpdateContentAlignment.start] regardless of
  /// [contentAlignment], because patch notes are typically multi-line text
  /// that reads best left-aligned even when the rest of the panel is centered.
  final FirebaseUpdateContentAlignment? patchNotesAlignment;

  /// Fine-grained text style overrides for individual text elements (title,
  /// message, patch notes, buttons, etc.).
  final FirebaseUpdateTypography typography;

  /// Overrides for every static string shown in the default update and
  /// maintenance UI.
  final FirebaseUpdateLabels labels;

  /// Theme tokens applied to the default presentation widgets.
  final FirebaseUpdatePresentationTheme theme;

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
