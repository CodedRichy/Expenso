import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/models/money_minor.dart';
import 'package:expenso/utils/ledger_delta.dart';
import 'package:expenso/utils/expense_revision.dart';

void main() {
  group('negateDeltas', () {
    test('inverts all delta amounts', () {
      final original = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime(2025, 1, 1),
        ),
        LedgerDelta(
          memberId: 'u2',
          delta: MoneyMinor(-15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime(2025, 1, 1),
        ),
      ];

      final negated = negateDeltas(original, 'compensation_1', DateTime(2025, 1, 2));

      expect(negated.length, 2);
      expect(negated[0].deltaMinor, -15000);
      expect(negated[1].deltaMinor, 15000);
    });

    test('preserves member IDs', () {
      final original = [
        LedgerDelta(
          memberId: 'alice',
          delta: MoneyMinor(100, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
      ];

      final negated = negateDeltas(original, 'comp', DateTime.now());

      expect(negated[0].memberId, 'alice');
    });

    test('preserves currency', () {
      final original = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(1000, 'JPY'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
      ];

      final negated = negateDeltas(original, 'comp', DateTime.now());

      expect(negated[0].currencyCode, 'JPY');
    });

    test('uses new expense ID', () {
      final original = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(100, 'INR'),
          expenseId: 'original_expense',
          timestamp: DateTime.now(),
        ),
      ];

      final negated = negateDeltas(original, 'new_compensation_id', DateTime.now());

      expect(negated[0].expenseId, 'new_compensation_id');
    });

    test('uses new timestamp', () {
      final originalTime = DateTime(2025, 1, 1);
      final newTime = DateTime(2025, 6, 15);
      
      final original = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(100, 'INR'),
          expenseId: 'e1',
          timestamp: originalTime,
        ),
      ];

      final negated = negateDeltas(original, 'comp', newTime);

      expect(negated[0].timestamp, newTime);
    });

    test('original plus negation sums to zero', () {
      final original = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(30000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
        LedgerDelta(
          memberId: 'u2',
          delta: MoneyMinor(-15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
        LedgerDelta(
          memberId: 'u3',
          delta: MoneyMinor(-15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime.now(),
        ),
      ];

      final negated = negateDeltas(original, 'comp', DateTime.now());
      final all = [...original, ...negated];
      
      final net = <String, int>{};
      for (final d in all) {
        net[d.memberId] = (net[d.memberId] ?? 0) + d.deltaMinor;
      }

      expect(net['u1'], 0);
      expect(net['u2'], 0);
      expect(net['u3'], 0);
    });
  });

  group('generateEditDeltas', () {
    test('editing an expense preserves total balance', () {
      final originalDeltas = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(30000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime(2025, 1, 1),
        ),
        LedgerDelta(
          memberId: 'u2',
          delta: MoneyMinor(-15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime(2025, 1, 1),
        ),
        LedgerDelta(
          memberId: 'u3',
          delta: MoneyMinor(-15000, 'INR'),
          expenseId: 'e1',
          timestamp: DateTime(2025, 1, 1),
        ),
      ];

      final newDeltas = [
        LedgerDelta(
          memberId: 'u1',
          delta: MoneyMinor(20000, 'INR'),
          expenseId: 'e2',
          timestamp: DateTime(2025, 1, 2),
        ),
        LedgerDelta(
          memberId: 'u2',
          delta: MoneyMinor(-10000, 'INR'),
          expenseId: 'e2',
          timestamp: DateTime(2025, 1, 2),
        ),
        LedgerDelta(
          memberId: 'u3',
          delta: MoneyMinor(-10000, 'INR'),
          expenseId: 'e2',
          timestamp: DateTime(2025, 1, 2),
        ),
      ];

      final editDeltas = generateEditDeltas(
        originalDeltas: originalDeltas,
        newDeltas: newDeltas,
        compensationExpenseId: 'e2',
        timestamp: DateTime(2025, 1, 2),
      );

      final allDeltas = [...originalDeltas, ...editDeltas];
      final net = computeNetBalancesFromAllDeltas(allDeltas, 'INR');

      expect(net['u1'], 20000);
      expect(net['u2'], -10000);
      expect(net['u3'], -10000);
      
      final totalSum = net.values.fold(0, (a, b) => a + b);
      expect(totalSum, 0, reason: 'Total balance must remain zero');
    });

    test('multiple edits chain correctly', () {
      final e1Deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(10000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-10000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
      ];

      final e2Deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(20000, 'INR'), expenseId: 'e2', timestamp: DateTime(2025, 1, 2)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-20000, 'INR'), expenseId: 'e2', timestamp: DateTime(2025, 1, 2)),
      ];

      final e3Deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(30000, 'INR'), expenseId: 'e3', timestamp: DateTime(2025, 1, 3)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-30000, 'INR'), expenseId: 'e3', timestamp: DateTime(2025, 1, 3)),
      ];

      final edit1 = generateEditDeltas(
        originalDeltas: e1Deltas,
        newDeltas: e2Deltas,
        compensationExpenseId: 'e2',
        timestamp: DateTime(2025, 1, 2),
      );

      final edit2 = generateEditDeltas(
        originalDeltas: e2Deltas,
        newDeltas: e3Deltas,
        compensationExpenseId: 'e3',
        timestamp: DateTime(2025, 1, 3),
      );

      final allDeltas = [...e1Deltas, ...edit1, ...edit2];
      final net = computeNetBalancesFromAllDeltas(allDeltas, 'INR');

      expect(net['u1'], 30000, reason: 'Only final edit should affect balance');
      expect(net['u2'], -30000);
    });
  });

  group('generateDeleteDeltas', () {
    test('deleting an expense fully negates its effect', () {
      final originalDeltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(50000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-25000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
        LedgerDelta(memberId: 'u3', delta: MoneyMinor(-25000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
      ];

      final deleteDeltas = generateDeleteDeltas(
        originalDeltas: originalDeltas,
        compensationExpenseId: 'delete_e1',
        timestamp: DateTime(2025, 1, 2),
      );

      final allDeltas = [...originalDeltas, ...deleteDeltas];
      final net = computeNetBalancesFromAllDeltas(allDeltas, 'INR');

      expect(net['u1'], 0);
      expect(net['u2'], 0);
      expect(net['u3'], 0);
    });

    test('deletion does not affect other expenses', () {
      final e1Deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(10000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-10000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
      ];

      final e2Deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(20000, 'INR'), expenseId: 'e2', timestamp: DateTime(2025, 1, 2)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-20000, 'INR'), expenseId: 'e2', timestamp: DateTime(2025, 1, 2)),
      ];

      final deleteE1 = generateDeleteDeltas(
        originalDeltas: e1Deltas,
        compensationExpenseId: 'delete_e1',
        timestamp: DateTime(2025, 1, 3),
      );

      final allDeltas = [...e1Deltas, ...e2Deltas, ...deleteE1];
      final net = computeNetBalancesFromAllDeltas(allDeltas, 'INR');

      expect(net['u1'], 20000, reason: 'e2 should remain unaffected');
      expect(net['u2'], -20000);
    });
  });

  group('Historical replay determinism', () {
    test('replay of historical expenses is deterministic', () {
      final expenses = [
        (id: 'e1', amount: 30000, payerId: 'u1', splits: {'u1': 15000, 'u2': 15000}),
        (id: 'e2', amount: 20000, payerId: 'u2', splits: {'u1': 10000, 'u2': 10000}),
      ];

      List<LedgerDelta> generateDeltas() {
        final allDeltas = <LedgerDelta>[];
        for (final e in expenses) {
          allDeltas.addAll(expenseToLedgerDeltas(
            expenseId: e.id,
            amountMinor: e.amount,
            payerId: e.payerId,
            splitAmountsByIdMinor: e.splits,
            currencyCode: 'INR',
            timestamp: DateTime(2025, 1, 1),
          ));
        }
        return allDeltas;
      }

      final run1 = generateDeltas();
      final run2 = generateDeltas();

      final net1 = computeNetBalancesFromAllDeltas(run1, 'INR');
      final net2 = computeNetBalancesFromAllDeltas(run2, 'INR');

      expect(net1, equals(net2), reason: 'Replay must be deterministic');
    });

    test('edit history can be replayed to reconstruct any point in time', () {
      final e1Deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(10000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-10000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
      ];

      final edit1Deltas = generateEditDeltas(
        originalDeltas: e1Deltas,
        newDeltas: [
          LedgerDelta(memberId: 'u1', delta: MoneyMinor(20000, 'INR'), expenseId: 'e2', timestamp: DateTime(2025, 1, 2)),
          LedgerDelta(memberId: 'u2', delta: MoneyMinor(-20000, 'INR'), expenseId: 'e2', timestamp: DateTime(2025, 1, 2)),
        ],
        compensationExpenseId: 'e2',
        timestamp: DateTime(2025, 1, 2),
      );

      final beforeEdit = computeNetBalancesFromAllDeltas(e1Deltas, 'INR');
      expect(beforeEdit['u1'], 10000);

      final afterEdit = computeNetBalancesFromAllDeltas([...e1Deltas, ...edit1Deltas], 'INR');
      expect(afterEdit['u1'], 20000);
    });
  });

  group('Ledger invariants', () {
    test('all deltas sum to zero after any operation', () {
      final original = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(30000, 'INR'), expenseId: 'e1', timestamp: DateTime.now()),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-15000, 'INR'), expenseId: 'e1', timestamp: DateTime.now()),
        LedgerDelta(memberId: 'u3', delta: MoneyMinor(-15000, 'INR'), expenseId: 'e1', timestamp: DateTime.now()),
      ];

      final sumOriginal = original.fold(0, (a, d) => a + d.deltaMinor);
      expect(sumOriginal, 0);

      final negated = negateDeltas(original, 'comp', DateTime.now());
      final sumNegated = negated.fold(0, (a, d) => a + d.deltaMinor);
      expect(sumNegated, 0);

      final editDeltas = generateEditDeltas(
        originalDeltas: original,
        newDeltas: [
          LedgerDelta(memberId: 'u1', delta: MoneyMinor(40000, 'INR'), expenseId: 'e2', timestamp: DateTime.now()),
          LedgerDelta(memberId: 'u2', delta: MoneyMinor(-40000, 'INR'), expenseId: 'e2', timestamp: DateTime.now()),
        ],
        compensationExpenseId: 'e2',
        timestamp: DateTime.now(),
      );
      final sumEdit = editDeltas.fold(0, (a, d) => a + d.deltaMinor);
      expect(sumEdit, 0, reason: 'Edit operation deltas must sum to zero');
    });

    test('net balances across all members sum to zero', () {
      final deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(100000, 'INR'), expenseId: 'e1', timestamp: DateTime.now()),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-30000, 'INR'), expenseId: 'e1', timestamp: DateTime.now()),
        LedgerDelta(memberId: 'u3', delta: MoneyMinor(-40000, 'INR'), expenseId: 'e1', timestamp: DateTime.now()),
        LedgerDelta(memberId: 'u4', delta: MoneyMinor(-30000, 'INR'), expenseId: 'e1', timestamp: DateTime.now()),
      ];

      final net = computeNetBalancesFromAllDeltas(deltas, 'INR');
      final totalSum = net.values.fold(0, (a, b) => a + b);
      
      expect(totalSum, 0, reason: 'Total balances must always sum to zero');
    });
  });

  group('Audit trail preservation', () {
    test('original deltas remain unchanged after negation', () {
      final original = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(10000, 'INR'), expenseId: 'e1', timestamp: DateTime(2025, 1, 1)),
      ];

      final originalDeltaMinor = original[0].deltaMinor;
      final originalExpenseId = original[0].expenseId;

      negateDeltas(original, 'comp', DateTime(2025, 1, 2));

      expect(original[0].deltaMinor, originalDeltaMinor, reason: 'Original must not be mutated');
      expect(original[0].expenseId, originalExpenseId);
    });

    test('expense IDs are preserved for audit', () {
      final e1Deltas = [
        LedgerDelta(memberId: 'u1', delta: MoneyMinor(10000, 'INR'), expenseId: 'original_e1', timestamp: DateTime(2025, 1, 1)),
        LedgerDelta(memberId: 'u2', delta: MoneyMinor(-10000, 'INR'), expenseId: 'original_e1', timestamp: DateTime(2025, 1, 1)),
      ];

      final edit = generateEditDeltas(
        originalDeltas: e1Deltas,
        newDeltas: [
          LedgerDelta(memberId: 'u1', delta: MoneyMinor(20000, 'INR'), expenseId: 'edited_e1', timestamp: DateTime(2025, 1, 2)),
          LedgerDelta(memberId: 'u2', delta: MoneyMinor(-20000, 'INR'), expenseId: 'edited_e1', timestamp: DateTime(2025, 1, 2)),
        ],
        compensationExpenseId: 'edited_e1',
        timestamp: DateTime(2025, 1, 2),
      );

      final allDeltas = [...e1Deltas, ...edit];
      final expenseIds = allDeltas.map((d) => d.expenseId).toSet();

      expect(expenseIds, contains('original_e1'));
      expect(expenseIds, contains('edited_e1'));
    });
  });

  group('ExpenseRevision model', () {
    test('original expense has null replacesExpenseId', () {
      const revision = ExpenseRevision(expenseId: 'e1');
      
      expect(revision.isOriginal, true);
      expect(revision.isRevision, false);
      expect(revision.replacesExpenseId, isNull);
    });

    test('edited expense has non-null replacesExpenseId', () {
      const revision = ExpenseRevision(
        expenseId: 'e2',
        replacesExpenseId: 'e1',
      );
      
      expect(revision.isOriginal, false);
      expect(revision.isRevision, true);
      expect(revision.replacesExpenseId, 'e1');
    });
  });
}
