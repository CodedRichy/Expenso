import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/widgets/expenso_loader.dart';

void main() {
  group('ExpensoLoader', () {
    testWidgets('pumps and contains CustomPaint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: ExpensoLoader(size: 80)),
          ),
        ),
      );
      expect(find.byType(ExpensoLoader), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('respects size parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: ExpensoLoader(size: 120)),
          ),
        ),
      );
      final loader = tester.widget<ExpensoLoader>(find.byType(ExpensoLoader));
      expect(loader.size, 120);
    });
  });
}
