# Logic audit (Feb 2026)

Summary of logical errors and edge cases found across the project. Items marked **Fixed** have been addressed in code; others remain for follow-up.

---

## Fixed: `_membersById` cleared inside loop (cycle_repository.dart)

**Issue:** In `_onGroupsSnapshot`, `_membersById.clear()` was called **inside** the `for (final doc in docs)` loop. That meant after processing all groups, only members from the **last** group in the list remained. Every other group lost its members in `_membersById`.

**Impact:** For any group that wasn't the last in the Firestore query:

- `getMembersForGroup(groupId)` could return an empty or incomplete list.
- `calculateBalances` / `getSettlementInstructions` used that list, so settlement instructions could be wrong or empty.
- `_DecisionClarityCard` in GroupDetail uses `getMembersForGroup` and `SettlementEngine.computeNetBalances(expenses, members)` — so the "Spent by You" / "Your Status" card could be wrong for all but one group.
- `getMemberDisplayName` (used in settlement instructions) would fall back to formatted phone for missing members.

**Fix:** Move `_membersById.clear()` to **before** the loop (once per snapshot), so members from every group are accumulated, not replaced each iteration.

---

## Fixed: Undo after add expense

**Issue:** The `/undo-expense` route existed but nothing navigated to it; handlers were empty. The "Undo last expense" feature was non-functional.

**Fix:** After adding an expense (manual entry and Magic Bar confirm), show a SnackBar with "Expense added" and an "Undo" action that calls `deleteExpense(groupId, expenseId)`. Expense input pops with `{groupId, expenseId}`; group_detail shows the snackbar and handles Undo. Magic Bar dialog pops with the same result; caller awaits and shows snackbar with Undo.

---

## Fixed: Expense date sort (firestore_service.dart, cycle_repository)

**Issue:** Expenses were sorted by the `date` string; order was not chronological.

**Fix:** New expenses now write `dateSortKey` (milliseconds since epoch) in Firestore. `expensesStream` sorts by `dateSortKey` first, with fallback to `date` string for older docs. Display order is chronological.

---

## Settlement confirmation: "Settlement amount" label (settlement_confirmation.dart)

**Issue:** The screen shows `group.amount` (cycle total) with the label "Settlement amount". That's the **total** cycle amount, not the amount the current user owes or is owed.

**Impact:** Possible user confusion ("Is this what I pay?"). Not a logic bug, but a UX/copy clarity issue.

**Suggestion:** If the screen is meant to show "total cycle amount being closed", consider wording like "Cycle total" or "Total being settled". If you want "amount you owe", compute and show the user's share from balances.

---

## Route arguments contract

**Issue:** Several screens use `ModalRoute.of(context)!.settings.arguments as Group` (or similar) without checking for null or wrong type. If a route is ever opened without arguments or with the wrong type, this will throw.

**Impact:** Crash if navigation is triggered incorrectly (e.g. from a deep link or a mistaken `pushNamed` without arguments).

**Suggestion:** Use safe casts and null checks, or a small helper that returns a nullable `Group` / shows an error and pops if missing.

---

## Edit expense when expense no longer exists (edit_expense.dart)

**Issue:** If the user opens Edit Expense and the expense is deleted (e.g. by another device or a previous action), `existing` can be null when loading. On save, we still call `repo.updateExpense(groupId, updatedExpense)` using `existing?.date ?? 'Today'`, etc. The Firestore update may fail (document not found).

**Impact:** User might see a generic error. Not a logic bug in the sense of wrong data, but the screen could validate that `existing != null` before enabling save or show "Expense not found" and pop.

**Suggestion:** Before calling `updateExpense`, check `existing != null` and handle the "expense deleted" case (e.g. show message and pop).

---

*Audit performed by reviewing cycle_repository, settlement_engine, firestore_service, main routes, group_detail, expense_input, edit_expense, undo_expense, settlement_confirmation, payment_result, profile, and phone_auth_service.*
