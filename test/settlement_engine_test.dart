import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/models/models.dart';
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

  group('SettlementEngine.computeNetBalances', () {
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
      expect(net['u1'], 150);
      expect(net['u2'], -150);
    });

    test('empty participantIds uses all members (even split)', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 40,
          paidById: 'u2',
          participantIds: [],
          splitAmountsById: null,
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['u1'], -20);
      expect(net['u2'], 20);
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
      expect(net['u1'], 300);
      expect(net['u2'], -300);
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

  group('SettlementEngine.computeDebts', () {
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
      expect(debts[0].amount, closeTo(150, 0.01));
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

  group('SettlementEngine delta-based computation', () {
    test('computeNetBalancesFromDeltas matches computeNetBalances', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];

      final legacyNet = SettlementEngine.computeNetBalances(expenses, members);
      final deltas = SettlementEngine.expensesToDeltas(expenses);
      final deltaNet = SettlementEngine.computeNetBalancesFromDeltas(deltas);

      expect(deltaNet['u1'], closeTo(legacyNet['u1']!, 0.01));
      expect(deltaNet['u2'], closeTo(legacyNet['u2']!, 0.01));
    });

    test('computeDebtsFromDeltas matches computeDebts', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];

      final legacyDebts = SettlementEngine.computeDebts(expenses, members);
      final deltas = SettlementEngine.expensesToDeltas(expenses);
      final deltaDebts = SettlementEngine.computeDebtsFromDeltas(deltas);

      expect(deltaDebts.length, legacyDebts.length);
      if (deltaDebts.isNotEmpty) {
        expect(deltaDebts[0].fromId, legacyDebts[0].fromId);
        expect(deltaDebts[0].toId, legacyDebts[0].toId);
        expect(deltaDebts[0].amount, closeTo(legacyDebts[0].amount, 0.01));
      }
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
      final deltaMap = {for (final d in deltas) d.memberId: d.delta};

      expect(deltaMap['u1'], closeTo(150, 0.01));
      expect(deltaMap['u2'], closeTo(-150, 0.01));
    });

    test('delta sum is always zero', () {
      final exp = expense(
        id: 'e1',
        amount: 500,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 200, 'u2': 300},
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      final sum = deltas.fold(0.0, (acc, d) => acc + d.delta);

      expect(sum.abs(), lessThan(0.01));
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
      final net = SettlementEngine.computeNetBalancesFromDeltas(deltas);

      expect(net['u1'], closeTo(0, 0.01));
      expect(net['u2'], closeTo(0, 0.01));
    });
  });

  group('expenseToLedgerDeltas function', () {
    test('produces correct deltas from raw expense data', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amount: 300,
        payerId: 'u1',
        splitAmountsById: {'u1': 150, 'u2': 150},
        timestamp: DateTime.now(),
      );

      final deltaMap = {for (final d in deltas) d.memberId: d.delta};
      expect(deltaMap['u1'], closeTo(150, 0.01));
      expect(deltaMap['u2'], closeTo(-150, 0.01));
    });

    test('skips pending member IDs in splits', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amount: 300,
        payerId: 'u1',
        splitAmountsById: {'u1': 150, 'p_pending': 150},
        timestamp: DateTime.now(),
      );

      expect(deltas.any((d) => d.memberId.startsWith('p_')), false);
    });

    test('returns empty for invalid amount', () {
      final deltas = expenseToLedgerDeltas(
        expenseId: 'e1',
        amount: 0,
        payerId: 'u1',
        splitAmountsById: {'u1': 0},
        timestamp: DateTime.now(),
      );

      expect(deltas, isEmpty);
    });
  });
}
