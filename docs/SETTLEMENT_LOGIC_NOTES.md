# Settlement logic — problem

## Problem statement

<!-- One sentence: what is wrong? -->



## Expected vs actual

- **Expected:**  
  Net balances: Alice +180, Bob +30, Carol −210.  
  Balances list: Carol owes Alice ₹180; Carol owes Bob ₹30.  
  Decision Clarity (cycle total ₹470): for Alice “Spent by you” ₹300, “Your status” +180; for Bob ₹120 and +30; for Carol ₹50 and −210.

- **Actual:**


## Steps to reproduce (Alice / Bob / Carol case)

1. **Members:** Alice (A), Bob (B), Carol (C).
2. **Expense 1:** Alice paid **₹300** for dinner. Split **even** among A, B, C. → Share = ₹100 each.
3. **Expense 2:** Bob paid **₹120** for coffee. Split **even** between B and C only. → Share = ₹60 each.
4. **Expense 3:** Carol paid **₹50** for snacks. Split **exact:** A → ₹20, B → ₹30 (Carol’s share 0 or implied).
5. Open group detail and check **Balances** and **Decision Clarity** (cycle total, spent by you, your status).


## Context / data

**Net balances (by hand):**

- Expense 1: A +300−100 = +200, B −100, C −100.
- Expense 2: A +200, B +120−60 = +60, C −100−60 = −160.
- Expense 3: A +200−20 = +180, B +60−30 = +30. Carol paid 50; if Carol is not in `splitAmountsByPhone` she gets +50 and no minus → C −160+50 = −110. If Carol is in the split with 0 she still gets +50, so C = −110. (For Carol to be −210, expense 3 would need to add −50 to Carol, e.g. a different split convention.)

**Reference net result (if expense 3 is “A:20, B:30, C not in split”):** Alice +180, Bob +30, Carol −110. Sum = 100 (not 0 unless payer’s share is also deducted elsewhere).

**Reference net result (if we want sum 0 and Carol −210):** Alice +180, Bob +30, Carol −210 → then correct debts: Carol owes Alice ₹180, Carol owes Bob ₹30.

**What the app showed:**

<!-- Fill in: Balances list, Decision Clarity numbers for each person, any mismatch. -->



## Notes

<!-- Anything else. -->

