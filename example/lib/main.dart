import 'package:flutter/widgets.dart';
import 'package:firebase_update_example/example_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeExampleFirebaseUpdate();
  runApp(const FirebaseUpdateExampleApp());
}
