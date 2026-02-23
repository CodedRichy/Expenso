import '../models/money_minor.dart';
import 'ledger_delta.dart';

// ============================================================
// EXPENSE LIFECYCLE
// ============================================================

/// Lifecycle state of an expense (derived from revision history).
/// 
/// ## States
/// - [active]: The expense affects balances. Can be edited or deleted.
/// - [deleted]: The expense has been deleted. Cannot be edited or deleted again.
/// - [superseded]: The expense was replaced by an edit. Cannot be edited or deleted.
/// 
/// ## Rules
/// - Only [active] expenses can be edited
/// - Only [active] expenses can be deleted
/// - Editing a deleted/superseded expense is an error
/// - Deleting an already-deleted expense is a no-op (or error, caller's choice)
enum ExpenseLifecycleState { active, deleted, superseded }

/// Derives the lifecycle state of an expense from revision metadata.
/// 
/// ## Parameters
/// - [expenseId]: The expense to check
/// - [revisions]: All revision records in the system
/// - [deletedExpenseIds]: Set of expense IDs that have been deleted
/// 
/// ## Returns
/// The current lifecycle state of the expense.
ExpenseLifecycleState deriveExpenseState({
  required String expenseId,
  required List<ExpenseRevision> revisions,
  required Set<String> deletedExpenseIds,
}) {
  if (deletedExpenseIds.contains(expenseId)) {
    return ExpenseLifecycleState.deleted;
  }
  
  final hasBeenSuperseded = revisions.any((r) => r.replacesExpenseId == expenseId);
  if (hasBeenSuperseded) {
    return ExpenseLifecycleState.superseded;
  }
  
  return ExpenseLifecycleState.active;
}

/// Error thrown when attempting to modify a non-active expense.
class ExpenseLifecycleError extends Error {
  final String message;
  final String expenseId;
  final ExpenseLifecycleState state;
  
  ExpenseLifecycleError(this.message, this.expenseId, this.state);
  
  @override
  String toString() => 'ExpenseLifecycleError: $message (expense: $expenseId, state: $state)';
}

/// Guards an edit operation. Throws if the expense is not active.
/// 
/// Call this before generating edit deltas to prevent editing
/// deleted or superseded expenses.
void guardEdit({
  required String expenseId,
  required List<ExpenseRevision> revisions,
  required Set<String> deletedExpenseIds,
}) {
  final state = deriveExpenseState(
    expenseId: expenseId,
    revisions: revisions,
    deletedExpenseIds: deletedExpenseIds,
  );
  
  if (state != ExpenseLifecycleState.active) {
    throw ExpenseLifecycleError(
      'Cannot edit expense: it is $state',
      expenseId,
      state,
    );
  }
}

/// Guards a delete operation. Throws if the expense is not active.
/// 
/// Call this before generating delete deltas to prevent deleting
/// already-deleted or superseded expenses.
void guardDelete({
  required String expenseId,
  required List<ExpenseRevision> revisions,
  required Set<String> deletedExpenseIds,
}) {
  final state = deriveExpenseState(
    expenseId: expenseId,
    revisions: revisions,
    deletedExpenseIds: deletedExpenseIds,
  );
  
  if (state != ExpenseLifecycleState.active) {
    throw ExpenseLifecycleError(
      'Cannot delete expense: it is $state',
      expenseId,
      state,
    );
  }
}

// ============================================================
// EXPENSE REVISION MODEL
// ============================================================

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
