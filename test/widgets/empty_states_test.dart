import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/design/typography.dart';
import 'package:expenso/widgets/empty_state_widget.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          headlineLarge: AppTypography.heroTitle,
          titleMedium: AppTypography.listItemTitle,
          bodyLarge: AppTypography.bodyPrimary,
          bodyMedium: AppTypography.bodySecondary,
          titleSmall: AppTypography.subheader,
          bodySmall: AppTypography.caption,
        ),
      ),
      home: Scaffold(body: child),
    );
  }

  group('EmptyStateWidget', () {
    testWidgets('no-expenses shows "No expenses yet"', (tester) async {
      await tester.pumpWidget(
        wrap(const EmptyStateWidget(type: 'no-expenses')),
      );
      expect(find.text('No expenses yet'), findsOneWidget);
    });

    testWidgets('no-groups shows "No groups yet" and Create Group button', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const EmptyStateWidget(type: 'no-groups')),
      );
      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.text('Create Group'), findsOneWidget);
    });

    testWidgets('new-cycle shows "New cycle started"', (tester) async {
      await tester.pumpWidget(
        wrap(const EmptyStateWidget(type: 'new-cycle')),
      );
      expect(find.text('New cycle started'), findsOneWidget);
    });

    testWidgets('zero-waste-cycle shows "Zero-Waste Cycle"', (tester) async {
      await tester.pumpWidget(
        wrap(const EmptyStateWidget(type: 'zero-waste-cycle')),
      );
      expect(find.text('No expenses yet ...'), findsOneWidget);
    });
  });
}
