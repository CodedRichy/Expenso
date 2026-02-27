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

  // ============================================================
  // PHASE 2: Invariant Enforcement Tests (I7)
  // ============================================================
  // DEPLOYMENT GATE: Before deploying MONEY_PHASE2, Firestore must be verified
  // to contain no expenses with empty or invalid paidById. If such data exists,
  // it must be backfilled or quarantined.
  // ============================================================

  group('Phase 2: Invariant I7 - Empty/Invalid payer enforcement', () {
    test('empty paidById produces no credit (no deltas)', () {
      final exp = expense(
        id: 'e1',
        amount: 300,
        paidById: '',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 150, 'u2': 150},
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      expect(deltas, isEmpty, reason: 'Empty paidById must yield no deltas');
    });

    test('empty paidById does not affect net balances', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: '',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];

      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['u1'], 0, reason: 'Empty paidById expense must not affect balances');
      expect(net['u2'], 0, reason: 'Empty paidById expense must not affect balances');
    });

    test('unknown paidById (not in members) does not affect member balances', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'unknown_user',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];

      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['u1'], -15000, reason: 'u1 still debited for their share');
      expect(net['u2'], -15000, reason: 'u2 still debited for their share');
      expect(net.containsKey('unknown_user'), false, reason: 'Unknown payer not in balances');
    });

    test('pending member paidById (p_ prefix) produces no deltas', () {
      final exp = expense(
        id: 'e1',
        amount: 300,
        paidById: 'p_pending123',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 150, 'u2': 150},
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      expect(deltas, isEmpty, reason: 'Pending member payer must yield no deltas');
    });
  });

  group('Phase 2: Invalid amount enforcement', () {
    test('zero amount expense produces empty deltas', () {
      final exp = expense(
        id: 'e1',
        amount: 0,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 0, 'u2': 0},
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      expect(deltas, isEmpty);
    });

    test('negative amount expense produces empty deltas', () {
      final exp = expense(
        id: 'e1',
        amount: -100,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': -50, 'u2': -50},
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      expect(deltas, isEmpty);
    });

    test('NaN amount expense produces empty deltas', () {
      final exp = expense(
        id: 'e1',
        amount: double.nan,
        paidById: 'u1',
        participantIds: ['u1'],
        splitAmountsById: null,
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      expect(deltas, isEmpty);
    });

    test('Infinite amount expense produces empty deltas', () {
      final exp = expense(
        id: 'e1',
        amount: double.infinity,
        paidById: 'u1',
        participantIds: ['u1'],
        splitAmountsById: null,
      );

      final deltas = SettlementEngine.expenseToDeltas(exp);
      expect(deltas, isEmpty);
    });
  });

  group('Phase 2: Invalid/missing splits and edge inputs', () {
    test('null splitAmountsById produces empty deltas', () {
      final exp = expense(
        id: 'e1',
        amount: 100,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: null,
      );
      expect(SettlementEngine.expenseToDeltas(exp), isEmpty);
    });

    test('empty splitAmountsById produces empty deltas', () {
      final exp = expense(
        id: 'e1',
        amount: 100,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {},
      );
      expect(SettlementEngine.expenseToDeltas(exp), isEmpty);
    });

    test('splits not summing to total skips expense', () {
      final exp = expense(
        id: 'e1',
        amount: 100,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 40, 'u2': 50},
      );
      expect(SettlementEngine.expenseToDeltas(exp), isEmpty);
    });

    test('splits within 0.01 of total are accepted', () {
      final exp = expense(
        id: 'e1',
        amount: 100,
        paidById: 'u1',
        participantIds: ['u1', 'u2'],
        splitAmountsById: {'u1': 50, 'u2': 49.99},
      );
      final deltas = SettlementEngine.expenseToDeltas(exp);
      expect(deltas, isNotEmpty);
      final sum = deltas.fold<int>(0, (s, d) => s + d.deltaMinor);
      expect(sum.abs(), lessThanOrEqualTo(1), reason: 'Rounding to minor units may yield ±1');
    });

    test('invalid expense skipped: other expenses still contribute to net', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 100,
          paidById: 'u1',
          splitAmountsById: null,
        ),
        expense(
          id: 'e2',
          amount: 200,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 100, 'u2': 100},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, members);
      expect(net['u1'], 10000);
      expect(net['u2'], -10000);
    });

    test('empty expense list yields zero balance for all members', () {
      final net = SettlementEngine.computeNetBalances([], members);
      expect(net['u1'], 0);
      expect(net['u2'], 0);
    });

    test('empty member list yields empty net map', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 100,
          paidById: 'u1',
          participantIds: ['u1', 'u2'],
          splitAmountsById: {'u1': 50, 'u2': 50},
        ),
      ];
      final net = SettlementEngine.computeNetBalances(expenses, []);
      expect(net, isEmpty);
    });
  });

  group('Phase 2: Replay determinism and balance invariants', () {
    test('replay of historical expenses is deterministic', () {
      final historicalExpenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
        expense(
          id: 'e2',
          amount: 200,
          paidById: 'u2',
          splitAmountsById: {'u1': 100, 'u2': 100},
        ),
      ];

      final deltas1 = SettlementEngine.expensesToDeltas(historicalExpenses);
      final deltas2 = SettlementEngine.expensesToDeltas(historicalExpenses);

      final net1 = SettlementEngine.computeNetBalancesFromDeltas(deltas1, 'INR');
      final net2 = SettlementEngine.computeNetBalancesFromDeltas(deltas2, 'INR');

      expect(net1, equals(net2), reason: 'Replay must be deterministic');
    });

    test('ledger deltas always sum to zero', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
        expense(
          id: 'e2',
          amount: 500,
          paidById: 'u2',
          splitAmountsById: {'u1': 200, 'u2': 300},
        ),
      ];

      final deltas = SettlementEngine.expensesToDeltas(expenses);
      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);

      expect(sum, 0, reason: 'Total delta sum must be exactly zero');
    });

    test('removing group members does not affect old balances', () {
      final expenses = [
        expense(
          id: 'e1',
          amount: 300,
          paidById: 'u1',
          splitAmountsById: {'u1': 150, 'u2': 150},
        ),
      ];

      final fullMembers = [memberRishi, memberRockey];
      final reducedMembers = [memberRishi];

      final netFull = SettlementEngine.computeNetBalances(expenses, fullMembers);
      final netReduced = SettlementEngine.computeNetBalances(expenses, reducedMembers);

      expect(netFull['u1'], 15000);
      expect(netReduced['u1'], isNotNull, reason: 'u1 balance must be present');
    });
  });

  group('Phase 2: Regression - Pre-Phase2 expense compatibility', () {
    test('well-formed expenses compute identical balances', () {
      final validExpenses = [
        expense(
          id: 'e1',
          amount: 1000,
          paidById: 'u1',
          splitAmountsById: {'u1': 400, 'u2': 600},
        ),
        expense(
          id: 'e2',
          amount: 500,
          paidById: 'u2',
          splitAmountsById: {'u1': 250, 'u2': 250},
        ),
      ];

      final net = SettlementEngine.computeNetBalances(validExpenses, members);
      final netDouble = SettlementEngine.computeNetBalancesAsDouble(validExpenses, members);

      expect(net['u1'], 35000);
      expect(net['u2'], -35000);
      expect(netDouble['u1'], 350.0);
      expect(netDouble['u2'], -350.0);
    });
  });

  group('SettlementEngine.computePaymentRoutes (debt minimization)', () {
    test('3 members: one creditor, two debtors - minimizes to 2 payments', () {
      final netBalances = {
        'alice': 10000,
        'bob': -6000,
        'carol': -4000,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

      expect(routes.length, 2);

      final totalToAlice = routes
          .where((r) => r.toMemberId == 'alice')
          .fold(0, (sum, r) => sum + r.amountMinor);
      expect(totalToAlice, 10000);

      final bobPayments = SettlementEngine.getPaymentsForMember('bob', routes);
      expect(bobPayments.length, 1);
      expect(bobPayments[0].amountMinor, 6000);
      expect(bobPayments[0].toMemberId, 'alice');

      final carolPayments = SettlementEngine.getPaymentsForMember('carol', routes);
      expect(carolPayments.length, 1);
      expect(carolPayments[0].amountMinor, 4000);
      expect(carolPayments[0].toMemberId, 'alice');
    });

    test('4 members: two creditors, two debtors - greedy matching', () {
      final netBalances = {
        'alice': 8000,
        'bob': 2000,
        'carol': -7000,
        'dave': -3000,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

      expect(routes.length, lessThanOrEqualTo(3));

      final totalCredits = 8000 + 2000;
      final totalDebts = 7000 + 3000;
      expect(totalCredits, totalDebts);

      final totalPaid = routes.fold(0, (sum, r) => sum + r.amountMinor);
      expect(totalPaid, 10000);

      for (final route in routes) {
        expect(route.amountMinor, greaterThan(0));
        expect(route.currencyCode, 'INR');
      }
    });

    test('5 members: complex scenario with chain reduction', () {
      final netBalances = {
        'u1': 15000,
        'u2': 5000,
        'u3': -8000,
        'u4': -7000,
        'u5': -5000,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

      expect(routes.length, lessThanOrEqualTo(4));

      final netAfterRoutes = <String, int>{};
      for (final entry in netBalances.entries) {
        netAfterRoutes[entry.key] = entry.value;
      }
      for (final route in routes) {
        netAfterRoutes[route.fromMemberId] = 
            (netAfterRoutes[route.fromMemberId] ?? 0) + route.amountMinor;
        netAfterRoutes[route.toMemberId] = 
            (netAfterRoutes[route.toMemberId] ?? 0) - route.amountMinor;
      }

      for (final balance in netAfterRoutes.values) {
        expect(balance, 0);
      }
    });

    test('all members balanced - no payments needed', () {
      final netBalances = {
        'alice': 0,
        'bob': 0,
        'carol': 0,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');
      expect(routes, isEmpty);
    });

    test('two members - single payment', () {
      final netBalances = {
        'alice': 5000,
        'bob': -5000,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

      expect(routes.length, 1);
      expect(routes[0].fromMemberId, 'bob');
      expect(routes[0].toMemberId, 'alice');
      expect(routes[0].amountMinor, 5000);
    });

    test('getPaymentsForMember returns only outgoing payments', () {
      final netBalances = {
        'alice': 10000,
        'bob': -6000,
        'carol': -4000,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

      final alicePayments = SettlementEngine.getPaymentsForMember('alice', routes);
      expect(alicePayments, isEmpty);

      final bobPayments = SettlementEngine.getPaymentsForMember('bob', routes);
      expect(bobPayments.length, 1);
      expect(bobPayments.every((r) => r.fromMemberId == 'bob'), true);
    });

    test('getPaymentsToMember returns only incoming payments', () {
      final netBalances = {
        'alice': 10000,
        'bob': -6000,
        'carol': -4000,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

      final aliceReceives = SettlementEngine.getPaymentsToMember('alice', routes);
      expect(aliceReceives.length, 2);
      expect(aliceReceives.every((r) => r.toMemberId == 'alice'), true);

      final bobReceives = SettlementEngine.getPaymentsToMember('bob', routes);
      expect(bobReceives, isEmpty);
    });

    test('PaymentRoute equality and toString', () {
      final route1 = PaymentRoute(
        fromMemberId: 'bob',
        toMemberId: 'alice',
        amount: MoneyMinor(5000, 'INR'),
      );
      final route2 = PaymentRoute(
        fromMemberId: 'bob',
        toMemberId: 'alice',
        amount: MoneyMinor(5000, 'INR'),
      );
      final route3 = PaymentRoute(
        fromMemberId: 'carol',
        toMemberId: 'alice',
        amount: MoneyMinor(5000, 'INR'),
      );

      expect(route1, equals(route2));
      expect(route1, isNot(equals(route3)));
      expect(route1.hashCode, route2.hashCode);
      expect(route1.toString(), contains('bob'));
      expect(route1.toString(), contains('alice'));
      expect(route1.toString(), contains('5000'));
    });

    test('6 members: realistic group expense scenario', () {
      final netBalances = {
        'anna': 25000,
        'ben': 15000,
        'carl': -12000,
        'diana': -10000,
        'eve': -8000,
        'frank': -10000,
      };

      final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

      expect(routes.length, lessThanOrEqualTo(5));

      final Map<String, int> verification = Map.from(netBalances);
      for (final route in routes) {
        verification[route.fromMemberId] = 
            verification[route.fromMemberId]! + route.amountMinor;
        verification[route.toMemberId] = 
            verification[route.toMemberId]! - route.amountMinor;
      }

      for (final entry in verification.entries) {
        expect(entry.value, 0, reason: '${entry.key} should be settled');
      }

      final carlPayments = SettlementEngine.getPaymentsForMember('carl', routes);
      expect(carlPayments.isNotEmpty, true);
      final carlTotal = carlPayments.fold(0, (sum, r) => sum + r.amountMinor);
      expect(carlTotal, 12000);
    });
  });
}
