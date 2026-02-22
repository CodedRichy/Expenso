# Money Computation Golden Tests

**Purpose:** Deterministic test cases to lock down balance and debt computation behavior  
**Scope:** Behavior specification only — no implementation changes

---

## Overview

These test cases define the expected behavior of `computeNetBalances` and `computeDebts` before any refactoring. Each test specifies exact inputs and expected outputs. Implementations must pass all tests to be considered correct.

### Notation

- **Members:** `{id, phone, name}` — only `id` matters for computation
- **Expense:** `{id, amount, paidById, participantIds, splitAmountsById}`
- **NetBalance:** `{memberId: balance}` — positive = credit, negative = debt
- **Debt:** `{fromId, toId, amount}` — always positive amount

### Tolerance

All comparisons use ε = 0.01 (one paisa). Values within ε of zero are treated as zero.

---

## Test Suite A: `computeNetBalances`

### A1: Two Members, Even Split

**Scenario:** Alice pays ₹300, split evenly with Bob.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 300.00 | `u1` | `[u1, u2]` | `{u1: 150, u2: 150}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +150.00 |
| `u2` | -150.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- I5: All members present ✓

---

### A2: Two Members, Empty Participants (All Members Fallback)

**Scenario:** Bob pays ₹40, no participants specified (should split among all).

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 40.00 | `u2` | `[]` | `null` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | -20.00 |
| `u2` | +20.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- Empty participants fallback ✓

---

### A3: Two Members, Uneven (Exact) Split

**Scenario:** Alice pays ₹500, split 200/300.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 500.00 | `u1` | `[u1, u2]` | `{u1: 200, u2: 300}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +300.00 |
| `u2` | -300.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- Exact split respected ✓

---

### A4: Two Members, Multiple Expenses, Net to Zero

**Scenario:** Alice and Bob each pay ₹100, split evenly. Balances cancel out.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 100.00 | `u1` | `[u1, u2]` | `{u1: 50, u2: 50}` |
| `e2` | 100.00 | `u2` | `[u1, u2]` | `{u1: 50, u2: 50}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | 0.00 |
| `u2` | 0.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- Multiple expense aggregation ✓

---

### A5: Three Members, One Payer, Even Split

**Scenario:** Alice pays ₹900, split evenly among all three.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 900.00 | `u1` | `[u1, u2, u3]` | `{u1: 300, u2: 300, u3: 300}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +600.00 |
| `u2` | -300.00 |
| `u3` | -300.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- I5: All members present ✓
- Multi-member split ✓

---

### A6: Three Members, Uneven Split (60/30/10)

**Scenario:** Bob pays ₹1000, split 60% Alice, 30% Bob, 10% Carol.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 1000.00 | `u2` | `[u1, u2, u3]` | `{u1: 600, u2: 300, u3: 100}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | -600.00 |
| `u2` | +700.00 |
| `u3` | -100.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- Percentage-based exact split ✓

---

### A7: Three Members, Multiple Payers, Complex Net

**Scenario:** Multiple expenses, different payers, complex final balances.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 300.00 | `u1` | `[u1, u2, u3]` | `{u1: 100, u2: 100, u3: 100}` |
| `e2` | 150.00 | `u2` | `[u1, u2]` | `{u1: 75, u2: 75}` |
| `e3` | 90.00 | `u3` | `[u2, u3]` | `{u2: 45, u3: 45}` |

**Calculation:**
- Alice: +300 (paid) - 100 (owes e1) - 75 (owes e2) = +125
- Bob: +150 (paid) - 100 (owes e1) - 75 (owes e2) - 45 (owes e3) = -70
- Carol: +90 (paid) - 100 (owes e1) - 45 (owes e3) = -55

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +125.00 |
| `u2` | -70.00 |
| `u3` | -55.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- Multi-expense, multi-payer aggregation ✓

---

### A8: Exclude Split (One Member Excluded)

**Scenario:** Alice pays ₹400 for herself and Bob only (Carol excluded).

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 400.00 | `u1` | `[u1, u2]` | `{u1: 200, u2: 200}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +200.00 |
| `u2` | -200.00 |
| `u3` | 0.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- I5: All members present (even non-participants) ✓
- Exclusion works correctly ✓

---

### A9: Zero Expenses

**Scenario:** No expenses recorded.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:** `[]`

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | 0.00 |
| `u2` | 0.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- I5: All members present ✓
- Empty input handling ✓

---

### A10: Single Member

**Scenario:** Group with only one member.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 500.00 | `u1` | `[u1]` | `{u1: 500}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | 0.00 |

**Invariants Validated:**
- I1: Sum = 0 ✓
- Single member edge case ✓

---

### A11: Pending Member Excluded

**Scenario:** Mix of real and pending members.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `p_9876543210` | Pending Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 200.00 | `u1` | `[u1]` | `{u1: 200}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | 0.00 |

**Note:** `p_9876543210` should NOT appear in output.

**Invariants Validated:**
- I2: No pending members in output ✓

---

### A12: Invalid Expense Skipped (Zero Amount)

**Scenario:** Expense with zero amount should be ignored.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 0.00 | `u1` | `[u1, u2]` | `{u1: 0, u2: 0}` |
| `e2` | 100.00 | `u1` | `[u1, u2]` | `{u1: 50, u2: 50}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +50.00 |
| `u2` | -50.00 |

**Invariants Validated:**
- I3: Invalid expenses skipped ✓

---

### A13: Invalid Expense Skipped (Negative Amount)

**Scenario:** Expense with negative amount should be ignored.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | -50.00 | `u1` | `[u1, u2]` | `{u1: -25, u2: -25}` |
| `e2` | 100.00 | `u2` | `[u1, u2]` | `{u1: 50, u2: 50}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | -50.00 |
| `u2` | +50.00 |

**Invariants Validated:**
- I3: Invalid expenses skipped ✓

---

### A14: Payer Not in Member List

**Scenario:** Expense paid by unknown UID.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 100.00 | `u999` | `[u1, u2]` | `{u1: 50, u2: 50}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | -50.00 |
| `u2` | -50.00 |

**Note:** Payer credit is lost (no one credited). Sum is -100, violating I1.

**Invariants Validated:**
- A2: Documents behavior when payer invalid (known gap)

---

### A15: Floating Point Precision

**Scenario:** Three-way split of amount not evenly divisible.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 100.00 | `u1` | `[u1, u2, u3]` | `null` |

**Calculation:** 100 / 3 = 33.333...

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +66.67 (approx) |
| `u2` | -33.33 (approx) |
| `u3` | -33.33 (approx) |

**Note:** Sum should be ≈ 0 within tolerance.

**Invariants Validated:**
- I1: Sum ≈ 0 (within floating point tolerance) ✓

---

## Test Suite B: `computeDebts`

### B1: Single Debt (Two Members)

**Scenario:** Alice paid, Bob owes.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 300.00 | `u1` | `[u1, u2]` | `{u1: 150, u2: 150}` |

**Expected Debts:**
| fromId | toId | amount |
|--------|------|--------|
| `u2` | `u1` | 150.00 |

**Invariants Validated:**
- I6: Debt amount positive ✓
- Single transfer case ✓

---

### B2: No Debts (Balanced)

**Scenario:** Equal payments cancel out.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 200.00 | `u1` | `[u1, u2]` | `{u1: 100, u2: 100}` |
| `e2` | 200.00 | `u2` | `[u1, u2]` | `{u1: 100, u2: 100}` |

**Expected Debts:** `[]`

**Invariants Validated:**
- Zero balance yields no debts ✓

---

### B3: Three Members, Two Debtors

**Scenario:** Alice paid for all, Bob and Carol owe.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 900.00 | `u1` | `[u1, u2, u3]` | `{u1: 300, u2: 300, u3: 300}` |

**NetBalances:**
- `u1`: +600
- `u2`: -300
- `u3`: -300

**Expected Debts:** (order may vary by implementation, but amounts must match)
| fromId | toId | amount |
|--------|------|--------|
| `u2` | `u1` | 300.00 |
| `u3` | `u1` | 300.00 |

**Invariants Validated:**
- Multiple debtors to single creditor ✓
- I6: All debt amounts positive ✓

---

### B4: Three Members, Chain Resolution

**Scenario:** A is owed by B, B is owed by C — greedy algorithm resolves.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Setup NetBalances (via expenses):**
- `u1`: +200 (creditor)
- `u2`: 0 (neutral)
- `u3`: -200 (debtor)

**Expenses to achieve this:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 200.00 | `u1` | `[u3]` | `{u3: 200}` |

**Expected Debts:**
| fromId | toId | amount |
|--------|------|--------|
| `u3` | `u1` | 200.00 |

**Invariants Validated:**
- Direct resolution (no chain through neutral member) ✓

---

### B5: Three Members, Circular Debt Simplification

**Scenario:** Complex cycle that simplifies.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 300.00 | `u1` | `[u2]` | `{u2: 300}` |
| `e2` | 200.00 | `u2` | `[u3]` | `{u3: 200}` |
| `e3` | 100.00 | `u3` | `[u1]` | `{u1: 100}` |

**NetBalances:**
- `u1`: +300 (paid) - 100 (owes) = +200
- `u2`: +200 (paid) - 300 (owes) = -100
- `u3`: +100 (paid) - 200 (owes) = -100

**Expected Debts:** (greedy: largest debtor first)
| fromId | toId | amount |
|--------|------|--------|
| `u2` | `u1` | 100.00 |
| `u3` | `u1` | 100.00 |

**Note:** Total transferred = 200 (equal to net imbalance). Two transactions instead of three.

**Invariants Validated:**
- Circular debt simplification ✓
- I1: Sum of debts equals sum of positive balances ✓

---

### B6: Four Members, Multiple Creditors and Debtors

**Scenario:** Two creditors, two debtors.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |
| `u3` | Carol |
| `u4` | Dave |

**Setup NetBalances (via appropriate expenses):**
- `u1`: +300 (creditor)
- `u2`: +100 (creditor)
- `u3`: -250 (debtor)
- `u4`: -150 (debtor)

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 400.00 | `u1` | `[u3, u4]` | `{u3: 250, u4: 150}` |
| `e2` | 100.00 | `u2` | `[u1]` | `{u1: 100}` |

**Expected Debts:** (greedy algorithm)

Step 1: Largest debtor `u3` (-250) → Largest creditor `u1` (+300)
- Transfer: min(250, 300) = 250
- Result: `u3` → `u1` ₹250
- Remaining: `u1` = +50, `u3` = 0

Step 2: Largest debtor `u4` (-150) → Largest creditor `u2` (+100)
- Transfer: min(150, 100) = 100
- Result: `u4` → `u2` ₹100
- Remaining: `u2` = 0, `u4` = -50

Step 3: Largest debtor `u4` (-50) → Largest creditor `u1` (+50)
- Transfer: min(50, 50) = 50
- Result: `u4` → `u1` ₹50
- Remaining: all zero

| fromId | toId | amount |
|--------|------|--------|
| `u3` | `u1` | 250.00 |
| `u4` | `u2` | 100.00 |
| `u4` | `u1` | 50.00 |

**Invariants Validated:**
- Multi-creditor, multi-debtor resolution ✓
- Greedy algorithm determinism ✓

---

### B7: Below Tolerance Ignored

**Scenario:** Balance below ₹0.01 should not generate debt.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 100.00 | `u1` | `[u1, u2]` | `{u1: 50.005, u2: 49.995}` |

**NetBalances:**
- `u1`: +100 - 50.005 = +49.995
- `u2`: -49.995

**Expected Debts:**
| fromId | toId | amount |
|--------|------|--------|
| `u2` | `u1` | 49.995 |

**But if balance is exactly ₹0.009:**

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 0.018 | `u1` | `[u1, u2]` | `{u1: 0.009, u2: 0.009}` |

**NetBalances:**
- `u1`: +0.009 (below tolerance)
- `u2`: -0.009 (below tolerance)

**Expected Debts:** `[]`

**Invariants Validated:**
- Tolerance threshold (ε = 0.01) respected ✓

---

### B8: Empty Expenses

**Scenario:** No expenses.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:** `[]`

**Expected Debts:** `[]`

**Invariants Validated:**
- Empty input handling ✓

---

### B9: Large Amount Precision

**Scenario:** Large expense to verify no overflow.

**Members:**
| id | name |
|----|------|
| `u1` | Alice |
| `u2` | Bob |

**Expenses:**
| id | amount | paidById | participantIds | splitAmountsById |
|----|--------|----------|----------------|------------------|
| `e1` | 10000000.00 | `u1` | `[u1, u2]` | `{u1: 5000000, u2: 5000000}` |

**Expected NetBalances:**
| memberId | balance |
|----------|---------|
| `u1` | +5000000.00 |
| `u2` | -5000000.00 |

**Expected Debts:**
| fromId | toId | amount |
|--------|------|--------|
| `u2` | `u1` | 5000000.00 |

**Invariants Validated:**
- Large number handling ✓

---

## Test Suite C: Cross-Validation

### C1: Net Balance Sum Equals Zero

**For every test case above, verify:**

```
sum(netBalances.values) == 0 (within tolerance)
```

### C2: Debt Sum Equals Creditor Sum

**For every test case above, verify:**

```
sum(debts.amount) == sum(positiveBalances)
```

### C3: All Members Present in NetBalances

**For every test case above, verify:**

```
netBalances.keys == members.filter(m => !m.id.startsWith('p_')).map(m => m.id)
```

### C4: No Debt to Self

**For every test case above, verify:**

```
for each debt: debt.fromId != debt.toId
```

### C5: All Debt Amounts Positive

**For every test case above, verify:**

```
for each debt: debt.amount >= 0.01
```

---

## Summary: Test Coverage Matrix

| Test | Members | Expenses | Scenario | Invariants |
|------|---------|----------|----------|------------|
| A1 | 2 | 1 | Even split | I1, I5 |
| A2 | 2 | 1 | Empty participants | I1 |
| A3 | 2 | 1 | Exact split | I1 |
| A4 | 2 | 2 | Net to zero | I1 |
| A5 | 3 | 1 | One payer, all share | I1, I5 |
| A6 | 3 | 1 | Uneven percentage | I1 |
| A7 | 3 | 3 | Complex multi-payer | I1 |
| A8 | 3 | 1 | Exclusion | I1, I5 |
| A9 | 2 | 0 | Zero expenses | I1, I5 |
| A10 | 1 | 1 | Single member | I1 |
| A11 | 2 | 1 | Pending excluded | I2 |
| A12 | 2 | 2 | Zero amount skip | I3 |
| A13 | 2 | 2 | Negative amount skip | I3 |
| A14 | 2 | 1 | Invalid payer | A2 |
| A15 | 3 | 1 | Float precision | I1 |
| B1 | 2 | 1 | Single debt | I6 |
| B2 | 2 | 2 | No debts | — |
| B3 | 3 | 1 | Two debtors | I6 |
| B4 | 3 | 1 | Chain resolution | — |
| B5 | 3 | 3 | Circular simplify | I1 |
| B6 | 4 | 2 | Multi-party | — |
| B7 | 2 | 1 | Tolerance | — |
| B8 | 2 | 0 | Empty | — |
| B9 | 2 | 1 | Large numbers | — |

---

## Implementation Notes

1. **Test Isolation:** Each test should be independent — no shared state.
2. **Determinism:** Given identical inputs, outputs must be identical.
3. **Tolerance Comparisons:** Use `closeTo(expected, 0.01)` for floating point.
4. **Order Independence:** Debt list order may vary; validate by content, not position.

This specification locks down expected behavior. Any implementation change that fails these tests is a regression.
