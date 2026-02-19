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
        'participants': ['Alice', 'Bob'],
      });
      expect(result.amount, 600.0);
      expect(result.description, 'Dinner');
      expect(result.category, 'Food');
      expect(result.splitType, 'even');
      expect(result.participantNames, ['Alice', 'Bob']);
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
        'exactAmounts': {'Alice': 200, 'Bob': 300},
      });
      expect(result.amount, 500.0);
      expect(result.splitType, 'exact');
      expect(result.exactAmountsByName, {'Alice': 200.0, 'Bob': 300.0});
    });

    test('parses exclude split with excluded list', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 900,
        'description': 'Taxi',
        'category': 'Transport',
        'splitType': 'exclude',
        'participants': ['Alice', 'Bob', 'Carol'],
        'excluded': ['Carol'],
      });
      expect(result.amount, 900.0);
      expect(result.splitType, 'exclude');
      expect(result.excludedNames, ['Carol']);
    });

    test('parses payer when set', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 500,
        'description': 'Snacks',
        'category': 'Food',
        'splitType': 'even',
        'participants': [],
        'payer': 'Pradhyun',
      });
      expect(result.payerName, 'Pradhyun');
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
        'percentageAmounts': {'Alice': 60, 'Bob': 40},
      });
      expect(result.amount, 1000.0);
      expect(result.splitType, 'percentage');
      expect(result.percentageByName, {'Alice': 60.0, 'Bob': 40.0});
    });

    test('parses shares split with sharesAmounts', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 1500,
        'description': 'Airbnb',
        'category': '',
        'splitType': 'shares',
        'participants': [],
        'sharesAmounts': {'Alice': 2, 'Bob': 3},
      });
      expect(result.amount, 1500.0);
      expect(result.splitType, 'shares');
      expect(result.sharesByName, {'Alice': 2.0, 'Bob': 3.0});
    });

    test('even with one participant: split between me and them (e.g. dinner with Rockey 300)', () {
      final result = ParsedExpenseResult.fromJson({
        'amount': 300,
        'description': 'Dinner',
        'category': 'Food',
        'splitType': 'even',
        'participants': ['Rockey'],
      });
      expect(result.amount, 300.0);
      expect(result.splitType, 'even');
      expect(result.participantNames, ['Rockey']);
      expect(result.payerName, isNull);
    });
  });
}
