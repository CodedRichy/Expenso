# Canonical Money Computation Plan

**Purpose:** Unify duplicated balance computation logic into a single canonical implementation  
**Scope:** Delegation plan only — no implementation changes yet

---

## 1. Canonical Implementation Identification

### Primary Canonical Module

**Location:** `lib/utils/settlement_engine.dart`

**Rationale:**
- Pure functions with no side effects
- No dependencies on repository state
- Explicit input/output contract
- More defensive validation (checks for NaN, Infinite, ≤0)
- Returns immutable map
- Existing unit test coverage

### Canonical Functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `computeNetBalances` | `(List<Expense>, List<Member>) → Map<String, double>` | Per-member net balance |
| `computeDebts` | `(List<Expense>, List<Member>) → List<Debt>` | Minimal debt transfers |

### Supporting Types

| Type | Location | Definition |
|------|----------|------------|
| `Debt` | `settlement_engine.dart` | `{fromId: String, toId: String, amount: double}` |
| `_BalanceEntry` | `settlement_engine.dart` (private) | Internal helper for debt matching |

---

## 2. Canonical API Specification

### Function: `computeNetBalances`

```dart
/// Computes net balance per member from expenses.
/// 
/// Returns: Map<memberId, balance>
///   - Positive balance = credit (owed to this member)
///   - Negative balance = debt (this member owes)
///   - All non-pending members are present in output
///   - Sum of all balances equals zero (invariant I1)
/// 
/// Behavior:
///   - Skips expenses with amount ≤ 0, NaN, or Infinite
///   - Skips split amounts that are NaN or Infinite
///   - Excludes pending members (id starting with 'p_')
///   - Empty participantIds falls back to all members
///   - Empty paidById skips credit (no fallback)
static Map<String, double> computeNetBalances(
  List<Expense> expenses,
  List<Member> members,
)
```

**Input Types:**

```dart
class Expense {
  final String id;
  final double amount;
  final String paidById;
  final List<String> participantIds;
  final Map<String, double>? splitAmountsById;
  // ... other fields ignored by this function
}

class Member {
  final String id;
  // ... other fields ignored by this function
}
```

**Output Type:**

```dart
Map<String, double>  // Immutable, unmodifiable
```

---

### Function: `computeDebts`

```dart
/// Derives minimal payment transfers to settle all balances.
/// 
/// Returns: List<Debt> where each Debt is a transfer instruction
///   - fromId: debtor (member with negative balance)
///   - toId: creditor (member with positive balance)
///   - amount: positive value (always ≥ 0.01)
/// 
/// Algorithm:
///   - Greedy matching: largest debtor to largest creditor
///   - Minimizes number of transactions
///   - Deterministic given same input order
/// 
/// Tolerance: Amounts below 0.01 are treated as zero
static List<Debt> computeDebts(
  List<Expense> expenses,
  List<Member> members,
)
```

**Output Type:**

```dart
class Debt {
  final String fromId;
  final String toId;
  final double amount;
}
```

---

### Constant: Tolerance

```dart
static const double tolerance = 0.01;
```

Currently private (`_tolerance`). Should remain private — callers should not depend on this value.

---

## 3. Non-Canonical Call Sites

### Site 1: `CycleRepository.calculateBalances()`

**Location:** `lib/repositories/cycle_repository.dart:1129-1157`

**Current Behavior:**
```dart
Map<String, double> calculateBalances(String groupId) {
  final cycle = getActiveCycle(groupId);
  final members = getMembersForGroup(groupId);
  // ... inline balance computation (28 lines)
}
```

**Differences from Canonical:**

| Aspect | CycleRepository | SettlementEngine |
|--------|-----------------|------------------|
| Empty `paidById` | Falls back to `_currentUserId` | Skips credit (empty string) |
| Invalid amount check | None | Skips ≤0, NaN, Infinite |
| Invalid split check | None | Skips NaN, Infinite |
| Participant filter | No validation | Filters to known members |
| Return type | Mutable map | Immutable map |

**Delegation Plan:**

```dart
Map<String, double> calculateBalances(String groupId) {
  final cycle = getActiveCycle(groupId);
  final members = getMembersForGroup(groupId);
  return SettlementEngine.computeNetBalances(cycle.expenses, members);
}
```

**Logic to Delete:** Lines 1132-1156 (entire inline implementation)

**Logic to Retain:** Lines 1130-1131 (data fetching)

**Behavior Change:** Empty `paidById` will no longer fall back to `_currentUserId`. This is a **correction** — the canonical behavior is correct per the golden tests.

---

### Site 2: `CycleRepository.getSettlementInstructions()`

**Location:** `lib/repositories/cycle_repository.dart:1159-1187`

**Current Behavior:**
```dart
List<String> getSettlementInstructions(String groupId) {
  final balances = calculateBalances(groupId);
  // ... inline debt matching (26 lines)
  // ... inline string formatting
}
```

**Delegation Plan:**

```dart
List<String> getSettlementInstructions(String groupId) {
  final cycle = getActiveCycle(groupId);
  final members = getMembersForGroup(groupId);
  final debts = SettlementEngine.computeDebts(cycle.expenses, members);
  return debts.map((d) => 
    '${getMemberDisplayNameById(d.fromId)} owes ${getMemberDisplayNameById(d.toId)} ₹${d.amount.round()}'
  ).toList();
}
```

**Logic to Delete:** Lines 1161-1185 (inline debt matching algorithm)

**Logic to Retain:** 
- Line 1160: Data fetching (modify to use computeDebts)
- String formatting with `getMemberDisplayNameById` (this is presentation, not computation)

---

### Site 3: `CycleRepository.getSettlementTransfersForCurrentUser()`

**Location:** `lib/repositories/cycle_repository.dart:1191-1223`

**Current Behavior:**
```dart
List<SettlementTransfer> getSettlementTransfersForCurrentUser(String groupId) {
  final balances = calculateBalances(groupId);
  // ... inline debt matching (30 lines)
  // ... filter to current user
  // ... build SettlementTransfer objects
}
```

**Delegation Plan:**

```dart
List<SettlementTransfer> getSettlementTransfersForCurrentUser(String groupId) {
  final cycle = getActiveCycle(groupId);
  final members = getMembersForGroup(groupId);
  final debts = SettlementEngine.computeDebts(cycle.expenses, members);
  return debts
    .where((d) => d.fromId == _currentUserId)
    .map((d) => SettlementTransfer(
      creditorPhone: _phoneForUid(d.toId),
      creditorDisplayName: getMemberDisplayNameById(d.toId),
      amount: d.amount,
    ))
    .toList();
}
```

**Logic to Delete:** Lines 1193-1221 (inline debt matching and filtering)

**Logic to Retain:**
- `_currentUserId` access (filtering)
- `_phoneForUid` call (phone lookup)
- `getMemberDisplayNameById` call (display name lookup)
- `SettlementTransfer` construction (model mapping)

---

### Site 4: `group_detail.dart` — Decision Clarity Card

**Location:** `lib/screens/group_detail.dart:742`

**Current Behavior:**
```dart
final netBalances = SettlementEngine.computeNetBalances(expenses, members);
```

**Status:** ✅ Already uses canonical function

**Delegation Plan:** No change needed

---

### Site 5: `group_detail.dart` — Balances Section

**Location:** `lib/screens/group_detail.dart:408`

**Current Behavior:**
```dart
final debts = SettlementEngine.computeDebts(expenses, members);
```

**Status:** ✅ Already uses canonical function

**Delegation Plan:** No change needed

---

### Site 6: `group_detail.dart` — Settle Dialog

**Location:** `lib/screens/group_detail.dart:616`

**Current Behavior:**
```dart
final instructions = repo.getSettlementInstructions(groupId);
```

**Status:** Uses repository wrapper (Site 2). Will automatically use canonical after Site 2 delegation.

**Delegation Plan:** No change needed at this call site

---

### Site 7: `group_detail.dart` — Pay via UPI

**Location:** `lib/screens/group_detail.dart:321`

**Current Behavior:**
```dart
final transfers = repo.getSettlementTransfersForCurrentUser(groupId);
```

**Status:** Uses repository wrapper (Site 3). Will automatically use canonical after Site 3 delegation.

**Delegation Plan:** No change needed at this call site

---

### Site 8: `group_members.dart` — Removal Guard

**Location:** `lib/screens/group_members.dart:38`

**Current Behavior:**
```dart
final netBalances = SettlementEngine.computeNetBalances(
  activeCycle.expenses,
  listMembers,
);
```

**Status:** ✅ Already uses canonical function

**Delegation Plan:** No change needed

---

### Site 9: `settlement_confirmation.dart` — Payment Amount

**Location:** `lib/screens/settlement_confirmation.dart:114`

**Current Behavior:**
```dart
final transfers = repo.getSettlementTransfersForCurrentUser(group.id);
```

**Status:** Uses repository wrapper (Site 3). Will automatically use canonical after Site 3 delegation.

**Delegation Plan:** No change needed at this call site

---

### Site 10: `settlement_confirmation.dart` — Pending Settlements

**Location:** `lib/screens/settlement_confirmation.dart:355`

**Current Behavior:**
```dart
final instructions = CycleRepository.instance.getSettlementInstructions(groupId);
```

**Status:** Uses repository wrapper (Site 2). Will automatically use canonical after Site 2 delegation.

**Delegation Plan:** No change needed at this call site

---

## 4. Duplicated Helper Classes

### `_BalanceEntry` (duplicated)

**Location 1:** `lib/utils/settlement_engine.dart:103-107`  
**Location 2:** `lib/repositories/cycle_repository.dart:1307-1311`

Both are identical:
```dart
class _BalanceEntry {
  final String id;
  double amount;
  _BalanceEntry(this.id, this.amount);
}
```

**Plan:** After delegation, the repository copy will be unused and should be deleted.

---

## 5. Summary: Changes Required

### Files to Modify

| File | Action |
|------|--------|
| `cycle_repository.dart` | Delegate 3 functions to SettlementEngine |
| `settlement_engine.dart` | No changes (canonical) |
| `group_detail.dart` | No changes (already canonical) |
| `group_members.dart` | No changes (already canonical) |
| `settlement_confirmation.dart` | No changes (uses wrappers) |

### Code to Delete

| Location | Lines | Description |
|----------|-------|-------------|
| `cycle_repository.dart` | 1132-1156 | Inline balance computation in `calculateBalances` |
| `cycle_repository.dart` | 1161-1185 | Inline debt matching in `getSettlementInstructions` |
| `cycle_repository.dart` | 1193-1221 | Inline debt matching in `getSettlementTransfersForCurrentUser` |
| `cycle_repository.dart` | 1307-1311 | Duplicate `_BalanceEntry` class |

**Total lines to delete:** ~75 lines

### Code to Add

| Location | Lines | Description |
|----------|-------|-------------|
| `cycle_repository.dart` | ~3 | Import statement (if not present) |
| `cycle_repository.dart` | ~15 | Delegation calls in 3 functions |

**Total lines to add:** ~18 lines

**Net reduction:** ~57 lines

---

## 6. Behavior Changes (Intentional)

### Change 1: Empty `paidById` Handling

**Before (CycleRepository):** Falls back to `_currentUserId`  
**After (SettlementEngine):** Skips credit (no payer = no credit)

**Impact:** If an expense has empty `paidById`, it will no longer credit the current user. This is the correct behavior per the data model — `paidById` should always be set.

**Risk:** Low. Expenses are always created with `paidById` set.

### Change 2: Validation Strictness

**Before (CycleRepository):** No validation of amount or splits  
**After (SettlementEngine):** Skips invalid amounts and splits

**Impact:** Invalid data (if any exists) will be skipped rather than causing incorrect calculations.

**Risk:** None. This is strictly safer.

---

## 7. Verification Plan

After delegation:

1. **Run existing tests:** `flutter test test/settlement_engine_test.dart`
2. **Add delegation tests:** Verify repository functions return same results as direct SettlementEngine calls
3. **Manual verification:** Check Decision Clarity card, Balances section, and Settlement flows in app
4. **Golden test validation:** All tests in MONEY_TESTS.md must pass

---

## 8. Execution Order

1. **Phase 1:** Delegate `calculateBalances()` → verify
2. **Phase 2:** Delegate `getSettlementInstructions()` → verify
3. **Phase 3:** Delegate `getSettlementTransfersForCurrentUser()` → verify
4. **Phase 4:** Delete unused `_BalanceEntry` in repository
5. **Phase 5:** Run full test suite
6. **Phase 6:** Manual app verification

Each phase should be a separate commit for easy rollback.

---

## Appendix: Current Call Graph

```
UI Layer
├── group_detail.dart
│   ├── [742] SettlementEngine.computeNetBalances() ─────────► CANONICAL
│   ├── [408] SettlementEngine.computeDebts() ───────────────► CANONICAL
│   ├── [321] repo.getSettlementTransfersForCurrentUser() ──► Site 3
│   └── [616] repo.getSettlementInstructions() ─────────────► Site 2
├── group_members.dart
│   └── [38] SettlementEngine.computeNetBalances() ──────────► CANONICAL
└── settlement_confirmation.dart
    ├── [114] repo.getSettlementTransfersForCurrentUser() ──► Site 3
    └── [355] repo.getSettlementInstructions() ─────────────► Site 2

Repository Layer
├── calculateBalances() ─────────────────────────────────────► DUPLICATE (Site 1)
│   └── [inline computation]
├── getSettlementInstructions() ─────────────────────────────► DUPLICATE (Site 2)
│   └── calculateBalances() + [inline debt matching]
└── getSettlementTransfersForCurrentUser() ──────────────────► DUPLICATE (Site 3)
    └── calculateBalances() + [inline debt matching + filter]

Canonical Layer
└── SettlementEngine
    ├── computeNetBalances() ────────────────────────────────► SOURCE OF TRUTH
    └── computeDebts() ──────────────────────────────────────► SOURCE OF TRUTH
```

After canonicalization:

```
UI Layer
├── group_detail.dart
│   ├── [742] SettlementEngine.computeNetBalances() ─────────► CANONICAL
│   ├── [408] SettlementEngine.computeDebts() ───────────────► CANONICAL
│   ├── [321] repo.getSettlementTransfersForCurrentUser() ──► delegates
│   └── [616] repo.getSettlementInstructions() ─────────────► delegates
├── group_members.dart
│   └── [38] SettlementEngine.computeNetBalances() ──────────► CANONICAL
└── settlement_confirmation.dart
    ├── [114] repo.getSettlementTransfersForCurrentUser() ──► delegates
    └── [355] repo.getSettlementInstructions() ─────────────► delegates

Repository Layer (thin wrappers)
├── calculateBalances() ──► SettlementEngine.computeNetBalances()
├── getSettlementInstructions() ──► SettlementEngine.computeDebts() + formatting
└── getSettlementTransfersForCurrentUser() ──► SettlementEngine.computeDebts() + filter + mapping

Canonical Layer
└── SettlementEngine
    ├── computeNetBalances() ────────────────────────────────► SINGLE SOURCE OF TRUTH
    └── computeDebts() ──────────────────────────────────────► SINGLE SOURCE OF TRUTH
```
