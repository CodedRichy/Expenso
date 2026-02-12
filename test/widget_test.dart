// Basic Flutter widget test for Expenso.
// Verifies that the app builds and shows the initial screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expenso/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that the MaterialApp (Expenso) is built.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
