import '../models/normalized_expense.dart';

const double _tolerance = 0.01;

/// A single balance-affecting entry in the ledger.
/// 
/// This model represents a fully-resolved accounting event.
/// It must be safe to replay at any time in the future.
/// 
/// ## Design Principles
/// - **UI-agnostic:** No UI concepts (selections, confirmation state)
/// - **Timeless:** Computed from stored data, not current group state
/// - **Deterministic:** Same input always produces same output
/// 
/// ## Properties
/// - Positive delta = credit (member is owed money)
/// - Negative delta = debit (member owes money)
/// 
/// ## Invariants
/// - The sum of all deltas for an expense must be exactly zero
/// - No inference from "everyone" or dynamic group membership
/// - Member IDs must be valid (non-empty, no `p_` prefixes)
class LedgerDelta {
  final String memberId;
  final double delta;
  final String expenseId;
  final DateTime timestamp;

  const LedgerDelta({
    required this.memberId,
    required this.delta,
    required this.expenseId,
    required this.timestamp,
  });

  @override
  String toString() => 'LedgerDelta($memberId: $delta for $expenseId)';
}

/// Converts a NormalizedExpense into a list of LedgerDeltas.
/// 
/// Rules:
/// - For each payer: +paidAmount (they are owed back)
/// - For each participant: -shareAmount (they owe)
/// - Net sum of all deltas is exactly zero (asserted)
/// 
/// This is a pure function with no side effects.
List<LedgerDelta> toLedgerDeltas(
  NormalizedExpense expense,
  String expenseId,
  DateTime timestamp,
) {
  final deltas = <LedgerDelta>[];
  final Map<String, double> netByMember = {};

  for (final entry in expense.payerContributionsByMemberId.entries) {
    netByMember[entry.key] = (netByMember[entry.key] ?? 0) + entry.value;
  }

  for (final entry in expense.participantSharesByMemberId.entries) {
    netByMember[entry.key] = (netByMember[entry.key] ?? 0) - entry.value;
  }

  for (final entry in netByMember.entries) {
    if (entry.value.abs() > _tolerance) {
      deltas.add(LedgerDelta(
        memberId: entry.key,
        delta: entry.value,
        expenseId: expenseId,
        timestamp: timestamp,
      ));
    }
  }

  final sum = deltas.fold(0.0, (acc, d) => acc + d.delta);
  assert(
    sum.abs() < _tolerance,
    'LedgerDelta sum must be zero, got $sum',
  );

  return deltas;
}

/// Converts a stored Expense (from Firestore) into LedgerDeltas.
/// 
/// This is the canonical replay-safe conversion function.
/// 
/// ## Replay Safety
/// This function uses ONLY explicitly stored data:
/// - `amount`: The total expense amount
/// - `payerId`: Who paid (stored, not inferred)
/// - `splitAmountsById`: Exact per-person shares (stored, not computed)
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
  required double amount,
  required String payerId,
  required Map<String, double> splitAmountsById,
  required DateTime timestamp,
}) {
  if (amount <= 0 || amount.isNaN || amount.isInfinite) {
    return [];
  }
  if (payerId.isEmpty || payerId.startsWith('p_')) {
    return [];
  }

  final Map<String, double> netByMember = {};

  netByMember[payerId] = (netByMember[payerId] ?? 0) + amount;

  for (final entry in splitAmountsById.entries) {
    if (entry.key.startsWith('p_')) continue;
    if (entry.key.isEmpty) continue;
    final shareAmount = entry.value;
    if (shareAmount.isNaN || shareAmount.isInfinite) continue;
    netByMember[entry.key] = (netByMember[entry.key] ?? 0) - shareAmount;
  }

  final deltas = <LedgerDelta>[];
  for (final entry in netByMember.entries) {
    if (entry.value.abs() > _tolerance) {
      deltas.add(LedgerDelta(
        memberId: entry.key,
        delta: entry.value,
        expenseId: expenseId,
        timestamp: timestamp,
      ));
    }
  }

  return deltas;
}
