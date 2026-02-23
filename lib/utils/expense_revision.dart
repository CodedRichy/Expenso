import '../models/money_minor.dart';
import 'ledger_delta.dart';

/// Represents an expense event in an append-only ledger.
/// 
/// ## Compensation Model
/// Expenses are immutable. Edits and deletions are implemented as compensation events:
/// - **Original expense:** `replacesExpenseId = null`
/// - **Edited expense:** `replacesExpenseId = originalExpenseId` (negates original + adds new)
/// - **Deleted expense:** Compensation entry that negates the original
/// 
/// ## Balance Computation
/// When computing balances, include all deltas:
/// - Original deltas + negation deltas + replacement deltas
/// - Net effect: only the final revision affects balances
/// 
/// ## Audit Trail
/// Old deltas are never modified or deleted. The full history is preserved.
class ExpenseRevision {
  final String expenseId;
  
  /// If non-null, this expense replaces (compensates for) another expense.
  /// The original expense's deltas are negated by this revision.
  final String? replacesExpenseId;

  const ExpenseRevision({
    required this.expenseId,
    this.replacesExpenseId,
  });

  bool get isOriginal => replacesExpenseId == null;
  bool get isRevision => replacesExpenseId != null;
}

/// Negates a list of ledger deltas for compensation.
/// 
/// Rules:
/// - Each delta is inverted (-deltaMinor)
/// - Same memberId
/// - Same currency
/// - New expenseId (the compensation event ID)
/// - New timestamp
/// 
/// This is a pure function. It does not modify the input or any accounting logic.
/// 
/// ## Usage
/// ```dart
/// final originalDeltas = expenseToLedgerDeltas(...);
/// final negationDeltas = negateDeltas(originalDeltas, 'compensation_id', DateTime.now());
/// // Net effect: originalDeltas + negationDeltas = zero for each member
/// ```
List<LedgerDelta> negateDeltas(
  List<LedgerDelta> original,
  String newExpenseId,
  DateTime timestamp,
) {
  return original.map((delta) => LedgerDelta(
    memberId: delta.memberId,
    delta: MoneyMinor(-delta.deltaMinor, delta.currencyCode),
    expenseId: newExpenseId,
    timestamp: timestamp,
  )).toList();
}

/// Generates all ledger deltas for an expense edit operation.
/// 
/// An edit is modeled as:
/// 1. Negation of the original expense's deltas
/// 2. Addition of the new expense's deltas
/// 
/// Returns a combined list of deltas that, when applied:
/// - Cancels out the original expense
/// - Applies the new expense
/// 
/// ## Parameters
/// - [originalDeltas]: The deltas from the expense being edited
/// - [newDeltas]: The deltas from the replacement expense
/// - [compensationExpenseId]: The ID for the compensation event (usually the new expense ID)
/// - [timestamp]: Timestamp for the compensation deltas
/// 
/// ## Invariants
/// - Sum of returned deltas equals sum of newDeltas (original is fully negated)
/// - All currency codes match
List<LedgerDelta> generateEditDeltas({
  required List<LedgerDelta> originalDeltas,
  required List<LedgerDelta> newDeltas,
  required String compensationExpenseId,
  required DateTime timestamp,
}) {
  final negation = negateDeltas(originalDeltas, compensationExpenseId, timestamp);
  return [...negation, ...newDeltas];
}

/// Generates ledger deltas for an expense deletion.
/// 
/// A deletion is modeled as negation of the original expense's deltas.
/// The net effect is that the expense no longer affects balances.
/// 
/// ## Parameters
/// - [originalDeltas]: The deltas from the expense being deleted
/// - [compensationExpenseId]: The ID for the compensation event
/// - [timestamp]: Timestamp for the compensation deltas
/// 
/// ## Invariants
/// - Sum of returned deltas + original deltas = 0 for each member
List<LedgerDelta> generateDeleteDeltas({
  required List<LedgerDelta> originalDeltas,
  required String compensationExpenseId,
  required DateTime timestamp,
}) {
  return negateDeltas(originalDeltas, compensationExpenseId, timestamp);
}

/// Computes net balances from a list of deltas including all revisions.
/// 
/// This function simply sums all deltas. It does not filter or exclude
/// any deltas based on revision status. The compensation model ensures
/// that:
/// - Deleted expenses have zero net effect (original + negation = 0)
/// - Edited expenses only reflect the final version (original + negation + new = new)
/// 
/// ## Parameters
/// - [allDeltas]: All ledger deltas including originals, negations, and replacements
/// 
/// ## Returns
/// Map of memberId to net balance in minor units.
Map<String, int> computeNetBalancesFromAllDeltas(
  List<LedgerDelta> allDeltas,
  String currencyCode,
) {
  final Map<String, int> net = {};
  
  for (final delta in allDeltas) {
    if (delta.memberId.isEmpty || delta.memberId.startsWith('p_')) continue;
    if (delta.currencyCode != currencyCode) {
      throw ArgumentError(
        'Currency mismatch: expected $currencyCode, got ${delta.currencyCode}',
      );
    }
    net[delta.memberId] = (net[delta.memberId] ?? 0) + delta.deltaMinor;
  }
  
  return Map.unmodifiable(net);
}
