# Expenso — Portfolio & Interview Guide

---

## One-Liner (Resume)

> **Ledger-based group expense system with replay-safe accounting, append-only edits, and zero-sum invariant enforcement.**

---

## Resume Bullet Points

Use 6–8 of these depending on space:

- Designed a **ledger-first accounting system** enforcing zero-sum invariants at construction time, eliminating silent money creation or loss

- Implemented **append-only expense edits** via compensation events—edits negate the original and append a replacement, preserving full audit history

- Eliminated **floating-point currency errors** using integer minor units (paise, cents) with ISO-4217 currency metadata for multi-currency support

- Built **replay-safe balance computation** that derives balances from stored deltas only, immune to group membership changes or historical data corruption

- Added **lifecycle guards** preventing illegal state transitions (edit-after-delete, double-delete) with explicit error types

- Decoupled **UI workflow from accounting core**—name resolution and confirmation happen in a separate layer; accounting only accepts validated, ID-based data

- Exposed **multi-payer expenses** without modifying accounting invariants—UI layer validates sum matches total before normalization

- Wrote **150+ invariant-based tests** covering zero-sum enforcement, replay determinism, currency handling, and lifecycle state machines

---

## Architecture Overview

### Accounting Pipeline

```
┌────────────────┐    ┌───────────────────┐    ┌─────────────┐    ┌──────────────────┐
│  Parsed Input  │ -> │ NormalizedExpense │ -> │ LedgerDelta │ -> │ SettlementEngine │
│  (names, UI)   │    │ (IDs, integers)   │    │ (credits/   │    │ (net balances,   │
│                │    │                   │    │  debits)    │    │  debt transfers) │
└────────────────┘    └───────────────────┘    └─────────────┘    └──────────────────┘
      UI layer              Normalization           Ledger              Settlement
    (untrusted)            boundary (pure)        (append-only)         (derived)
```

### Why Balances Are Never Stored

Balances are **derived on demand** from ledger deltas. Storing balances would require keeping them in sync with every write—a source of bugs and data races. Instead:

- Write path: append `LedgerDelta` entries only
- Read path: sum deltas at query time

This is the same model used by double-entry accounting systems.

### Why Edits Are Compensation-Based

In financial systems, history must be immutable for audit purposes. Expenso handles edits by:

1. **Negating** the original expense's deltas (compensation event)
2. **Appending** the new expense's deltas

Net effect: the original is zeroed out, and only the edited version affects balances. The full history remains intact.

```
Edit: ₹300 dinner → ₹200 dinner

Timeline:
  t1: +150 (Alice paid), -75 (Alice owes), -75 (Bob owes)   ← original
  t2: -150, +75, +75                                        ← negation
  t2: +100, -50, -50                                        ← replacement

Net at t2: +100, -50, -50 (only edited expense affects balances)
```

### Why Replay Safety Matters

An expense recorded in 2024 must produce **identical deltas** when recomputed in 2026. This requires:

- Storing explicit participant IDs (no "everyone" semantics)
- Storing exact amounts in minor units (no percentage-based recalculation)
- No dependence on current group membership

Replay safety enables audits, migrations, and debugging without fear of balance drift.

---

## Hard Engineering Problems Solved

### 1. Preventing Silent Money Creation

Every `NormalizedExpense` enforces at construction:
- `sum(payerContributions) == total` (exact)
- `sum(participantShares) == total` (exact)

Every `LedgerDelta` set is asserted to sum to zero. Violations throw immediately—no silent corruption.

### 2. Safe Deletion/Editing in Financial History

Expenses are immutable. Edits append compensation + replacement. Deletes append negation only. Lifecycle guards prevent:
- Editing a deleted expense
- Editing an already-superseded expense
- Double-deleting

State is derived from revision metadata, not stored flags.

### 3. Currency-Agnostic Integer Accounting

All money is stored as `MoneyMinor(amountMinor, currencyCode)`:
- INR: 2 decimal places (100.50 → 10050 paise)
- JPY: 0 decimal places (1000 → 1000)
- KWD: 3 decimal places (1.500 → 1500 fils)

Arithmetic uses integers. Currency mismatch throws at operation time. No tolerance logic—exact math only.

### 4. Deterministic Recomputation from Persisted Data

Balance computation uses **only** stored fields:
- `amountMinor` (not `amount`)
- `paidById` (not `paidByName`)
- `splitAmountsByIdMinor` (not percentages)

No current-state queries. No "default to everyone" fallbacks. Old expenses always produce identical results.

### 5. UI Decoupling from Accounting Correctness

The pipeline separates concerns:
- **UI layer**: name resolution, confirmation dialogs, slot editing
- **Normalization boundary**: converts names→IDs, doubles→integers, validates invariants
- **Accounting layer**: only accepts `NormalizedExpense`, rejects invalid data

A bug in name resolution cannot corrupt balances. The accounting layer is pure and testable in isolation.

---

## Interview Talking Points

### "Why not just update an expense in place?"

In financial systems, history is evidence. If you update in place, you lose the ability to audit what actually happened. Expenso uses compensation events: the original record stays intact, and a negation + replacement is appended. This preserves the full history while achieving the same end state.

### "Why store deltas instead of balances?"

Balances are derived data. Storing them means keeping two sources of truth in sync—a common bug source. Expenso stores only ledger deltas and computes balances on demand. This is the same principle behind event sourcing and double-entry accounting.

### "How do you handle edits safely?"

Edits are modeled as `negate(original) + append(replacement)`. Before generating deltas, a lifecycle guard checks if the expense is active. Editing a deleted or already-edited expense throws `ExpenseLifecycleError`. The guard derives state from revision metadata—no stored flags that could become stale.

### "How do you guarantee correctness over time?"

Three mechanisms: (1) Construction-time invariants—`NormalizedExpense` throws if sums don't match. (2) Runtime assertions—delta sums are asserted to equal zero. (3) Replay safety—balance computation uses only stored fields, so recomputing old expenses always produces identical results.

### "What breaks if invariants are violated?"

If payer contributions don't sum to total, money is created or destroyed. If delta sums aren't zero, balances drift over time. If lifecycle guards are bypassed, you can edit deleted expenses and resurrect negated amounts. The system is designed to fail loudly rather than silently corrupt data.

---

## Test Coverage Summary

| Category | Tests | What They Verify |
|----------|-------|------------------|
| Zero-sum enforcement | 12 | Delta sums, payer/participant invariants |
| Replay determinism | 6 | Same input → same deltas across time |
| Multi-currency | 8 | INR/JPY/KWD handling, currency mismatch rejection |
| Lifecycle guards | 10 | Edit/delete state transitions, error types |
| Compensation events | 10 | Edit/delete delta generation, audit preservation |
| Multi-payer | 16 | Validation, rounding, contribution storage |
| Phase 2 invariants | 12 | Empty payer rejection, invalid amount handling |

Total: **150+ tests** covering accounting correctness, not just UI behavior.

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/models/money_minor.dart` | Integer money type with currency metadata |
| `lib/models/normalized_expense.dart` | Immutable expense with construction-time invariants |
| `lib/utils/ledger_delta.dart` | Balance-affecting entries, replay-safe conversion |
| `lib/utils/settlement_engine.dart` | Net balance computation, debt minimization |
| `lib/utils/expense_revision.dart` | Lifecycle guards, compensation event generation |
| `lib/utils/normalization_workflow.dart` | UI→accounting bridge, validation |

---

## What This Project Demonstrates

- **Financial system design**: ledger-based accounting, not CRUD
- **Invariant enforcement**: fail-fast over silent corruption
- **Immutable data modeling**: append-only history with derived state
- **Separation of concerns**: UI layer cannot bypass accounting validation
- **Comprehensive testing**: behavior locks before implementation
