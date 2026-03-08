import 'package:flutter/widgets.dart';

import 'example_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeExampleFirebaseUpdate();
  runApp(const FirebaseUpdateExampleApp());
}
