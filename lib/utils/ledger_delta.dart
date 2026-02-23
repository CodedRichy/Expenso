import '../models/normalized_expense.dart';

const double _tolerance = 0.01;

/// A single balance-affecting entry in the ledger.
/// 
/// Represents a change to a member's balance for a specific expense.
/// - Positive delta = credit (member is owed money)
/// - Negative delta = debit (member owes money)
/// 
/// The sum of all deltas for an expense must be exactly zero.
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
/// This bridges the gap between the existing Expense model and the new
/// delta-based computation. Used during migration to ensure both paths
/// produce identical results.
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
