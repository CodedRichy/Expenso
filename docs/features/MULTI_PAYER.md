# Multi-Payer Expense Support

**Status:** IMPLEMENTED  
**File:** `lib/utils/normalization_workflow.dart`  
**Tests:** `test/expense_normalization_test.dart` (Multi-payer support group)

---

## Overview

Expenso supports expenses where **multiple people contribute to a single payment**. This is common in scenarios like:

- Friends splitting a bill with separate cards
- One person paying cash + another paying by card
- Business trips where expenses are shared upfront

---

## UI Model

### PayerContributionSlot

```dart
class PayerContributionSlot {
  final String? memberId;  // Who paid
  final double amount;     // How much (display units)
}
```

This is a **UI-only model** used in expense confirmation dialogs. It is converted to `MoneyMinor` (integer) at the normalization boundary.

### Rules

- **Explicit only**: No inferred splitting or fallback to single payer
- **User-entered amounts**: No defaults beyond zero
- **Validation before normalization**: Sum must match total exactly

---

## Validation

Before an expense can be normalized, payer contributions are validated:

```dart
PayerValidationResult validatePayerContributions({
  required double total,
  required List<PayerContributionSlot> payerSlots,
})
```

### Validation Rules

| Rule | Error Message |
|------|---------------|
| At least one payer required | "At least one payer is required" |
| All payers must be selected | "All payers must be selected" |
| All amounts must be positive | "All payer amounts must be positive" |
| Sum must equal total | "Payer contributions (X) are less/exceed total (Y)" |

### Return Types

```dart
sealed class PayerValidationResult {}
class PayerValidationSuccess extends PayerValidationResult {}
class PayerValidationError extends PayerValidationResult {
  final String message;
  final double expected;
  final double actual;
}
```

---

## Normalization

When normalizing an expense, payer slots are converted to integer contributions:

```dart
NormalizedExpense buildNormalizedExpenseFromSlots({
  required double amount,
  required List<PayerContributionSlot> payerSlots,  // NEW
  required List<ParticipantSlot> slots,
  // ... other params
})
```

### Rounding

When converting display amounts to minor units, integer division may produce a remainder. The remainder is assigned to the **first payer** (deterministic, documented).

Example: Total ₹100.01 split between two payers (₹50.00 each)
- Total minor: 10001 paise
- Payer 1: 5000 + 1 (remainder) = 5001 paise
- Payer 2: 5000 paise

---

## Backward Compatibility

`NormalizationNeedsConfirmation` provides a `payerId` getter for backward compatibility:

```dart
String get payerId => payerSlots.isNotEmpty 
    ? (payerSlots.first.memberId ?? '') 
    : '';
```

---

## Accounting Core (Unchanged)

The multi-payer feature **does not modify** any accounting core logic:

| Component | Status |
|-----------|--------|
| `NormalizedExpense` | **Unchanged** (already supports `payerContributionsByMemberId`) |
| `LedgerDelta` | **Unchanged** |
| `SettlementEngine` | **Unchanged** |
| `toLedgerDeltas()` | **Unchanged** (already iterates over all payer contributions) |

Multi-payer support was already built into the accounting model. This change **exposes** that capability to the UI/normalization layer.

---

## Test Coverage

| Scenario | Test |
|----------|------|
| Empty slots rejected | ✓ |
| Unresolved payer rejected | ✓ |
| Zero amount rejected | ✓ |
| Sum less than total rejected | ✓ |
| Sum exceeds total rejected | ✓ |
| Exact sum accepted | ✓ |
| Two payers splitting unevenly | ✓ |
| Three payers summing exactly | ✓ |
| Multi-payer with even split | ✓ |
| Multi-payer with percentage split | ✓ |
| Ledger deltas sum to zero | ✓ |
| Payer contributions stored correctly | ✓ |
| Net deltas are correct | ✓ |
| Rounding remainder to first payer | ✓ |
| NormalizationNeedsConfirmation includes payerSlots | ✓ |
| Backward compatibility: payerId getter | ✓ |

---

## UX Guidelines

When implementing the UI:

1. **Show "who paid how much"** clearly with editable amount fields
2. **Display running total** vs expected total in real-time
3. **Disable submit** until `validatePayerContributions` returns `PayerValidationSuccess`
4. **Show clear error messages** from `PayerValidationError.message`
5. **No silent fixes**: Never auto-balance mismatches

---

## Example Usage

```dart
// UI creates payer slots from user input
final payerSlots = [
  PayerContributionSlot(memberId: 'alice_id', amount: 200.0),
  PayerContributionSlot(memberId: 'bob_id', amount: 100.0),
];

// Validate before proceeding
final validation = validatePayerContributions(
  total: 300.0,
  payerSlots: payerSlots,
);

if (validation is PayerValidationError) {
  showError(validation.message);
  return;
}

// Normalize the expense
final expense = buildNormalizedExpenseFromSlots(
  amount: 300.0,
  payerSlots: payerSlots,
  slots: participantSlots,
  // ... other params
);

// expense.payerContributionsByMemberId now contains:
// { 'alice_id': MoneyMinor(20000, 'INR'), 'bob_id': MoneyMinor(10000, 'INR') }
```
