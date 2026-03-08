import 'package:flutter/widgets.dart';

import '../controller/firebase_update.dart';
import '../models/firebase_update_state.dart';

/// A widget that rebuilds whenever the [FirebaseUpdateState] changes.
///
/// Use this widget to build inline update banners, maintenance overlays, or
/// any other custom UI that needs to react to the current update state without
/// using the package-managed modal presentation.
///
/// ```dart
/// FirebaseUpdateBuilder(
///   builder: (context, state) {
///     if (state.kind == FirebaseUpdateKind.optionalUpdate) {
///       return UpdateBanner(version: state.latestVersion);
///     }
///     return const SizedBox.shrink();
///   },
/// )
/// ```
class FirebaseUpdateBuilder extends StatelessWidget {
  const FirebaseUpdateBuilder({super.key, required this.builder});

  /// Called on every state change with the current [FirebaseUpdateState].
  final Widget Function(BuildContext context, FirebaseUpdateState state)
  builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FirebaseUpdateState>(
      initialData: FirebaseUpdate.instance.currentState,
      stream: FirebaseUpdate.instance.stream,
      builder: (context, snapshot) {
        return builder(
          context,
          snapshot.data ?? const FirebaseUpdateState.idle(),
        );
      },
    );
  }
}
