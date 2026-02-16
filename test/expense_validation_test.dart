import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/utils/expense_validation.dart';

void main() {
  group('validateExpenseAmount', () {
    test('returns null for positive amount', () {
      expect(validateExpenseAmount(1), isNull);
      expect(validateExpenseAmount(100.5), isNull);
    });

    test('returns error for zero or negative', () {
      expect(validateExpenseAmount(0), isNotNull);
      expect(validateExpenseAmount(-10), isNotNull);
    });

    test('returns error for NaN', () {
      expect(validateExpenseAmount(double.nan), isNotNull);
    });
  });

  group('validateExpenseDescription', () {
    test('returns null for non-empty description', () {
      expect(validateExpenseDescription('Dinner'), isNull);
      expect(validateExpenseDescription('  Lunch  '), isNull);
    });

    test('returns error for empty or whitespace', () {
      expect(validateExpenseDescription(''), isNotNull);
      expect(validateExpenseDescription('   '), isNotNull);
    });
  });
}
