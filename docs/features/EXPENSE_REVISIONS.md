# Expense Revisions (Edit & Delete)

**Status:** IMPLEMENTED  
**File:** `lib/utils/expense_revision.dart`  
**Tests:** `test/expense_revision_test.dart`

---

## Overview

Expenses are **immutable** in Expenso. Edits and deletions are implemented as **compensation events** that preserve the complete audit trail.

---

## Compensation Model

### Core Principle

> Old ledger entries are **never modified or deleted**. New entries are appended to compensate.

### Operations

| Operation | Implementation |
|-----------|----------------|
| **Create** | Add expense → generate deltas |
| **Edit** | Negate original deltas → add new deltas |
| **Delete** | Negate original deltas only |

### Example: Editing an Expense

```
Original expense (e1): Alice paid ₹300, split evenly with Bob
  → Alice: +150 (paid 300, owes 150)
  → Bob:   -150 (owes 150)

Edit: Change amount to ₹200
  1. Negate e1 deltas:
     → Alice: -150
     → Bob:   +150
  2. Add new deltas:
     → Alice: +100 (paid 200, owes 100)
     → Bob:   -100

Net effect:
  → Alice: +150 - 150 + 100 = +100
  → Bob:   -150 + 150 - 100 = -100
```

---

## Expense Lifecycle

Each expense has exactly one lifecycle state, derived from revision metadata:

| State | Meaning | Can Edit? | Can Delete? |
|-------|---------|-----------|-------------|
| **active** | Currently affects balances | ✓ | ✓ |
| **deleted** | Has been deleted | ✗ | ✗ |
| **superseded** | Replaced by a newer edit | ✗ | ✗ |

### Determining State

```dart
ExpenseLifecycleState deriveExpenseState({
  required String expenseId,
  required List<ExpenseRevision> revisions,
  required Set<String> deletedExpenseIds,
})
```

- If in `deletedExpenseIds` → **deleted**
- If any revision has `replacesExpenseId == expenseId` → **superseded**  
- Otherwise → **active**

---

## Guards

Before any edit or delete operation, the caller **must** verify the expense is active:

```dart
// Before editing
guardEdit(
  expenseId: 'e1',
  revisions: allRevisions,
  deletedExpenseIds: deletedIds,
);

// Before deleting
guardDelete(
  expenseId: 'e1',
  revisions: allRevisions,
  deletedExpenseIds: deletedIds,
);
```

These throw `ExpenseLifecycleError` if the expense is not active.

---

## Edit-After-Delete Prevention

### Problem

Without guards, editing a deleted expense would:
1. Generate negation of original (already negated by delete)
2. Generate negation of negation (resurrects original!)
3. Add new deltas

This would **accidentally resurrect** a deleted expense.

### Solution

The `guardEdit` function prevents this by checking lifecycle state before allowing edits:

```dart
// This throws ExpenseLifecycleError
guardEdit(expenseId: deletedExpenseId, ...);
```

### Rule

> An expense that has been deleted or superseded **cannot** be edited.  
> To modify a chain of edits, always edit the **latest active revision**.

---

## Data Structures

### ExpenseRevision

```dart
class ExpenseRevision {
  final String expenseId;
  final String? replacesExpenseId;  // null for originals
}
```

### ExpenseLifecycleError

```dart
class ExpenseLifecycleError extends Error {
  final String message;
  final String expenseId;
  final ExpenseLifecycleState state;
}
```

---

## Pure Functions

All revision functions are **pure** (no side effects, no DB access):

| Function | Purpose |
|----------|---------|
| `negateDeltas(...)` | Invert deltas for compensation |
| `generateEditDeltas(...)` | Combine negation + new deltas |
| `generateDeleteDeltas(...)` | Negation only |
| `computeNetBalancesFromAllDeltas(...)` | Sum all deltas (originals + compensations) |
| `deriveExpenseState(...)` | Determine lifecycle state |
| `guardEdit(...)` | Throw if not active |
| `guardDelete(...)` | Throw if not active |

---

## Invariants

| # | Invariant | Enforced |
|---|-----------|----------|
| R1 | Old deltas are never modified | ✓ By design |
| R2 | Sum of all deltas = 0 | ✓ Tested |
| R3 | Deleted expenses have zero net effect | ✓ Tested |
| R4 | Only active expenses can be edited | ✓ `guardEdit` |
| R5 | Only active expenses can be deleted | ✓ `guardDelete` |
| R6 | Full history is preserved for audit | ✓ By design |
| R7 | Replay produces identical results | ✓ Tested |

---

## Integration Status

### Repository Layer — INTEGRATED

The `CycleRepository` now uses lifecycle guards for edit/delete operations:

```dart
// Delete uses soft-delete (marks as deleted, preserves audit trail)
await repo.deleteExpense(groupId, expenseId);

// Update validates expense is active before allowing changes
repo.updateExpense(groupId, updatedExpense);

// Query lifecycle state
final state = repo.getExpenseLifecycleState(groupId, expenseId);
final canEdit = repo.canEditExpense(groupId, expenseId);
final canDelete = repo.canDeleteExpense(groupId, expenseId);
```

### Firestore Storage

| Collection | Purpose |
|------------|---------|
| `groups/{groupId}/expense_revisions` | Tracks edit chains (replacesExpenseId) |
| `groups/{groupId}/deleted_expenses` | Stores deleted expense IDs with timestamps |

### For UI Layer

Disable edit/delete buttons for non-active expenses:

```dart
final canModify = repo.canEditExpense(groupId, expense.id);
// Use canModify to enable/disable UI controls
```

---

## Test Coverage

See `test/expense_revision_test.dart`:

- `negateDeltas`: 6 tests
- `generateEditDeltas`: 2 tests  
- `generateDeleteDeltas`: 2 tests
- `Historical replay determinism`: 1 test
- `Ledger invariants`: 2 tests
- `Audit trail preservation`: 2 tests
- `ExpenseRevision model`: 2 tests
- `ExpenseLifecycleState derivation`: 5 tests
- `Lifecycle guards`: 8 tests
- `Edit-after-delete prevention`: 2 tests
