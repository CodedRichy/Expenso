import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/models/models.dart';
import 'package:expenso/models/normalized_expense.dart';
import 'package:expenso/services/groq_expense_parser_service.dart';
import 'package:expenso/utils/expense_normalization.dart';
import 'package:expenso/utils/ledger_delta.dart';

void main() {
  final memberA = Member(id: 'u1', phone: '+91 12345 67890', name: 'Alice');
  final memberB = Member(id: 'u2', phone: '+91 98765 43210', name: 'Bob');
  final memberC = Member(id: 'u3', phone: '+91 55555 55555', name: 'Charlie');
  final members = [memberA, memberB, memberC];

  group('NormalizedExpense invariants', () {
    test('valid expense passes all invariants', () {
      final expense = NormalizedExpense(
        amount: 300,
        description: 'Dinner',
        payerContributionsByMemberId: {'u1': 300},
        participantSharesByMemberId: {'u1': 100, 'u2': 100, 'u3': 100},
      );

      expect(expense.amount, 300);
      expect(expense.primaryPayerId, 'u1');
      expect(expense.participantIds, containsAll(['u1', 'u2', 'u3']));
    });

    test('payer contributions must equal amount', () {
      expect(
        () => NormalizedExpense(
          amount: 300,
          description: 'Dinner',
          payerContributionsByMemberId: {'u1': 200},
          participantSharesByMemberId: {'u1': 150, 'u2': 150},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('participant shares must equal amount', () {
      expect(
        () => NormalizedExpense(
          amount: 300,
          description: 'Dinner',
          payerContributionsByMemberId: {'u1': 300},
          participantSharesByMemberId: {'u1': 100, 'u2': 100},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('pending member IDs are rejected', () {
      expect(
        () => NormalizedExpense(
          amount: 300,
          description: 'Dinner',
          payerContributionsByMemberId: {'p_pending': 300},
          participantSharesByMemberId: {'u1': 150, 'u2': 150},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('empty description is rejected', () {
      expect(
        () => NormalizedExpense(
          amount: 300,
          description: '',
          payerContributionsByMemberId: {'u1': 300},
          participantSharesByMemberId: {'u1': 150, 'u2': 150},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('zero or negative amount is rejected', () {
      expect(
        () => NormalizedExpense(
          amount: 0,
          description: 'Test',
          payerContributionsByMemberId: {'u1': 0},
          participantSharesByMemberId: {'u1': 0},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });
  });

  group('LedgerDelta computation', () {
    test('sum of deltas is always zero', () {
      final expense = NormalizedExpense(
        amount: 300,
        description: 'Dinner',
        payerContributionsByMemberId: {'u1': 300},
        participantSharesByMemberId: {'u1': 100, 'u2': 100, 'u3': 100},
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final sum = deltas.fold(0.0, (acc, d) => acc + d.delta);
      
      expect(sum.abs(), lessThan(0.01));
    });

    test('payer gets positive delta, participants get negative', () {
      final expense = NormalizedExpense(
        amount: 300,
        description: 'Dinner',
        payerContributionsByMemberId: {'u1': 300},
        participantSharesByMemberId: {'u1': 100, 'u2': 100, 'u3': 100},
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final deltaMap = {for (final d in deltas) d.memberId: d.delta};

      expect(deltaMap['u1'], closeTo(200, 0.01));
      expect(deltaMap['u2'], closeTo(-100, 0.01));
      expect(deltaMap['u3'], closeTo(-100, 0.01));
    });

    test('payer who is also participant has net delta', () {
      final expense = NormalizedExpense(
        amount: 200,
        description: 'Lunch',
        payerContributionsByMemberId: {'u1': 200},
        participantSharesByMemberId: {'u1': 100, 'u2': 100},
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final deltaMap = {for (final d in deltas) d.memberId: d.delta};

      expect(deltaMap['u1'], closeTo(100, 0.01));
      expect(deltaMap['u2'], closeTo(-100, 0.01));
    });

    test('multiple payers distribute credit correctly', () {
      final expense = NormalizedExpense(
        amount: 300,
        description: 'Group dinner',
        payerContributionsByMemberId: {'u1': 200, 'u2': 100},
        participantSharesByMemberId: {'u1': 100, 'u2': 100, 'u3': 100},
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final deltaMap = {for (final d in deltas) d.memberId: d.delta};

      expect(deltaMap['u1'], closeTo(100, 0.01));
      expect(deltaMap.containsKey('u2'), false);
      expect(deltaMap['u3'], closeTo(-100, 0.01));
    });
  });

  group('normalizeExpense', () {
    test('even split among all members when participants is empty', () {
      final parsed = ParsedExpenseResult(
        amount: 300,
        description: 'Dinner',
        category: 'Food',
        splitType: 'even',
        participantNames: [],
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.amount, 300);
      expect(expense.participantSharesByMemberId.length, 3);
      expect(expense.participantSharesByMemberId['u1'], closeTo(100, 0.01));
      expect(expense.participantSharesByMemberId['u2'], closeTo(100, 0.01));
      expect(expense.participantSharesByMemberId['u3'], closeTo(100, 0.01));
    });

    test('even split with named participants', () {
      final parsed = ParsedExpenseResult(
        amount: 200,
        description: 'Coffee',
        category: 'Food',
        splitType: 'even',
        participantNames: ['Bob'],
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.participantSharesByMemberId.length, 2);
      expect(expense.participantSharesByMemberId['u1'], closeTo(100, 0.01));
      expect(expense.participantSharesByMemberId['u2'], closeTo(100, 0.01));
    });

    test('exact split with specific amounts', () {
      final parsed = ParsedExpenseResult(
        amount: 500,
        description: 'Dinner',
        category: 'Food',
        splitType: 'exact',
        exactAmountsByName: {'Alice': 200, 'Bob': 300},
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.participantSharesByMemberId['u1'], closeTo(200, 0.01));
      expect(expense.participantSharesByMemberId['u2'], closeTo(300, 0.01));
    });

    test('exact split fills remainder to current user', () {
      final parsed = ParsedExpenseResult(
        amount: 500,
        description: 'Dinner',
        category: 'Food',
        splitType: 'exact',
        exactAmountsByName: {'Bob': 300},
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.participantSharesByMemberId['u1'], closeTo(200, 0.01));
      expect(expense.participantSharesByMemberId['u2'], closeTo(300, 0.01));
    });

    test('percentage split converts to amounts', () {
      final parsed = ParsedExpenseResult(
        amount: 1000,
        description: 'Rent',
        category: '',
        splitType: 'percentage',
        percentageByName: {'me': 60, 'Bob': 40},
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.participantSharesByMemberId['u1'], closeTo(600, 0.01));
      expect(expense.participantSharesByMemberId['u2'], closeTo(400, 0.01));
    });

    test('shares split calculates proportionally', () {
      final parsed = ParsedExpenseResult(
        amount: 1500,
        description: 'Airbnb',
        category: '',
        splitType: 'shares',
        sharesByName: {'Alice': 2, 'Bob': 3},
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.participantSharesByMemberId['u1'], closeTo(600, 0.01));
      expect(expense.participantSharesByMemberId['u2'], closeTo(900, 0.01));
    });

    test('unresolved name returns NeedsConfirmation', () {
      final parsed = ParsedExpenseResult(
        amount: 200,
        description: 'Dinner',
        category: 'Food',
        splitType: 'even',
        participantNames: ['Unknown Person'],
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationNeedsConfirmation>());
      final needsConfirm = result as NormalizationNeedsConfirmation;
      expect(needsConfirm.unresolvedNames, contains('Unknown Person'));
    });

    test('payer name resolution works', () {
      final parsed = ParsedExpenseResult(
        amount: 300,
        description: 'Dinner',
        category: 'Food',
        splitType: 'even',
        participantNames: [],
        payerName: 'Bob',
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      expect(success.expense.primaryPayerId, 'u2');
    });

    test('invalid amount returns error', () {
      final parsed = ParsedExpenseResult(
        amount: -100,
        description: 'Invalid',
        category: '',
        splitType: 'even',
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationError>());
    });

    test('percentage not summing to 100 returns needs confirmation', () {
      final parsed = ParsedExpenseResult(
        amount: 1000,
        description: 'Rent',
        category: '',
        splitType: 'percentage',
        percentageByName: {'Alice': 60, 'Bob': 30},
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
      );

      expect(result, isA<NormalizationNeedsConfirmation>());
      final needsConfirm = result as NormalizationNeedsConfirmation;
      expect(needsConfirm.validationWarning, isNotNull);
      expect(needsConfirm.validationWarning, contains('100%'));
    });
  });

  group('name collision handling', () {
    test('exact name match wins over partial match', () {
      final memberAl = Member(id: 'u_al', phone: '+91 11111 11111', name: 'Al');
      final memberAlex = Member(id: 'u_alex', phone: '+91 22222 22222', name: 'Alex');
      final testMembers = [memberAl, memberAlex];

      final parsed = ParsedExpenseResult(
        amount: 200,
        description: 'Dinner',
        category: 'Food',
        splitType: 'even',
        participantNames: ['Al'],
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: testMembers,
        currentUserId: 'u_alex',
        currentUserName: 'Alex',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      expect(success.expense.participantSharesByMemberId.keys, contains('u_al'));
    });
  });

  group('buildNormalizedExpenseFromSlots', () {
    test('builds expense from resolved slots', () {
      final slots = [
        ParticipantSlot(name: 'Alice', amount: 100, memberId: 'u1'),
        ParticipantSlot(name: 'Bob', amount: 200, memberId: 'u2'),
      ];

      final expense = buildNormalizedExpenseFromSlots(
        amount: 300,
        description: 'Dinner',
        category: 'Food',
        date: 'Today',
        payerId: 'u1',
        slots: slots,
        splitType: 'Exact',
        allMemberIds: ['u1', 'u2', 'u3'],
      );

      expect(expense.amount, 300);
      expect(expense.participantSharesByMemberId['u1'], 100);
      expect(expense.participantSharesByMemberId['u2'], 200);
    });

    test('exclude split uses all members minus excluded', () {
      final slots = [
        ParticipantSlot(name: 'Charlie', amount: 0, memberId: 'u3'),
      ];

      final expense = buildNormalizedExpenseFromSlots(
        amount: 300,
        description: 'Dinner',
        category: 'Food',
        date: 'Today',
        payerId: 'u1',
        slots: slots,
        splitType: 'Exclude',
        allMemberIds: ['u1', 'u2', 'u3'],
        excludedIds: ['u3'],
      );

      expect(expense.participantSharesByMemberId.keys, containsAll(['u1', 'u2']));
      expect(expense.participantSharesByMemberId.containsKey('u3'), false);
      expect(expense.participantSharesByMemberId['u1'], closeTo(150, 0.01));
      expect(expense.participantSharesByMemberId['u2'], closeTo(150, 0.01));
    });
  });

  group('delta sum invariant across all split types', () {
    final testCases = [
      (
        name: 'even split',
        parsed: ParsedExpenseResult(
          amount: 300,
          description: 'Test',
          category: '',
          splitType: 'even',
          participantNames: [],
        ),
      ),
      (
        name: 'exact split',
        parsed: ParsedExpenseResult(
          amount: 300,
          description: 'Test',
          category: '',
          splitType: 'exact',
          exactAmountsByName: {'Alice': 100, 'Bob': 200},
        ),
      ),
      (
        name: 'percentage split',
        parsed: ParsedExpenseResult(
          amount: 300,
          description: 'Test',
          category: '',
          splitType: 'percentage',
          percentageByName: {'Alice': 50, 'Bob': 50},
        ),
      ),
      (
        name: 'shares split',
        parsed: ParsedExpenseResult(
          amount: 300,
          description: 'Test',
          category: '',
          splitType: 'shares',
          sharesByName: {'Alice': 1, 'Bob': 2},
        ),
      ),
    ];

    for (final tc in testCases) {
      test('${tc.name}: sum of deltas is zero', () {
        final result = normalizeExpense(
          parsed: tc.parsed,
          members: members,
          currentUserId: 'u1',
          currentUserName: 'Alice',
        );

        expect(result, isA<NormalizationSuccess>());
        final expense = (result as NormalizationSuccess).expense;
        final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
        final sum = deltas.fold(0.0, (acc, d) => acc + d.delta);

        expect(sum.abs(), lessThan(0.01), reason: 'Delta sum must be zero for ${tc.name}');
      });
    }
  });
}
