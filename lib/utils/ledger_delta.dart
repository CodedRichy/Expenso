import '../models/money_minor.dart';
import '../models/normalized_expense.dart';

/// A single balance-affecting entry in the ledger.
/// 
/// This model represents a fully-resolved accounting event.
/// It must be safe to replay at any time in the future.
/// 
/// ## Design Principles
/// - **UI-agnostic:** No UI concepts (selections, confirmation state)
/// - **Timeless:** Computed from stored data, not current group state
/// - **Deterministic:** Same input always produces same output
/// - **Integer-only:** Uses [MoneyMinor] for exact arithmetic
/// 
/// ## Properties
/// - Positive delta = credit (member is owed money)
/// - Negative delta = debit (member owes money)
/// 
/// ## Invariants
/// - The sum of all deltas for an expense must be exactly zero
/// - No inference from "everyone" or dynamic group membership
/// - Member IDs must be valid (non-empty, no `p_` prefixes)
/// - All deltas in a set must share the same currency
class LedgerDelta {
  final String memberId;
  
  /// Balance change in minor units.
  /// Positive = credit (owed to member), negative = debit (member owes).
  final MoneyMinor delta;
  
  final String expenseId;
  final DateTime timestamp;

  const LedgerDelta({
    required this.memberId,
    required this.delta,
    required this.expenseId,
    required this.timestamp,
  });

  /// Convenience getter for the minor amount.
  int get deltaMinor => delta.amountMinor;

  /// Convenience getter for the currency code.
  String get currencyCode => delta.currencyCode;

  @override
  String toString() => 'LedgerDelta($memberId: ${delta.amountMinor} ${delta.currencyCode} for $expenseId)';
}

/// Converts a NormalizedExpense into a list of LedgerDeltas.
/// 
/// Rules:
/// - For each payer: +paidAmount (they are owed back)
/// - For each participant: -shareAmount (they owe)
/// - Net sum of all deltas is exactly zero (asserted)
/// 
/// This is a pure function with no side effects.
/// Uses integer arithmetic only - no floating-point.
List<LedgerDelta> toLedgerDeltas(
  NormalizedExpense expense,
  String expenseId,
  DateTime timestamp,
) {
  final currencyCode = expense.currencyCode;
  final Map<String, int> netByMember = {};

  for (final entry in expense.payerContributionsByMemberId.entries) {
    netByMember[entry.key] = (netByMember[entry.key] ?? 0) + entry.value.amountMinor;
  }

  for (final entry in expense.participantSharesByMemberId.entries) {
    netByMember[entry.key] = (netByMember[entry.key] ?? 0) - entry.value.amountMinor;
  }

  final deltas = <LedgerDelta>[];
  for (final entry in netByMember.entries) {
    if (entry.value != 0) {
      deltas.add(LedgerDelta(
        memberId: entry.key,
        delta: MoneyMinor(entry.value, currencyCode),
        expenseId: expenseId,
        timestamp: timestamp,
      ));
    }
  }

  final sum = deltas.fold(0, (acc, d) => acc + d.deltaMinor);
  assert(
    sum == 0,
    'LedgerDelta sum must be exactly zero, got $sum',
  );

  return deltas;
}

/// Converts a stored Expense (from Firestore) into LedgerDeltas.
/// 
/// This is the canonical replay-safe conversion function.
/// 
/// ## Replay Safety
/// This function uses ONLY explicitly stored data:
/// - `amountMinor`: The total expense amount in minor units
/// - `payerId`: Who paid (stored, not inferred)
/// - `splitAmountsByIdMinor`: Exact per-person shares in minor units (stored, not computed)
/// - `currencyCode`: The expense currency
/// 
/// It does NOT use:
/// - Current group membership
/// - "Everyone" semantics
/// - Dynamic participant lists
/// 
/// This ensures that old expenses produce identical deltas regardless
/// of group membership changes after the expense was created.
List<LedgerDelta> expenseToLedgerDeltas({
  required String expenseId,
  required int amountMinor,
  required String payerId,
  required Map<String, int> splitAmountsByIdMinor,
  required String currencyCode,
  required DateTime timestamp,
}) {
  if (amountMinor <= 0) {
    return [];
  }
  if (payerId.isEmpty || payerId.startsWith('p_')) {
    return [];
  }

  final Map<String, int> netByMember = {};

  netByMember[payerId] = (netByMember[payerId] ?? 0) + amountMinor;

  for (final entry in splitAmountsByIdMinor.entries) {
    if (entry.key.startsWith('p_')) continue;
    if (entry.key.isEmpty) continue;
    netByMember[entry.key] = (netByMember[entry.key] ?? 0) - entry.value;
  }

  final deltas = <LedgerDelta>[];
  for (final entry in netByMember.entries) {
    if (entry.value != 0) {
      deltas.add(LedgerDelta(
        memberId: entry.key,
        delta: MoneyMinor(entry.value, currencyCode),
        expenseId: expenseId,
        timestamp: timestamp,
      ));
    }
  }

  return deltas;
}

/// Legacy adapter: Converts double-based expense data to LedgerDeltas.
/// 
/// This is used during migration from float-based storage to integer-based.
/// Converts doubles to minor units using the currency's scale.
/// 
/// TODO: Remove once all stored expenses use integer amounts.
List<LedgerDelta> expenseToLedgerDeltasLegacy({
  required String expenseId,
  required double amount,
  required String payerId,
  required Map<String, double> splitAmountsById,
  required String currencyCode,
  required DateTime timestamp,
}) {
  if (amount <= 0 || amount.isNaN || amount.isInfinite) {
    return [];
  }
  if (payerId.isEmpty || payerId.startsWith('p_')) {
    return [];
  }

  final amountMinor = MoneyConversion.parseToMinor(amount, currencyCode).amountMinor;
  
  final splitAmountsByIdMinor = <String, int>{};
  for (final entry in splitAmountsById.entries) {
    if (entry.key.startsWith('p_')) continue;
    if (entry.key.isEmpty) continue;
    if (entry.value.isNaN || entry.value.isInfinite) continue;
    splitAmountsByIdMinor[entry.key] = 
        MoneyConversion.parseToMinor(entry.value, currencyCode).amountMinor;
  }

  return expenseToLedgerDeltas(
    expenseId: expenseId,
    amountMinor: amountMinor,
    payerId: payerId,
    splitAmountsByIdMinor: splitAmountsByIdMinor,
    currencyCode: currencyCode,
    timestamp: timestamp,
  );
}
