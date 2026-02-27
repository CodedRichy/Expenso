# Balance Computation Isolation

**Purpose:** Formal specification of money-critical balance computation logic  
**Scope:** Isolation and specification only — no code changes proposed

---

## 1. Where Balance Computation Currently Happens

### Primary Location

**File:** `lib/utils/settlement_engine.dart`

| Function | Purpose |
|----------|---------|
| `SettlementEngine.computeNetBalances()` | Compute per-member net balance (credit/debt) |
| `SettlementEngine._buildNetBalances()` | Internal implementation of balance calculation |
| `SettlementEngine.computeDebts()` | Derive minimal debt transfers from net balances |
| `SettlementEngine.computePaymentRoutes()` | Derive minimal payment instructions from net balances (greedy algorithm) |
| `SettlementEngine.getPaymentsForMember()` | Filter payment routes to those a member must make |
| `SettlementEngine.getPaymentsToMember()` | Filter payment routes to those a member will receive |

### Secondary Location (Repository Wrappers)

**File:** `lib/repositories/cycle_repository.dart`

| Function | Purpose |
|----------|---------|
| `calculateBalances()` | Wrapper that fetches cycle + members, then computes balances |
| `getSettlementInstructions()` | Human-readable "X owes Y ₹Z" strings |
| `getSettlementTransfersForCurrentUser()` | Current user's specific payment obligations |

### Usage Sites

| Location | Function Used | Purpose |
|----------|--------------|---------|
| `group_detail.dart` | `computeNetBalances()` | Decision Clarity card ("Your Status") |
| `group_detail.dart` | `computeDebts()` | Balances section (who owes whom) |
| `group_members.dart` | `computeNetBalances()` | Block removal of members with non-zero balance |
| `settlement_confirmation.dart` | `getSettlementInstructions()` | Settlement dialog |
| `settlement_confirmation.dart` | `getSettlementTransfersForCurrentUser()` | Razorpay payment amount |

---

## 2. Current Implementation Analysis

### Inputs to Balance Logic

```
computeNetBalances(expenses, members) → Map<String, double>
```

| Input | Type | Description |
|-------|------|-------------|
| `expenses` | `List<Expense>` | All expenses in the active cycle |
| `members` | `List<Member>` | All group members (excluding pending) |

**Expense fields used:**
- `amount` — Total expense amount
- `paidById` — Who paid (UID)
- `participantIds` — Who owes (list of UIDs)
- `splitAmountsById` — Per-person amounts (optional override)

**Member fields used:**
- `id` — Member UID (filtered to exclude `p_` prefix pending members)

### Outputs Produced

| Output | Type | Description |
|--------|------|-------------|
| Net balances | `Map<String, double>` | UID → net amount (positive = credit, negative = debt) |
| Debts | `List<Debt>` | Minimal transfers: `(fromId, toId, amount)` |

### Assumptions the Logic Relies On

| # | Assumption | Enforced? |
|---|-----------|-----------|
| 1 | `expense.amount > 0` | Yes — skips invalid amounts |
| 2 | `expense.amount` is finite | Yes — skips NaN/Infinite |
| 3 | `splitAmountsById` values are finite | Yes — skips NaN/Infinite |
| 4 | `splitAmountsById` sums to `amount` | **No** — assumed, not validated |
| 5 | `paidById` is a valid member UID | Partial — skips if not in members |
| 6 | `participantIds` are valid member UIDs | Partial — filters to known members |
| 7 | Empty `participantIds` means "all members" | Yes — explicit fallback |
| 8 | Pending members (IDs starting with `p_`) are excluded | Yes — explicit filter |
| 9 | Sum of all net balances equals zero | Implicit — by construction |

---

## 3. Pure Function Specification

### Function 1: `computeNetBalances`

**Purpose:** Calculate the net financial position of each member.

```
computeNetBalances : (List<Expense>, List<Member>) → Map<MemberId, Balance>

where:
  MemberId = String (UID, not starting with 'p_')
  Balance  = double (positive = credit, negative = debt)
```

**Signature:**

```dart
Map<String, double> computeNetBalances(
  List<Expense> expenses,
  List<Member> members,
)
```

**Input Parameters:**

| Parameter | Type | Constraints |
|-----------|------|-------------|
| `expenses` | `List<Expense>` | May be empty. Invalid expenses are skipped. |
| `members` | `List<Member>` | Members with `id` starting with `p_` are excluded. |

**Output Shape:**

```dart
Map<String, double>
// Keys: Member UIDs (all members present, even if balance is 0)
// Values: Net balance (positive = owed to them, negative = they owe)
```

**Computation Rules:**

1. Initialize `net[memberId] = 0.0` for each non-pending member
2. For each expense where `amount > 0` and `amount` is finite:
   - **Credit the payer:** `net[paidById] += amount`
   - **Debit the participants:**
     - If `splitAmountsById` exists: `net[uid] -= splitAmountsById[uid]`
     - Else: `net[uid] -= amount / participantCount` for each participant
3. Return immutable map

**Side Effects:** None. Pure function.

---

### Function 2: `computeDebts`

**Purpose:** Derive minimal payment transfers to settle all balances.

```
computeDebts : (List<Expense>, List<Member>) → List<Debt>

where:
  Debt = { fromId: MemberId, toId: MemberId, amount: double }
```

**Signature:**

```dart
List<Debt> computeDebts(
  List<Expense> expenses,
  List<Member> members,
)
```

**Input Parameters:**

| Parameter | Type | Constraints |
|-----------|------|-------------|
| `expenses` | `List<Expense>` | Same as `computeNetBalances` |
| `members` | `List<Member>` | Same as `computeNetBalances` |

**Output Shape:**

```dart
List<Debt>
// Each Debt: { fromId, toId, amount }
// fromId: debtor (negative balance)
// toId: creditor (positive balance)
// amount: transfer amount (always positive)
```

**Algorithm:**

1. Compute net balances via `computeNetBalances`
2. Separate into debtors (balance < -ε) and creditors (balance > ε), where ε = 0.01
3. Sort both lists by amount descending (largest first)
4. Greedy matching:
   - Match largest debtor to largest creditor
   - Transfer `min(debtor.amount, creditor.amount)`
   - Reduce both amounts
   - Advance pointer when amount < ε
5. Return list of Debt objects

**Side Effects:** None. Pure function.

**Algorithm Properties:**
- Minimizes number of transactions (greedy)
- Does not minimize total transferred (that's guaranteed equal regardless)
- Deterministic given same input order

---

### Function 3: `computeSettlementInstructions`

**Purpose:** Generate human-readable settlement instructions.

```
computeSettlementInstructions : (Map<MemberId, Balance>, NameResolver) → List<String>

where:
  NameResolver = MemberId → String
```

**Signature (conceptual pure form):**

```dart
List<String> computeSettlementInstructions(
  Map<String, double> balances,
  String Function(String) getDisplayName,
)
```

**Output Shape:**

```dart
List<String>
// Each string: "{DebtorName} owes {CreditorName} ₹{Amount}"
```

**Notes:** Currently implemented in `CycleRepository.getSettlementInstructions()` with side-effect (accesses `_currentUserId`, `getMemberDisplayNameById`). The pure form would accept these as parameters.

---

### Function 4: `computeUserTransfers`

**Purpose:** Filter debts to only those where a specific user is the debtor.

```
computeUserTransfers : (List<Debt>, MemberId) → List<Debt>
```

**Signature (conceptual pure form):**

```dart
List<Debt> computeUserTransfers(
  List<Debt> debts,
  String userId,
)
```

**Output Shape:**

```dart
List<Debt>
// Only debts where fromId == userId
```

**Notes:** Currently embedded in `CycleRepository.getSettlementTransfersForCurrentUser()` with side-effects (accesses `_currentUserId`, phone lookups).

---

## 4. Invariants This Logic MUST Uphold

### Fundamental Invariants

| # | Invariant | Description | Status |
|---|-----------|-------------|--------|
| **I1** | Sum of net balances equals zero | Total credits must equal total debts | ✅ Enforced by construction |
| **I2** | No balance for pending members | Members with `p_` prefix are excluded | ✅ Enforced |
| **I3** | Invalid expenses are skipped | Amount ≤ 0, NaN, or Infinite are ignored | ✅ Enforced |
| **I4** | Invalid split amounts are skipped | NaN or Infinite splits are ignored | ✅ Enforced |
| **I5** | All members appear in output | Even if balance is 0 | ✅ Enforced |
| **I6** | Debt amounts are positive | Never negative or zero | ✅ Enforced (≥ 0.01 threshold) |

### Assumed but Not Enforced

| # | Invariant | Status / Risk |
|---|-----------|----------------|
| **A1** | `splitAmountsById` sums to `expense.amount` | ✅ **Validated at read:** expense skipped if splits missing, empty, or sum not within 0.01 of amount. See G3 in docs/internal/V4_TESTING_ISSUES.md. |
| **A2** | `paidById` is a valid member | Payment credit is lost (skipped) |
| **A3** | All `participantIds` are valid members | Some debits are lost (filtered out) |

### Tolerance Constant

```dart
static const double _tolerance = 0.01;
```

- Amounts below ₹0.01 are treated as zero
- Prevents floating-point artifacts from creating false debts
- Applied consistently in debtor/creditor classification and matching loop

---

## 5. Test Coverage Summary

**File:** `test/settlement_engine_test.dart`

| Test Case | Covered |
|-----------|---------|
| Even split: one pays, two share | ✅ |
| Empty participantIds uses all members | ✅ |
| Exact split: amounts match total | ✅ |
| Multiple expenses net correctly | ✅ |
| Single debtor owes single creditor | ✅ |
| Balanced expenses yield no debts | ✅ |
| Null/empty splitAmountsById → expense skipped | ✅ |
| Splits not summing to total → expense skipped | ✅ |
| Splits within 0.01 tolerance accepted | ✅ |
| Invalid expense skipped, other expenses still count | ✅ |
| Empty expense list → zero balances | ✅ |
| Empty member list → empty net | ✅ |

**Not Covered (lower priority):**

- Payer not in member list (credit dropped; nets sum ≠ 0)
- Participant not in member list (debit dropped)
- Three or more members with complex debt graph (some coverage in computePaymentRoutes)
- Large numbers (overflow potential)

---

## 6. Canonicalization Status

**✅ RESOLVED (Phase 2 executed)**

Balance computation is now unified. `CycleRepository.calculateBalances()` delegates to `SettlementEngine.computeNetBalancesAsDouble()`.

| Location | Role |
|----------|------|
| `SettlementEngine.computeNetBalances()` | Canonical implementation (strict validation) |
| `CycleRepository.calculateBalances()` | Thin wrapper that delegates to SettlementEngine |

See [MONEY_PHASE2.md](MONEY_PHASE2.md) for migration details and [MONEY_CANONICALIZATION.md](MONEY_CANONICALIZATION.md) for the delegation plan.

---

## 7. Recommendations for Testing

When adding tests to this logic, prioritize:

1. **Edge cases for Invariant A1:** What happens when splits don't sum to amount?
2. **Three-member scenarios:** A owes B, B owes C — verify debt minimization
3. **Empty inputs:** Zero expenses, zero members
4. **Boundary amounts:** ₹0.00, ₹0.01, ₹0.02, ₹0.009 (below tolerance)
5. **Large cycles:** 50+ expenses, 10+ members

No code changes are proposed. This is a specification for future test expansion.

---

## Summary

The balance computation in Expenso is implemented as pure functions in `SettlementEngine`. The core logic is sound and tested for basic cases. Remaining considerations:

1. **Assumed invariant A1** — Split amounts summing to total are now validated at read: expenses with missing/empty splits or sum not within 0.01 of amount are skipped (see G3 in docs/internal/V4_TESTING_ISSUES.md).
2. **Test gaps** — Remaining lower-priority gaps: payer/participant not in member list, large cycles, overflow. See §5 Not Covered.

This specification isolates the money-critical path for inspection.
