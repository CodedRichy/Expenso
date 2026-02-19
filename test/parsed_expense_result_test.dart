import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/services/groq_expense_parser_service.dart';

void main() {
  group('ParsedExpenseResult.fromJson', () {
    test('parses even split with amount and description', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 600,
        'description': 'Dinner',
        'category': 'Food',
        'splitType': 'even',
        'participants': ['A', 'B'],
      });
      expect(result.amount, 600.0);
      expect(result.description, 'Dinner');
      expect(result.category, 'Food');
      expect(result.splitType, 'even');
      expect(result.participantNames, ['A', 'B']);
      expect(result.payerName, isNull);
      expect(result.excludedNames, isEmpty);
      expect(result.exactAmountsByName, isEmpty);
    });

    test('parses exact split with exactAmounts', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 500,
        'description': 'Lunch',
        'category': 'Food',
        'splitType': 'exact',
        'participants': [],
        'exactAmounts': {'A': 200, 'B': 300},
      });
      expect(result.amount, 500.0);
      expect(result.splitType, 'exact');
      expect(result.exactAmountsByName, {'A': 200.0, 'B': 300.0});
    });

    test('parses exclude split with excluded list', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 900,
        'description': 'Taxi',
        'category': 'Transport',
        'splitType': 'exclude',
        'participants': ['A', 'B', 'C'],
        'excluded': ['C'],
      });
      expect(result.amount, 900.0);
      expect(result.splitType, 'exclude');
      expect(result.excludedNames, ['C']);
    });

    test('parses payer when set', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 500,
        'description': 'Snacks',
        'category': 'Food',
        'splitType': 'even',
        'participants': [],
        'payer': 'B',
      });
      expect(result.payerName, 'B');
    });

    test('defaults to even when splitType unknown', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 100,
        'description': 'Misc',
        'category': '',
        'splitType': 'unknown',
        'participants': [],
      });
      expect(result.splitType, 'even');
    });

    test('handles missing or invalid amount', () {
      final result = ParsedExpenseResult.fromJson({
        'description': 'Test',
        'splitType': 'even',
        'participants': [],
      });
      expect(result.amount, 0.0);
      final result2 = ParsedExpenseResult.fromJson({
        'amount': 'not a number',
        'description': 'Test',
        'splitType': 'even',
        'participants': [],
      });
      expect(result2.amount, 0.0);
    });

    test('partial success: valid amount with empty description yields description in fromJson', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 100,
        'description': '',
        'splitType': 'even',
        'participants': [],
      });
      expect(result.amount, 100.0);
      expect(result.description, '');
      expect(result.participantNames, isEmpty);
    });

    test('parses percentage split with percentageAmounts', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 1000,
        'description': 'Rent',
        'category': '',
        'splitType': 'percentage',
        'participants': [],
        'percentageAmounts': {'A': 60, 'B': 40},
      });
      expect(result.amount, 1000.0);
      expect(result.splitType, 'percentage');
      expect(result.percentageByName, {'A': 60.0, 'B': 40.0});
    });

    test('parses shares split with sharesAmounts', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 1500,
        'description': 'Airbnb',
        'category': '',
        'splitType': 'shares',
        'participants': [],
        'sharesAmounts': {'A': 2, 'B': 3},
      });
      expect(result.amount, 1500.0);
      expect(result.splitType, 'shares');
      expect(result.sharesByName, {'A': 2.0, 'B': 3.0});
    });

    test('even with one participant: split between me and them (e.g. dinner with B 300)', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 300,
        'description': 'Dinner',
        'category': 'Food',
        'splitType': 'even',
        'participants': ['B'],
      });
      expect(result.amount, 300.0);
      expect(result.splitType, 'even');
      expect(result.participantNames, ['B']);
      expect(result.payerName, isNull);
    });

    test('even split general rule: N participantNames => N+1 people, perShare = amount/(N+1)', () {
      const amount = 900.0;
      for (final n in [1, 2, 3, 5]) {
        final names = List.generate(n, (i) => 'Person${i + 1}');
        final result = ParsedExpenseResult.fromJson({
          'amount': amount,
          'description': 'Split test',
          'splitType': 'even',
          'participants': names,
        });
        expect(result.participantNames.length, n);
        final splitCount = result.participantNames.length + 1;
        final perShare = amount / splitCount;
        expect(splitCount, n + 1);
        expect(perShare, amount / (n + 1));
      }
    });
  });
}
