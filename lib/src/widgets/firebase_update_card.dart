import 'package:flutter/material.dart';

import '../controller/firebase_update.dart';
import '../models/firebase_update_kind.dart';
import '../models/firebase_update_state.dart';
import 'firebase_update_builder.dart';

/// An inline card widget that reacts to [FirebaseUpdateState] in real time.
///
/// Renders nothing ([SizedBox.shrink]) when the state is [FirebaseUpdateKind.idle]
/// or [FirebaseUpdateKind.upToDate]. For all other states it displays a
/// styled surface card with the resolved title, message, and an action button.
///
/// Drop this into a settings screen, home feed, or any scrollable layout to
/// give users a persistent update prompt without a modal dialog.
///
/// ```dart
/// FirebaseUpdateCard(
///   onUpdateTap: () => FirebaseUpdate.instance.launchStore(),
/// )
/// ```
///
/// Provide [onUpdateTap] to override the default store-launch behavior, or
/// leave it `null` to use the package's built-in store launch.
///
/// For optional-update states the card also shows a "Later" button that
/// calls [onLaterTap] when provided. When [onLaterTap] is `null` the button
/// calls [FirebaseUpdate.instance.dismissOptionalUpdateForSession].
class FirebaseUpdateCard extends StatelessWidget {
  const FirebaseUpdateCard({
    super.key,
    this.onUpdateTap,
    this.onLaterTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.elevation = 0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  /// Called when the primary action button ("Update now") is tapped.
  ///
  /// When `null`, the package's default store-launch flow is used.
  final VoidCallback? onUpdateTap;

  /// Called when the secondary action button ("Later") is tapped on an
  /// optional-update card.
  ///
  /// When `null`, [FirebaseUpdate.instance.dismissOptionalUpdateForSession]
  /// is called instead.
  final VoidCallback? onLaterTap;

  /// Outer margin around the card. Defaults to horizontal 16, vertical 8.
  final EdgeInsetsGeometry margin;

  /// Material elevation of the card surface. Defaults to 0 (flat, tinted).
  final double elevation;

  /// Corner radius of the card. Defaults to 16.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return FirebaseUpdateBuilder(
      builder: (context, state) => _buildCard(context, state),
    );
  }

  Widget _buildCard(BuildContext context, FirebaseUpdateState state) {
    if (state.kind == FirebaseUpdateKind.idle ||
        state.kind == FirebaseUpdateKind.upToDate) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (Color surface, Color onSurface, IconData icon) =
        switch (state.kind) {
      FirebaseUpdateKind.forceUpdate => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.system_update_rounded,
        ),
      FirebaseUpdateKind.maintenance => (
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
          Icons.build_rounded,
        ),
      FirebaseUpdateKind.shorebirdPatch => (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          Icons.auto_fix_high_rounded,
        ),
      _ => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          Icons.new_releases_rounded,
        ),
    };

    final title = _resolveTitle(state);
    final message = state.message ?? '';
    final isOptional = state.kind == FirebaseUpdateKind.optionalUpdate;
    final isBlocking = state.kind == FirebaseUpdateKind.forceUpdate ||
        state.kind == FirebaseUpdateKind.maintenance;

    return Padding(
      padding: margin,
      child: Material(
        color: surface,
        elevation: elevation,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: onSurface, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isOptional)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: onSurface,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        if (onLaterTap != null) {
                          onLaterTap!();
                        } else {
                          final v = state.latestVersion;
                          if (v != null) {
                            FirebaseUpdate.instance
                                .dismissOptionalUpdateForSession();
                          }
                        }
                      },
                      child: Text(_laterLabel),
                    ),
                  if (isOptional) const SizedBox(width: 4),
                  if (!isBlocking ||
                      state.kind == FirebaseUpdateKind.forceUpdate)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: onSurface,
                        foregroundColor: surface,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      onPressed: onUpdateTap,
                      child: Text(_updateLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveTitle(FirebaseUpdateState state) {
    if (state.title != null) return state.title!;
    return switch (state.kind) {
      FirebaseUpdateKind.forceUpdate => 'Update required',
      FirebaseUpdateKind.maintenance => 'Under maintenance',
      FirebaseUpdateKind.shorebirdPatch => 'Patch available',
      _ => 'Update available',
    };
  }

  String get _updateLabel => 'Update now';
  String get _laterLabel => 'Later';
}
