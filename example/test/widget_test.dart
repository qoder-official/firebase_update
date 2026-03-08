import 'package:flutter_test/flutter_test.dart';

import 'package:firebase_update_example/example_app.dart';

void main() {
  testWidgets('example app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FirebaseUpdateExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('firebase_update'), findsOneWidget);
    expect(find.text('State Simulator (Local Overrides)'), findsOneWidget);
  });
}
