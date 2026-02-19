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
    required String paidByPhone,
    List<String>? participantPhones,
    Map<String, double>? splitAmountsByPhone,
  }) {
    return Expense(
      id: id,
      description: 'Test',
      amount: amount,
      date: 'Today',
      participantPhones: participantPhones ?? [],
      paidByPhone: paidByPhone,
      splitAmountsByPhone: splitAmountsByPhone,
    );
  }

  group('SettlementEngine.computeNetBalances', () {
    test('even split: one paid, two share - payer gets credit others owe', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidByPhone: 'p_rishi',
          participantPhones: ['p_rishi', 'p_rockey'],
          splitAmountsByPhone: {'p_rishi': 150, 'p_rockey': 150},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['p_rishi'], 150);
      expect(net['p_rockey'], -150);
    });

    test('empty participantPhones uses all members (even split)', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 40,
          paidByPhone: 'p_rockey',
          participantPhones: [],
          splitAmountsByPhone: null,
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['p_rishi'], -20);
      expect(net['p_rockey'], 20);
    });

    test('exact split: amounts match total', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 500,
          paidByPhone: 'p_rishi',
          participantPhones: ['p_rishi', 'p_rockey'],
          splitAmountsByPhone: {'p_rishi': 200, 'p_rockey': 300},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['p_rishi'], 300);
      expect(net['p_rockey'], -300);
    });

    test('multiple expenses net correctly', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 100,
          paidByPhone: 'p_rishi',
          participantPhones: ['p_rishi', 'p_rockey'],
          splitAmountsByPhone: {'p_rishi': 50, 'p_rockey': 50},
        ),
        expense(
          id: 'e2',
          amount: 100,
          paidByPhone: 'p_rockey',
          participantPhones: ['p_rishi', 'p_rockey'],
          splitAmountsByPhone: {'p_rishi': 50, 'p_rockey': 50},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['p_rishi'], 0);
      expect(net['p_rockey'], 0);
    });
  });

  group('SettlementEngine.computeDebts', () {
    test('single debtor owes single creditor', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidByPhone: 'p_rishi',
          participantPhones: ['p_rishi', 'p_rockey'],
          splitAmountsByPhone: {'p_rishi': 150, 'p_rockey': 150},
        ),
      ];
      final debts = SettlementEngine.computeDebts(expenses, members);
      expect(debts.length, 1);
      expect(debts[0].fromPhone, 'p_rockey');
      expect(debts[0].toPhone, 'p_rishi');
      expect(debts[0].amount, closeTo(150, 0.01));
    });

    test('balanced expenses yield no debts', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 200,
          paidByPhone: 'p_rishi',
          participantPhones: ['p_rishi', 'p_rockey'],
          splitAmountsByPhone: {'p_rishi': 100, 'p_rockey': 100},
        ),
        expense(
          id: 'e2',
          amount: 200,
          paidByPhone: 'p_rockey',
          participantPhones: ['p_rishi', 'p_rockey'],
          splitAmountsByPhone: {'p_rishi': 100, 'p_rockey': 100},
        ),
      ];
      final debts = SettlementEngine.computeDebts(expenses, members);
      expect(debts, isEmpty);
    });
  });
}
