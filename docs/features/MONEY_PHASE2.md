# Phase 2 Money Invariant Enforcement Plan

**Purpose:** Transition from legacy balance computation to canonical behavior  
**Status:** **EXECUTED**

---

> **DEPLOYMENT GATE**
> 
> Before deploying MONEY_PHASE2, Firestore must be verified to contain no expenses
> with empty or invalid `paidById`. If such data exists, it must be backfilled or
> quarantined. This is a deployment responsibility, not app logic.

---

## Execution Summary

**Completed:**
- Removed `computeNetBalancesLegacy()` and `computeDebtsLegacy()` from `SettlementEngine`
- Removed `_BalanceEntryDouble` helper class
- Updated `CycleRepository.calculateBalances()` to use `computeNetBalancesAsDouble()`
- Added 12 Phase 2 tests covering I7 invariant enforcement, invalid amounts, and replay determinism
- Added deployment gate comments to `settlement_engine.dart`

**Invariant I7 now enforced:** An expense with no valid payer produces no credit.

---

## 1. Final State

### Canonical Implementation
- `SettlementEngine.computeNetBalances()` — strict validation, no fallbacks
- `SettlementEngine.computeDebts()` — uses strict balances
- `SettlementEngine.computeNetBalancesAsDouble()` — UI-facing wrapper

### Legacy Adapter
- **DELETED**: `computeNetBalancesLegacy()` — removed
- **DELETED**: `computeDebtsLegacy()` — removed

### Behavior Differences (Legacy vs Canonical)

| Behavior | Legacy | Canonical |
|----------|--------|-----------|
| Empty `paidById` | Falls back to `_currentUserId` | Skips credit (no fallback) |
| Amount ≤ 0 | Processed | Skipped |
| Amount NaN/Infinite | Processed (corrupts balance) | Skipped |
| Split amount NaN/Infinite | Processed (corrupts balance) | Skipped |
| participantIds not in members | Processed (may not debit) | Filtered to known members only |
| Return type | Mutable `Map` | Immutable `Map` |

---

## 2. Legacy Behaviors: Keep, Tighten, or Remove

### REMOVE: Empty `paidById` Fallback

**Legacy:** Falls back to `_currentUserId`  
**Decision:** Remove

**Rationale:**
- Data layer already normalizes `paidById` at write time (`addExpense` line 930, `updateExpense` line 1066)
- All UI entry points set `paidById` explicitly (`expense_input.dart` line 69, `edit_expense.dart` line 157)
- Fallback in read path masks data quality issues
- `_currentUserId` at read time may differ from actual payer

**Migration Risk:** Low. Grep shows no code path creates expenses without `paidById`.

**Verification Step:** Before removing, query Firestore for any expenses with empty `payerId` field. If found, backfill or decide on handling.

---

### REMOVE: Processing of Invalid Amounts (≤ 0, NaN, Infinite)

**Legacy:** No validation; processes all values  
**Decision:** Remove (adopt canonical skip behavior)

**Rationale:**
- `addExpense()` validates via `validateExpenseAmount()` before write (line 920-921)
- Invalid amounts should not exist in production data
- Processing NaN/Infinite corrupts entire balance calculation silently
- Skipping is safer than corrupting

**Migration Risk:** None. Write path already enforces valid amounts.

**Verification Step:** None needed — write path guarantees valid data.

---

### REMOVE: Processing of Invalid Split Amounts (NaN, Infinite)

**Legacy:** No validation; processes all values  
**Decision:** Remove (adopt canonical skip behavior)

**Rationale:**
- Split amounts are computed from valid expense amounts
- NaN/Infinite splits indicate logic error, not user data
- Skipping prevents corruption propagation

**Migration Risk:** None.

---

### KEEP (for now): participantIds Not Filtered to Known Members

**Legacy:** Uses `net.containsKey(entry.key)` check (skips unknown, but still iterates)  
**Canonical:** Pre-filters to `ids.contains(id)`

**Decision:** Keep canonical behavior (pre-filter)

**Rationale:**
- No functional difference — both skip unknown members
- Canonical is slightly more efficient (filter once vs check per-expense)
- Canonical is more explicit about intent

**Migration Risk:** None — behavioral equivalent.

---

## 3. Invariants to Enforce at Runtime (Post-Phase 2)

### Already Enforced by Canonical (No Change Needed)

| # | Invariant | Enforcement |
|---|-----------|-------------|
| I1 | Sum of net balances = 0 | By construction |
| I2 | No balances for pending members (`p_` prefix) | Explicit filter |
| I3 | Invalid amounts skipped (≤ 0, NaN, Infinite) | Explicit check |
| I4 | Invalid split amounts skipped (NaN, Infinite) | Explicit check |
| I5 | All members appear in output | Initialize all to 0.0 |
| I6 | Debt amounts always positive (≥ tolerance) | Threshold check |

### New Invariant to Add: I7

| # | Invariant | Description |
|---|-----------|-------------|
| **I7** | Empty `paidById` skips credit | No fallback; expense with no payer yields no credit |

**Implementation:** Already in canonical. Removing legacy adapter enables this.

### Invariants NOT to Enforce in Phase 2

| # | Invariant | Reason to Defer |
|---|-----------|-----------------|
| A1 | `splitAmountsById` sums to `expense.amount` | Requires data migration / breaking change; defer to Phase 3 |
| A2 | `paidById` is a valid member | Current behavior (skip credit) is acceptable; adding runtime error would break existing flows |
| A3 | All `participantIds` are valid members | Current behavior (filter) is acceptable |

---

## 4. Changes to `computeNetBalances` After Legacy Removal

### Current Canonical Implementation (No Changes Needed)

```dart
static Map<String, double> computeNetBalances(List<Expense> expenses, List<Member> members) {
  final net = _buildNetBalances(expenses, members);
  return Map.unmodifiable(Map.from(net));
}
```

The `_buildNetBalances` function already implements all desired behaviors:
- Skips expenses with `amount <= 0 || isNaN || isInfinite`
- Empty `paidById` → sets `payerId = ''` → skips credit (not in `ids`)
- Filters `participantIds` to known members
- Skips NaN/Infinite split amounts
- Returns immutable map

### What Changes After Phase 2

**Code changes:** None to `computeNetBalances` or `_buildNetBalances`.

**Changes to callers:**
1. `CycleRepository.calculateBalances()` — remove `Legacy` suffix from function call
2. Delete `computeNetBalancesLegacy()` from `SettlementEngine`

---

## 5. Test Plan

### Tests to Keep Unchanged

All existing tests in `settlement_engine_test.dart` remain valid. They test canonical behavior which does not change.

### Tests to Add

| Test | Input | Expected | Validates |
|------|-------|----------|-----------|
| **Empty paidById skips credit** | Expense with `paidById: ''` | Only debits applied, no credits | I7 |
| **Zero amount expense skipped** | Expense with `amount: 0` | No effect on balances | I3 |
| **Negative amount expense skipped** | Expense with `amount: -100` | No effect on balances | I3 |
| **NaN amount expense skipped** | Expense with `amount: double.nan` | No effect on balances | I3 |
| **Infinite amount expense skipped** | Expense with `amount: double.infinity` | No effect on balances | I3 |
| **NaN split amount skipped** | `splitAmountsById: {'u1': double.nan}` | That split ignored | I4 |
| **Unknown payer loses credit** | `paidById: 'unknown'` | No credit given | A2 documented |
| **Unknown participant filtered** | `participantIds: ['u1', 'unknown']` | Only u1 debited | A3 documented |

### Tests to Update

None. Existing tests validate canonical behavior which is unchanged.

### Tests to Delete

None. Golden tests in `MONEY_TESTS.md` are behavioral specifications, not implementation tests.

---

## 6. Implementation Checklist

### Pre-Implementation Verification

- [ ] Query Firestore for expenses with empty `payerId` — confirm none exist
- [ ] Confirm all write paths set `paidById` explicitly
- [ ] Review `MONEY_TESTS.md` test cases A12, A13, A14 for alignment

### Phase 2 Implementation Steps

1. **Add new tests** for edge cases (empty paidById, invalid amounts)
2. **Update `calculateBalances()`** to call `computeNetBalances` directly
   ```dart
   Map<String, double> calculateBalances(String groupId) {
     final cycle = getActiveCycle(groupId);
     final members = getMembersForGroup(groupId);
     return Map.from(SettlementEngine.computeNetBalances(cycle.expenses, members));
   }
   ```
3. **Remove `computeNetBalancesLegacy()`** from `SettlementEngine`
4. **Run full test suite** — verify no regressions
5. **Manual app verification** — check Decision Clarity card, Balances section

### Post-Implementation

- [ ] Update `MONEY_CANONICALIZATION.md` to reflect completed Phase 2
- [ ] Document the invariant changes in `STABILIZATION.md` if needed

---

## 7. Risk Assessment

### Low Risk

| Change | Risk | Mitigation |
|--------|------|------------|
| Remove invalid amount processing | None | Write path already validates |
| Remove invalid split processing | None | Computed from valid amounts |
| Switch to immutable return | None | Callers already treat as read-only |

### Medium Risk

| Change | Risk | Mitigation |
|--------|------|------------|
| Remove `paidById` fallback | Old data with empty `paidById` | Pre-check Firestore before deploying |

### No-Go Criteria

Do NOT proceed with Phase 2 if:
- Firestore query finds expenses with empty `payerId` field
- Any write path is discovered that doesn't set `paidById`

---

## 8. Decision Summary

| Behavior | Decision | Risk | Action |
|----------|----------|------|--------|
| Empty `paidById` fallback | Remove | Medium | Verify Firestore first |
| Invalid amount processing | Remove | None | Proceed |
| Invalid split processing | Remove | None | Proceed |
| participantIds filtering | Keep canonical | None | Already done |
| Return immutable map | Keep canonical | None | Already done |

---

## 9. Approval Checklist

Before executing Phase 2:

- [ ] This document reviewed and approved
- [ ] Firestore verification completed (no empty `payerId` expenses)
- [ ] New tests written and passing
- [ ] Team notified of behavioral changes

---

## Appendix: Related Documentation

- [MONEY_BALANCE_LOGIC.md](MONEY_BALANCE_LOGIC.md) — Pure function specifications
- [MONEY_TESTS.md](MONEY_TESTS.md) — Golden test cases
- [MONEY_CANONICALIZATION.md](MONEY_CANONICALIZATION.md) — Canonicalization plan
- [STABILIZATION.md](../STABILIZATION.md) — Overall stabilization analysis
