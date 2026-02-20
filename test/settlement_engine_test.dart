import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/models/models.dart';
import 'package:expenso/utils/settlement_engine.dart';

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
}
