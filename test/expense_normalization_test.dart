import 'package:flutter_test/flutter_test.dart';
import 'package:expenso/models/models.dart';
import 'package:expenso/models/currency.dart';
import 'package:expenso/models/money_minor.dart';
import 'package:expenso/models/normalized_expense.dart';
import 'package:expenso/services/groq_expense_parser_service.dart';
import 'package:expenso/utils/expense_normalization.dart';
import 'package:expenso/utils/ledger_delta.dart';

void main() {
  final memberA = Member(id: 'u1', phone: '+91 12345 67890', name: 'Alice');
  final memberB = Member(id: 'u2', phone: '+91 98765 43210', name: 'Bob');
  final memberC = Member(id: 'u3', phone: '+91 55555 55555', name: 'Charlie');
  final members = [memberA, memberB, memberC];

  group('Currency and MoneyMinor', () {
    test('CurrencyRegistry contains standard currencies', () {
      expect(CurrencyRegistry.lookup('INR')?.minorUnitScale, 2);
      expect(CurrencyRegistry.lookup('USD')?.minorUnitScale, 2);
      expect(CurrencyRegistry.lookup('JPY')?.minorUnitScale, 0);
      expect(CurrencyRegistry.lookup('KWD')?.minorUnitScale, 3);
    });

    test('Currency multiplier is correct', () {
      expect(CurrencyRegistry.inr.multiplier, 100);
      expect(CurrencyRegistry.jpy.multiplier, 1);
      expect(CurrencyRegistry.kwd.multiplier, 1000);
    });

    test('MoneyConversion parseToMinor works for INR (2 decimals)', () {
      final money = MoneyConversion.parseToMinor(100.50, 'INR');
      expect(money.amountMinor, 10050);
      expect(money.currencyCode, 'INR');
    });

    test('MoneyConversion parseToMinor works for JPY (0 decimals)', () {
      final money = MoneyConversion.parseToMinor(1000, 'JPY');
      expect(money.amountMinor, 1000);
      expect(money.currencyCode, 'JPY');
    });

    test('MoneyConversion parseToMinor works for KWD (3 decimals)', () {
      final money = MoneyConversion.parseToMinor(1.500, 'KWD');
      expect(money.amountMinor, 1500);
      expect(money.currencyCode, 'KWD');
    });

    test('MoneyConversion toDisplay reverses parseToMinor', () {
      expect(MoneyConversion.toDisplay(MoneyMinor(10050, 'INR')), 100.50);
      expect(MoneyConversion.toDisplay(MoneyMinor(1000, 'JPY')), 1000.0);
      expect(MoneyConversion.toDisplay(MoneyMinor(1500, 'KWD')), 1.500);
    });

    test('MoneyMinor arithmetic works within same currency', () {
      final a = MoneyMinor(100, 'INR');
      final b = MoneyMinor(50, 'INR');
      expect((a + b).amountMinor, 150);
      expect((a - b).amountMinor, 50);
      expect((-a).amountMinor, -100);
    });

    test('MoneyMinor rejects arithmetic across currencies', () {
      final inr = MoneyMinor(100, 'INR');
      final usd = MoneyMinor(100, 'USD');
      expect(() => inr + usd, throwsArgumentError);
    });
  });

  group('MoneySplitter', () {
    test('splitEvenly divides correctly with no remainder', () {
      final result = MoneySplitter.splitEvenly(
        totalMinor: 300,
        participantIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );
      expect(result['u1'], 100);
      expect(result['u2'], 100);
      expect(result['u3'], 100);
    });

    test('splitEvenly assigns remainder to first participant', () {
      final result = MoneySplitter.splitEvenly(
        totalMinor: 100,
        participantIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );
      expect(result['u1'], 34);
      expect(result['u2'], 33);
      expect(result['u3'], 33);
    });

    test('splitByWeights distributes proportionally', () {
      final result = MoneySplitter.splitByWeights(
        totalMinor: 1000,
        weights: {'u1': 1, 'u2': 2, 'u3': 2},
        currencyCode: 'INR',
      );
      expect(result['u1'], 200);
      expect(result['u2']! + result['u3']!, 800);
    });
  });

  group('NormalizedExpense invariants (integer-based)', () {
    test('valid expense passes all invariants', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: 'Dinner',
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(10000, 'INR'),
          'u3': MoneyMinor(10000, 'INR'),
        },
      );

      expect(expense.amountMinor, 30000);
      expect(expense.primaryPayerId, 'u1');
      expect(expense.participantIds, containsAll(['u1', 'u2', 'u3']));
      expect(expense.currencyCode, 'INR');
    });

    test('payer contributions must equal total exactly', () {
      expect(
        () => NormalizedExpense(
          total: MoneyMinor(30000, 'INR'),
          description: 'Dinner',
          payerContributionsByMemberId: {'u1': MoneyMinor(20000, 'INR')},
          participantSharesByMemberId: {'u1': MoneyMinor(15000, 'INR'), 'u2': MoneyMinor(15000, 'INR')},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('participant shares must equal total exactly', () {
      expect(
        () => NormalizedExpense(
          total: MoneyMinor(30000, 'INR'),
          description: 'Dinner',
          payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
          participantSharesByMemberId: {'u1': MoneyMinor(10000, 'INR'), 'u2': MoneyMinor(10000, 'INR')},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('mixed currencies are rejected', () {
      expect(
        () => NormalizedExpense(
          total: MoneyMinor(30000, 'INR'),
          description: 'Dinner',
          payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'USD')},
          participantSharesByMemberId: {'u1': MoneyMinor(15000, 'INR'), 'u2': MoneyMinor(15000, 'INR')},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('pending member IDs are rejected', () {
      expect(
        () => NormalizedExpense(
          total: MoneyMinor(30000, 'INR'),
          description: 'Dinner',
          payerContributionsByMemberId: {'p_pending': MoneyMinor(30000, 'INR')},
          participantSharesByMemberId: {'u1': MoneyMinor(15000, 'INR'), 'u2': MoneyMinor(15000, 'INR')},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });

    test('empty description is allowed (UI concern, not accounting)', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: '',
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {'u1': MoneyMinor(15000, 'INR'), 'u2': MoneyMinor(15000, 'INR')},
      );
      expect(expense.description, '');
    });

    test('zero or negative amount is rejected', () {
      expect(
        () => NormalizedExpense(
          total: MoneyMinor(0, 'INR'),
          description: 'Test',
          payerContributionsByMemberId: {'u1': MoneyMinor(0, 'INR')},
          participantSharesByMemberId: {'u1': MoneyMinor(0, 'INR')},
        ),
        throwsA(isA<NormalizedExpenseError>()),
      );
    });
  });

  group('LedgerDelta computation (integer-based)', () {
    test('sum of deltas is always exactly zero', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: 'Dinner',
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(10000, 'INR'),
          'u3': MoneyMinor(10000, 'INR'),
        },
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      
      expect(sum, 0);
    });

    test('payer gets positive delta, participants get negative', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: 'Dinner',
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(10000, 'INR'),
          'u3': MoneyMinor(10000, 'INR'),
        },
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final deltaMap = {for (final d in deltas) d.memberId: d.deltaMinor};

      expect(deltaMap['u1'], 20000);
      expect(deltaMap['u2'], -10000);
      expect(deltaMap['u3'], -10000);
    });

    test('payer who is also participant has net delta', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(20000, 'INR'),
        description: 'Lunch',
        payerContributionsByMemberId: {'u1': MoneyMinor(20000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(10000, 'INR'),
        },
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final deltaMap = {for (final d in deltas) d.memberId: d.deltaMinor};

      expect(deltaMap['u1'], 10000);
      expect(deltaMap['u2'], -10000);
    });

    test('multiple payers distribute credit correctly', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: 'Group dinner',
        payerContributionsByMemberId: {
          'u1': MoneyMinor(20000, 'INR'),
          'u2': MoneyMinor(10000, 'INR'),
        },
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(10000, 'INR'),
          'u3': MoneyMinor(10000, 'INR'),
        },
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final deltaMap = {for (final d in deltas) d.memberId: d.deltaMinor};

      expect(deltaMap['u1'], 10000);
      expect(deltaMap.containsKey('u2'), false);
      expect(deltaMap['u3'], -10000);
    });
  });

  group('Multi-currency support', () {
    test('INR: 100.50 rupees = 10050 paise', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(10050, 'INR'),
        payerContributionsByMemberId: {'u1': MoneyMinor(10050, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(5025, 'INR'),
          'u2': MoneyMinor(5025, 'INR'),
        },
      );
      expect(expense.amountMinor, 10050);
      expect(MoneyConversion.toDisplay(expense.total), 100.50);
    });

    test('JPY: 1000 yen = 1000 (no minor units)', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(1000, 'JPY'),
        payerContributionsByMemberId: {'u1': MoneyMinor(1000, 'JPY')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(500, 'JPY'),
          'u2': MoneyMinor(500, 'JPY'),
        },
      );
      expect(expense.amountMinor, 1000);
      expect(MoneyConversion.toDisplay(expense.total), 1000.0);
    });

    test('KWD: 1.500 dinar = 1500 fils', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(1500, 'KWD'),
        payerContributionsByMemberId: {'u1': MoneyMinor(1500, 'KWD')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(750, 'KWD'),
          'u2': MoneyMinor(750, 'KWD'),
        },
      );
      expect(expense.amountMinor, 1500);
      expect(MoneyConversion.toDisplay(expense.total), 1.500);
    });

    test('deltas sum to zero across all currency types', () {
      for (final currency in ['INR', 'USD', 'JPY', 'KWD']) {
        final expense = NormalizedExpense(
          total: MoneyMinor(1000, currency),
          payerContributionsByMemberId: {'u1': MoneyMinor(1000, currency)},
          participantSharesByMemberId: {
            'u1': MoneyMinor(333, currency),
            'u2': MoneyMinor(333, currency),
            'u3': MoneyMinor(334, currency),
          },
        );

        final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
        final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
        expect(sum, 0, reason: 'Deltas must sum to zero for $currency');
      }
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
        currencyCode: 'INR',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.amountMinor, 30000);
      expect(expense.participantSharesByMemberId.length, 3);
      
      final totalShares = expense.participantSharesByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(totalShares, 30000);
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
        currencyCode: 'INR',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      expect(expense.participantSharesByMemberId.length, 2);
      expect(expense.participantSharesByMemberId.containsKey('u1'), true);
      expect(expense.participantSharesByMemberId.containsKey('u2'), true);
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
        currencyCode: 'INR',
      );

      expect(result, isA<NormalizationSuccess>());
      final success = result as NormalizationSuccess;
      final expense = success.expense;

      final totalShares = expense.participantSharesByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(totalShares, 50000);
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
        currencyCode: 'INR',
      );

      expect(result, isA<NormalizationNeedsConfirmation>());
      final needsConfirm = result as NormalizationNeedsConfirmation;
      expect(needsConfirm.unresolvedNames, contains('Unknown Person'));
      expect(needsConfirm.currencyCode, 'INR');
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
        currencyCode: 'INR',
      );

      expect(result, isA<NormalizationError>());
    });
  });

  group('Remainder handling', () {
    test('100 paise split 3 ways: first person gets remainder', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 1.00,
        description: 'Test',
        category: '',
        date: 'Today',
        payerSlots: [const PayerContributionSlot(memberId: 'u1', amount: 1.00)],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 0.33, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 0.33, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 0.33, memberId: 'u3'),
        ],
        splitType: 'Even',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      final totalShares = expense.participantSharesByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(totalShares, 100);
    });

    test('JPY: 100 yen split 3 ways handles remainder', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 100,
        description: 'Test',
        category: '',
        date: 'Today',
        payerSlots: [const PayerContributionSlot(memberId: 'u1', amount: 100)],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 33, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 33, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 33, memberId: 'u3'),
        ],
        splitType: 'Even',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'JPY',
      );

      final totalShares = expense.participantSharesByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(totalShares, 100);
    });

    test('KWD: 1.000 dinar (1000 fils) split 3 ways handles remainder', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 1.000,
        description: 'Test',
        category: '',
        date: 'Today',
        payerSlots: [const PayerContributionSlot(memberId: 'u1', amount: 1.000)],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 0.333, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 0.333, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 0.333, memberId: 'u3'),
        ],
        splitType: 'Even',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'KWD',
      );

      final totalShares = expense.participantSharesByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(totalShares, 1000);
    });
  });

  group('Architectural guardrails', () {
    test('NormalizedExpense contains no names (only IDs)', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: 'Test',
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(20000, 'INR'),
        },
      );

      for (final id in expense.payerContributionsByMemberId.keys) {
        expect(id, isNot(contains('Alice')));
        expect(id, isNot(contains('Bob')));
      }
      for (final id in expense.participantSharesByMemberId.keys) {
        expect(id, isNot(contains('Alice')));
        expect(id, isNot(contains('Bob')));
      }
    });

    test('NormalizedExpense can be created without UI state', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(50000, 'INR'),
        payerContributionsByMemberId: {'user-123': MoneyMinor(50000, 'INR')},
        participantSharesByMemberId: {
          'user-123': MoneyMinor(25000, 'INR'),
          'user-456': MoneyMinor(25000, 'INR'),
        },
      );

      expect(expense.amountMinor, 50000);
      expect(expense.primaryPayerId, 'user-123');
    });

    test('expenseToLedgerDeltas is deterministic (same input = same output)', () {
      final deltas1 = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 30000,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 10000, 'u2': 20000},
        currencyCode: 'INR',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final deltas2 = expenseToLedgerDeltas(
        expenseId: 'e1',
        amountMinor: 30000,
        payerId: 'u1',
        splitAmountsByIdMinor: {'u1': 10000, 'u2': 20000},
        currencyCode: 'INR',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(deltas1.length, deltas2.length);
      for (var i = 0; i < deltas1.length; i++) {
        expect(deltas1[i].memberId, deltas2[i].memberId);
        expect(deltas1[i].deltaMinor, deltas2[i].deltaMinor);
      }
    });

    test('LedgerDelta contains no names', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(20000, 'INR'),
        },
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());

      for (final delta in deltas) {
        expect(delta.memberId, isNot(contains('Alice')));
        expect(delta.memberId, isNot(contains('Bob')));
        expect(delta.memberId.length, greaterThan(0));
      }
    });

    test('UI-only fields do not affect balance computation', () {
      final expense1 = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: 'Dinner at fancy restaurant',
        category: 'Food',
        date: 'Today',
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(20000, 'INR'),
        },
      );

      final expense2 = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        description: '',
        category: '',
        date: '',
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(20000, 'INR'),
        },
      );

      final deltas1 = toLedgerDeltas(expense1, 'e1', DateTime.now());
      final deltas2 = toLedgerDeltas(expense2, 'e1', DateTime.now());

      final map1 = {for (final d in deltas1) d.memberId: d.deltaMinor};
      final map2 = {for (final d in deltas2) d.memberId: d.deltaMinor};

      expect(map1, map2);
    });

    test('no tolerance logic in integer-based delta computation', () {
      final expense = NormalizedExpense(
        total: MoneyMinor(30000, 'INR'),
        payerContributionsByMemberId: {'u1': MoneyMinor(30000, 'INR')},
        participantSharesByMemberId: {
          'u1': MoneyMinor(10000, 'INR'),
          'u2': MoneyMinor(10000, 'INR'),
          'u3': MoneyMinor(10000, 'INR'),
        },
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      
      expect(sum, 0);
    });
  });

  group('Replay safety across currencies', () {
    test('replaying expense produces identical deltas for INR', () {
      final storedData = {
        'expenseId': 'e1',
        'amountMinor': 30000,
        'payerId': 'u1',
        'splitAmountsByIdMinor': {'u1': 10000, 'u2': 10000, 'u3': 10000},
        'currencyCode': 'INR',
      };

      final deltas1 = expenseToLedgerDeltas(
        expenseId: storedData['expenseId'] as String,
        amountMinor: storedData['amountMinor'] as int,
        payerId: storedData['payerId'] as String,
        splitAmountsByIdMinor: storedData['splitAmountsByIdMinor'] as Map<String, int>,
        currencyCode: storedData['currencyCode'] as String,
        timestamp: DateTime.now(),
      );

      final deltas2 = expenseToLedgerDeltas(
        expenseId: storedData['expenseId'] as String,
        amountMinor: storedData['amountMinor'] as int,
        payerId: storedData['payerId'] as String,
        splitAmountsByIdMinor: storedData['splitAmountsByIdMinor'] as Map<String, int>,
        currencyCode: storedData['currencyCode'] as String,
        timestamp: DateTime.now(),
      );

      expect(deltas1.length, deltas2.length);
      final map1 = {for (final d in deltas1) d.memberId: d.deltaMinor};
      final map2 = {for (final d in deltas2) d.memberId: d.deltaMinor};
      expect(map1, map2);
    });

    test('replaying expense produces identical deltas for JPY', () {
      final storedData = {
        'expenseId': 'e1',
        'amountMinor': 3000,
        'payerId': 'u1',
        'splitAmountsByIdMinor': {'u1': 1000, 'u2': 1000, 'u3': 1000},
        'currencyCode': 'JPY',
      };

      final deltas = expenseToLedgerDeltas(
        expenseId: storedData['expenseId'] as String,
        amountMinor: storedData['amountMinor'] as int,
        payerId: storedData['payerId'] as String,
        splitAmountsByIdMinor: storedData['splitAmountsByIdMinor'] as Map<String, int>,
        currencyCode: storedData['currencyCode'] as String,
        timestamp: DateTime.now(),
      );

      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      expect(sum, 0);
      expect(deltas.every((d) => d.currencyCode == 'JPY'), true);
    });

    test('replaying expense produces identical deltas for KWD', () {
      final storedData = {
        'expenseId': 'e1',
        'amountMinor': 3000,
        'payerId': 'u1',
        'splitAmountsByIdMinor': {'u1': 1000, 'u2': 1000, 'u3': 1000},
        'currencyCode': 'KWD',
      };

      final deltas = expenseToLedgerDeltas(
        expenseId: storedData['expenseId'] as String,
        amountMinor: storedData['amountMinor'] as int,
        payerId: storedData['payerId'] as String,
        splitAmountsByIdMinor: storedData['splitAmountsByIdMinor'] as Map<String, int>,
        currencyCode: storedData['currencyCode'] as String,
        timestamp: DateTime.now(),
      );

      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      expect(sum, 0);
      expect(deltas.every((d) => d.currencyCode == 'KWD'), true);
    });
  });

  group('Delta sum invariant across all split types', () {
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
      test('${tc.name}: sum of deltas is exactly zero', () {
        final result = normalizeExpense(
          parsed: tc.parsed,
          members: members,
          currentUserId: 'u1',
          currentUserName: 'Alice',
          currencyCode: 'INR',
        );

        expect(result, isA<NormalizationSuccess>());
        final expense = (result as NormalizationSuccess).expense;
        final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
        final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);

        expect(sum, 0, reason: 'Delta sum must be exactly zero for ${tc.name}');
      });
    }
  });

  group('Multi-payer support', () {
    test('PayerContributionSlot validation: empty slots rejected', () {
      final result = validatePayerContributions(
        total: 300.0,
        payerSlots: [],
      );
      
      expect(result, isA<PayerValidationError>());
      final error = result as PayerValidationError;
      expect(error.message, contains('At least one payer'));
    });

    test('PayerContributionSlot validation: unresolved payer rejected', () {
      final result = validatePayerContributions(
        total: 300.0,
        payerSlots: [
          const PayerContributionSlot(memberId: null, amount: 300.0),
        ],
      );
      
      expect(result, isA<PayerValidationError>());
      final error = result as PayerValidationError;
      expect(error.message, contains('must be selected'));
    });

    test('PayerContributionSlot validation: zero amount rejected', () {
      final result = validatePayerContributions(
        total: 300.0,
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 0),
        ],
      );
      
      expect(result, isA<PayerValidationError>());
      final error = result as PayerValidationError;
      expect(error.message, contains('must be positive'));
    });

    test('PayerContributionSlot validation: sum less than total rejected', () {
      final result = validatePayerContributions(
        total: 300.0,
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 100.0),
          const PayerContributionSlot(memberId: 'u2', amount: 100.0),
        ],
      );
      
      expect(result, isA<PayerValidationError>());
      final error = result as PayerValidationError;
      expect(error.message, contains('less than total'));
      expect(error.expected, 300.0);
      expect(error.actual, 200.0);
    });

    test('PayerContributionSlot validation: sum exceeds total rejected', () {
      final result = validatePayerContributions(
        total: 300.0,
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 200.0),
          const PayerContributionSlot(memberId: 'u2', amount: 200.0),
        ],
      );
      
      expect(result, isA<PayerValidationError>());
      final error = result as PayerValidationError;
      expect(error.message, contains('exceed total'));
    });

    test('PayerContributionSlot validation: exact sum accepted', () {
      final result = validatePayerContributions(
        total: 300.0,
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 150.0),
          const PayerContributionSlot(memberId: 'u2', amount: 150.0),
        ],
      );
      
      expect(result, isA<PayerValidationSuccess>());
    });

    test('Two payers splitting payment unevenly', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 300.0,
        description: 'Dinner',
        category: 'Food',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 200.0),
          const PayerContributionSlot(memberId: 'u2', amount: 100.0),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 100.0, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 100.0, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 100.0, memberId: 'u3'),
        ],
        splitType: 'Exact',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      expect(expense.payerContributionsByMemberId.length, 2);
      expect(expense.payerContributionsByMemberId['u1']!.amountMinor, 20000);
      expect(expense.payerContributionsByMemberId['u2']!.amountMinor, 10000);
      expect(expense.participantSharesByMemberId.length, 3);
      
      final payerSum = expense.payerContributionsByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(payerSum, expense.total.amountMinor);
    });

    test('Three payers summing exactly to total', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 900.0,
        description: 'Group outing',
        category: 'Entertainment',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 300.0),
          const PayerContributionSlot(memberId: 'u2', amount: 300.0),
          const PayerContributionSlot(memberId: 'u3', amount: 300.0),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 300.0, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 300.0, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 300.0, memberId: 'u3'),
        ],
        splitType: 'Exact',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      expect(expense.payerContributionsByMemberId.length, 3);
      expect(expense.payerContributionsByMemberId['u1']!.amountMinor, 30000);
      expect(expense.payerContributionsByMemberId['u2']!.amountMinor, 30000);
      expect(expense.payerContributionsByMemberId['u3']!.amountMinor, 30000);
    });

    test('Multi-payer with even split participants', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 300.0,
        description: 'Lunch',
        category: 'Food',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 200.0),
          const PayerContributionSlot(memberId: 'u2', amount: 100.0),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 100.0, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 100.0, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 100.0, memberId: 'u3'),
        ],
        splitType: 'Even',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      final payerSum = expense.payerContributionsByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      final participantSum = expense.participantSharesByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      
      expect(payerSum, expense.total.amountMinor);
      expect(participantSum, expense.total.amountMinor);
    });

    test('Multi-payer with percentage split', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 1000.0,
        description: 'Project expense',
        category: 'Work',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 600.0),
          const PayerContributionSlot(memberId: 'u2', amount: 400.0),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 500.0, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 300.0, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 200.0, memberId: 'u3'),
        ],
        splitType: 'Percentage',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      expect(expense.payerContributionsByMemberId['u1']!.amountMinor, 60000);
      expect(expense.payerContributionsByMemberId['u2']!.amountMinor, 40000);
      
      final payerSum = expense.payerContributionsByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(payerSum, expense.total.amountMinor);
    });

    test('Multi-payer ledger deltas sum to zero', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 300.0,
        description: 'Shared payment',
        category: 'General',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 200.0),
          const PayerContributionSlot(memberId: 'u2', amount: 100.0),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 100.0, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 100.0, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 100.0, memberId: 'u3'),
        ],
        splitType: 'Exact',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
      
      expect(sum, 0, reason: 'Multi-payer deltas must sum to zero');
    });

    test('Multi-payer: payer contributions stored correctly', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 300.0,
        description: 'Shared payment',
        category: 'General',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 200.0),
          const PayerContributionSlot(memberId: 'u2', amount: 100.0),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 100.0, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 100.0, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 100.0, memberId: 'u3'),
        ],
        splitType: 'Exact',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      expect(expense.payerContributionsByMemberId['u1']!.amountMinor, 20000,
          reason: 'u1 paid 200 = 20000 paise');
      expect(expense.payerContributionsByMemberId['u2']!.amountMinor, 10000,
          reason: 'u2 paid 100 = 10000 paise');
    });

    test('Multi-payer: net deltas are correct', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 300.0,
        description: 'Shared payment',
        category: 'General',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 200.0),
          const PayerContributionSlot(memberId: 'u2', amount: 100.0),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 100.0, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 100.0, memberId: 'u2'),
          ParticipantSlot(name: 'Charlie', amount: 100.0, memberId: 'u3'),
        ],
        splitType: 'Exact',
        allMemberIds: ['u1', 'u2', 'u3'],
        currencyCode: 'INR',
      );

      final deltas = toLedgerDeltas(expense, 'e1', DateTime.now());
      final deltaMap = {for (var d in deltas) d.memberId: d.deltaMinor};
      
      expect(deltaMap['u1'], 10000, reason: 'u1: paid 200, owes 100 → net +100 = +10000');
      expect(deltaMap.containsKey('u2'), false, reason: 'u2: paid 100, owes 100 → net 0 (no delta created)');
      expect(deltaMap['u3'], -10000, reason: 'u3: paid 0, owes 100 → net -100 = -10000');
    });

    test('NormalizationNeedsConfirmation includes payerSlots', () {
      final parsed = ParsedExpenseResult(
        amount: 300.0,
        description: 'Test',
        category: 'Test',
        splitType: 'exact',
        participantNames: [],
        excludedNames: [],
        exactAmountsByName: {},
      );

      final result = normalizeExpense(
        parsed: parsed,
        members: members,
        currentUserId: 'u1',
        currentUserName: 'Alice',
        currencyCode: 'INR',
      );

      if (result is NormalizationNeedsConfirmation) {
        expect(result.payerSlots, isNotEmpty);
        expect(result.payerSlots.first.memberId, 'u1');
        expect(result.payerSlots.first.amount, 300.0);
        expect(result.payerId, 'u1');
      }
    });

    test('NormalizationNeedsConfirmation backward compatibility: payerId getter', () {
      final confirmation = NormalizationNeedsConfirmation(
        amount: 300.0,
        description: 'Test',
        category: 'Test',
        date: 'Today',
        splitType: 'Even',
        currencyCode: 'INR',
        slots: [],
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 300.0),
        ],
        unresolvedNames: [],
      );

      expect(confirmation.payerId, 'u1');
    });

    test('Rounding remainder assigned to first payer', () {
      final expense = buildNormalizedExpenseFromSlots(
        amount: 100.01,
        description: 'Test rounding',
        category: 'Test',
        date: 'Today',
        payerSlots: [
          const PayerContributionSlot(memberId: 'u1', amount: 50.00),
          const PayerContributionSlot(memberId: 'u2', amount: 50.00),
        ],
        slots: [
          ParticipantSlot(name: 'Alice', amount: 50.00, memberId: 'u1'),
          ParticipantSlot(name: 'Bob', amount: 50.00, memberId: 'u2'),
        ],
        splitType: 'Exact',
        allMemberIds: ['u1', 'u2'],
        currencyCode: 'INR',
      );

      final payerSum = expense.payerContributionsByMemberId.values
          .fold(0, (sum, m) => sum + m.amountMinor);
      expect(payerSum, expense.total.amountMinor);
      expect(expense.payerContributionsByMemberId['u1']!.amountMinor, 5001);
    });
  });
}
