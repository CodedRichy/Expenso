# Research: How to Solve Settlement Logic Issues in Expenso

This doc summarizes research on fixing and hardening settlement/balance logic in expense-splitting apps, applied to Expenso.

---

## 1. Core invariants (what “correct” means)

Any correct settlement implementation must keep these true (Splitwise and similar apps use the same idea):

| Invariant | Meaning |
|-----------|--------|
| **Net sum is zero** | Sum of all members’ net balances = 0 (within tolerance). If not, the system is inconsistent. |
| **Nets come only from expenses** | Each person’s net = (total they paid) − (total they owe from splits). No extra sources. |
| **Debts preserve nets** | The list of “A owes B ₹X” must be equivalent to the net balances: after applying those transfers, everyone ends at 0. |

So the main lever is: **get the inputs right** (who paid, who is in the split, how much each owes). The “who owes whom” algorithm (greedy match of debtors to creditors) is standard and correct; bugs usually come from wrong or missing participant/payer data.

---

## 2. Single source of truth

Two common designs:

- **Stored participants:** Store an explicit participant list (and optionally per-person shares) per expense. Balances are computed only from this. Risk: stored list can get out of sync (e.g. member removed from group later; or wrong at write time).
- **Computed from one canonical form:** Store one representation (e.g. `splits`: UID → share). Derive “participants” and “who owes what” only from that. Risk: derivation can drop people (e.g. UID→phone fails) and then nets are wrong.

Expenso uses the second approach: Firestore has `splits` (and `payerId`). When we read, we derive `participantPhones` / `splitAmountsByPhone` in `_expenseFromFirestore`. So:

- **Correctness depends on:** (1) What we **write** (parser/form must write correct payer + full `splits` for the intended participants). (2) What we **read** (UID→phone must not drop anyone; we fixed this by using `_membersById` first).
- **Recommendation:** Treat `splits` + `payerId` as the only source of truth. Never infer “who’s in the split” from anywhere else when computing balances. Add validation at **write** time so bad data doesn’t get in.

---

## 3. Validation strategies (practical ways to catch bugs)

### 3.1 Assert net sum = 0

After computing net balances (in tests and, optionally, in app):

- Sum all net values; assert `sum.abs() < tolerance` (e.g. 0.01).
- If it fails: the inputs are wrong (missing participant, wrong share, or wrong payer). Log and, in dev, consider surfacing “Data inconsistency” instead of showing wrong numbers.

This is the single most important check: it catches missing or double-counted shares.

### 3.2 One implementation for “net balances”

Have **one** function that computes net balances from expenses + members. Everyone (group detail, settlement dialog, Razorpay, tests) should use it. Expenso had two (SettlementEngine and CycleRepository.calculateBalances); we aligned the repo with the engine for the payer default. Going further: **remove the duplicate** and have the repo call `SettlementEngine.computeNetBalances` (and same for debts if needed) so there is no chance of the two implementations drifting.

### 3.3 Validate at write time

When adding or updating an expense:

- **Even split:** `participantPhones` or `splits` must include everyone in the split; `sum(splits.values) == amount` (tolerance); `payerId` must be in the group.
- **Exact/percentage/shares:** Same sum check; every key in `splits` must be a current group member (by UID/phone). Reject or correct before writing.

This stops “wrong who is involved” from ever becoming stored data.

### 3.4 Property-based / scenario tests

- **Property:** For any list of expenses and members, if every expense has `sum(splits) == amount` and all keys are in the member set, then `sum(net balances) == 0`.
- **Scenarios:** Pin the Alice/Bob/Carol (and similar) cases: fixed expenses, expected net balances and expected debt list; assert engine and repo give the same result and that net sum is 0. Add a test that builds expenses with **empty** participantPhones (meaning “all members”) and checks nets and debts.

These tests lock in the intended behavior and catch regressions (e.g. after changing “who is in the split” when participantPhones is empty).

### 3.5 Debugging when something is wrong

- **Step 1:** Compute net balances and check `sum(net balances) == 0`. If not, the bug is in **input data** (who paid, who’s in the split, or per-person shares).
- **Step 2:** For each expense, recompute “expected” share per person from stored `splits` / participant list; ensure payer gets +amount and each participant gets −their share. Find the expense(s) where this doesn’t match the stored data or where a member is missing.
- **Step 3:** Trace where that expense was created (Magic Bar vs manual) and fix the path that wrote wrong `splits` or `participantPhones`.

---

## 4. Algorithm note (minimal transfers)

The “minimal number of payments” problem (debt simplification) is well known: compute net balances, then match debtors to creditors. A **greedy** approach (sort debtors and creditors by amount, then repeatedly match largest debtor to largest creditor and transfer the smaller of the two amounts) gives at most `n−1` payments and preserves net balances. It does not always minimize the number of transactions (that can be NP-hard in general), but it is simple and correct for “same nets, fewer edges.” Expenso’s SettlementEngine and repo already use this idea; no change needed there unless you want a different optimization goal.

---

## 5. Recommended next steps for Expenso

1. **Add net-sum assertion**  
   In `SettlementEngine._buildNetBalances` (or right after), in debug/test: assert `sum(net.values).abs() < 0.01`. Optionally in production: if it fails, log and show a generic “balance inconsistency” instead of wrong numbers.

2. **Unify balance computation**  
   Have `CycleRepository.calculateBalances` call `SettlementEngine.computeNetBalances(getActiveCycle(groupId).expenses, getMembersForGroup(groupId))` instead of reimplementing. Same for debts if the repo has its own debt list. That way there is a single implementation to test and fix.

3. **Validate on write**  
   In `addExpense` / `addExpenseFromMagicBar`: before writing to Firestore, check that `sum(splits.values)` equals the expense amount (tolerance) and that every UID in `splits` (and payerId) resolves to a current group member. Reject or fix the payload if not.

4. **Add scenario tests**  
   In `test/`, add tests: (a) Alice/Bob/Carol with all even splits (e.g. 300/3, 120/3, 50/3); assert expected nets and that sum == 0; (b) one expense with `participantPhones` empty and all members in `splits`; (c) one expense with wrong `splits` sum and assert that validation fails or that net sum != 0 so the invariant test catches it.

5. **Document the invariant**  
   In code or in APP_BLUEPRINT: “Sum of net balances over the group must be zero; if not, the stored expenses (splits/payer) are inconsistent.” That makes the “why” of validation and tests clear for future changes.

---

## 6. References

- Splitwise “Simplify debts” rules and greedy/min-cost-flow style approach (e.g. [Medium](https://medium.com/@mithunmk93/algorithm-behind-splitwises-debt-simplification-feature-8ac485e97688)).
- Stack Overflow: [algorithm to determine minimum payments amongst a group](https://stackoverflow.com/questions/1163116/algorithm-to-determine-minimum-payments-amongst-a-group) (net balances, then match givers/receivers).
- Single source of truth: Beancount-style “compute splits from one canonical form” vs stored participant lists; validation at write and at read.
- Property-based / invariant testing for financial logic: assert invariants (e.g. sum of balances = 0) over many or fixed inputs.
