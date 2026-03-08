import 'package:flutter/widgets.dart';

import '../controller/firebase_update.dart';
import '../models/firebase_update_state.dart';

class FirebaseUpdateBuilder extends StatelessWidget {
  const FirebaseUpdateBuilder({super.key, required this.builder});

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
