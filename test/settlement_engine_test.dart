import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/models/models.dart';
import 'package:expenso/models/money_minor.dart';
import 'package:expenso/utils/settlement_engine.dart';
import 'package:expenso/utils/ledger_delta.dart';

void main() {
  final memberRishi = Member(id: 'u1', phone: 'p_rishi', name: 'Rishi');
  final memberRockey = Member(id: 'u2', phone: 'p_rockey', name: 'Rockey');
  final members = [memberRishi, memberRockey];

  Expense expense({
    required String id,
    required double amount,
    required String paidById,
    List<String>? participantIds,
    Map<String, double>? splitAmountsById,
  }) {
    return Expense(
      id: id,
      description: 'Test',
      amount: amount,
      date: 'Today',
      participantIds: participantIds ?? [],
      paidById: paidById,
      splitAmountsById: splitAmountsById,
    );
  }

  group('SettlementEngine.computeNetBalances (integer-based)', () {
    test('even split: one paid, two share - payer gets credit others owe', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['u1'], 15000);
      expect(net['u2'], -15000);
    });

    test('exact split: amounts match total', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 500,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 200, 'u2': 300},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['u1'], 30000);
      expect(net['u2'], -30000);
    });

    test('multiple expenses net correctly', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 100,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 50, 'u2': 50},
        ),
        expense(
          id: 'e2',
          amount: 100,
          paidById: 'u2',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 50, 'u2': 50},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['u1'], 0);
      expect(net['u2'], 0);
    });
  });

  group('SettlementEngine.computeDebts (integer-based)', () {
    test('single debtor owes single creditor', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];
      final debts = SettlementEngine.computeDebts(expenses, members);
      expect(debts.length, 1);
      expect(debts[0].fromId, 'u2');
      expect(debts[0].toId, 'u1');
      expect(debts[0].amountMinor, 15000);
    });

    test('balanced expenses yield no debts', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 200,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 100, 'u2': 100},
        ),
        expense(
          id: 'e2',
          amount: 200,
          paidById: 'u2',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 100, 'u2': 100},
        ),
      ];
      final debts = SettlementEngine.computeDebts(expenses, members);
      expect(debts, isEmpty);
    });
  });

  group('SettlementEngine delta-based computation (integer)', () {
    test('computeNetBalancesFromDeltas returns integer balances', () {
      final deltas = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
        LedgerDelta(
          memberId: 'u2',
          delta: MoneyMinor(-15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
      ];

      final net = SettlementEngine.computeNetBalancesFromDeltas(deltas, 'INR');
      expect(net['u1'], 15000);
      expect(net['u2'], -15000);
    });

    test('computeDebtsFromDeltas returns Debt with MoneyMinor', () {
      final deltas = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
        LedgerDelta(
          memberId: 'u2',
          delta: MoneyMinor(-15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
      ];

      final debts = SettlementEngine.computeDebtsFromDeltas(deltas, 'INR');
      expect(debts.length, 1);
      expect(debts[0].fromId, 'u2');
      expect(debts[0].toId, 'u1');
      expect(debts[0].amountMinor, 15000);
      expect(debts[0].currencyCode, 'INR');
    });

    test('rejects mixed currencies in deltas', () {
      final deltas = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
        LedgerDelta(
          memberId: 'u2',
          delta: MoneyMinor(-15000, 'USD'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
      ];

      expect(
        () => SettlementEngine.computeNetBalancesFromDeltas(deltas, 'INR'),
        throwsArgumentError,
      );
    });

    test('expenseToDeltas produces correct deltas', () {
      final exp = expense(
        id: 'e1',
        amount: 300,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 150, 'u2': 150},
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      final deltaMap = {for (final d in deltas) d.memberId: d.deltaMinor};

      expect(deltaMap['u1'], 15000);
      expect(deltaMap['u2'], -15000);
    });

    test('delta sum is always exactly zero (integer)', () {
      final exp = expense(
        id: 'e1',
        amount: 500,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 200, 'u2': 300},
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);

      expect(sum, 0);
    });

    test('invalid expense returns empty deltas', () {
      final invalidExp = expense(
        id: 'e1',
        amount: -100,
        paidById: 'u1',
        participantIds: ['u1'],
        splitAmountsById: {'u1': -100},
      );

      final deltas = SettlementEngine.expenseToDeltas(invalidExp);
      expect(deltas, isEmpty);
    });

    test('expense with empty payer returns empty deltas', () {
      final noPayerExp = expense(
        id: 'e1',
        amount: 100,
        paidById: '',
        participantIds: ['u1'],
        splitAmountsById: {'u1': 100},
      );

      final deltas = SettlementEngine.expenseToDeltas(noPayerExp);
      expect(deltas, isEmpty);
    });

    test('multiple expenses delta computation', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 100,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 50, 'u2': 50},
        ),
        expense(
          id: 'e2',
          amount: 100,
          paidById: 'u2',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 50, 'u2': 50},
        ),
      ];

      final deltas = SettlementEngine.expensesToDeltas(expenses);
      final net = SettlementEngine.computeNetBalancesFromDeltas(deltas, 'INR');

      expect(net['u1'], 0);
      expect(net['u2'], 0);
    });
  });

  group('expenseToLedgerDeltas function (integer-based)', () {
    test('produces correct deltas from integer expense data', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 30000,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 15000, 'u2': 15000},
        currencyCode: 'INR',
        timestamp: DateTime.now(),
      );

      final deltaMap = {for (final d in deltas) d.memberId: d.deltaMinor};
      expect(deltaMap['u1'], 15000);
      expect(deltaMap['u2'], -15000);
    });

    test('skips pending member IDs in splits', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 30000,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 15000, 'p_pending': 15000},
        currencyCode: 'INR',
        timestamp: DateTime.now(),
      );

      expect(deltas.any((d) => d.memberId.startsWith('p_')), false);
    });

    test('returns empty for invalid amount', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 0,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 0},
        currencyCode: 'INR',
        timestamp: DateTime.now(),
      );

      expect(deltas, isEmpty);
    });

    test('deltas sum to exactly zero', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 50000,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 20000, 'u2': 30000},
        currencyCode: 'INR',
        timestamp: DateTime.now(),
      );

      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      expect(sum, 0);
    });
  });

  group('Legacy adapter compatibility', () {
    test('expenseToLedgerDeltasLegacy converts doubles to integers', () {
      final deltas = expenseToLedgerDeltasLegacy(
        expenseId: 'e1',
        amount: 300.50,
        payerId: 'u1',
        splitAmountsById: {'u1': 150.25, 'u2': 150.25},
        currencyCode: 'INR',
        timestamp: DateTime.now(),
      );

      final deltaMap = {for (final d in deltas) d.memberId: d.deltaMinor};
      expect(deltaMap['u1'], 15025);
      expect(deltaMap['u2'], -15025);
    });

    test('computeNetBalancesAsDouble returns display values', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];
      final net = SettlementEngine.computeNetBalancesAsDouble(expenses, members);
      expect(net['u1'], 150.0);
      expect(net['u2'], -150.0);
    });
  });

  group('Multi-currency settlement', () {
    test('JPY: deltas in minor units (no decimals)', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 3000,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 1500, 'u2': 1500},
        currencyCode: 'JPY',
        timestamp: DateTime.now(),
      );

      expect(deltas.every((d) => d.currencyCode == 'JPY'), true);
      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      expect(sum, 0);
    });

    test('KWD: deltas in fils (3 decimal places)', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 3000,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 1500, 'u2': 1500},
        currencyCode: 'KWD',
        timestamp: DateTime.now(),
      );

      expect(deltas.every((d) => d.currencyCode == 'KWD'), true);
      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      expect(sum, 0);
    });
  });
}
