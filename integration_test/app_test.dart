import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:expenso/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows MaterialApp', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
