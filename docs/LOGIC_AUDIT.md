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

## Firestore: "This document does not exist"

**What you see:** In the Firestore console, a document under `groups` (e.g. `g_1771258278101`) shows **"This document does not exist, it will not appear in queries or snapshots"** but may still list subcollections (e.g. `settled_cycles`).

**Why it happens:** In Firestore, a document "exists" only if it has at least one field. You can have a *path* because of subcollections (e.g. `groups/g_xxx/settled_cycles`) while the parent document itself has no fields. That usually means either:

1. The group document was **deleted** before the full-delete fix (e.g. via the app’s "Delete group" when the app only removed the document and left subcollections). Those orphaned paths can still appear in the console. *Now*, deleting a group from the app removes the group and all its data (see "Fixed: Delete group leaves subcollections").
2. Something wrote only to a subcollection and never created the group document (e.g. a script or an old flow). The app’s `createGroup` does a full `set()` with fields, so new groups created in the app should not end up in this state.

**Impact:** The app’s `groupsStream(uid)` query uses `where('members', arrayContains: uid)`. It only returns documents that **exist**. So a group with no document will not appear in the app; you only see it in the console when opening that path.

**What to do:**

- **Clean up:** In the console, open the non-existent document’s subcollections and delete them if you don’t need the data (e.g. delete `settled_cycles` and any `expenses` under the group). That removes the orphaned path. You cannot "delete" the document itself because it doesn’t exist.
- **Recover:** If you want the group to appear again, use **"+ Add field"** on that document and add the required fields (`groupName`, `members`, `creatorId`, `activeCycleId`, `cycleStatus`) so the document exists and matches what the app expects. Prefer fixing data in the app (e.g. re-create the group) if you’re unsure of correct values.

---

## Fixed: Delete group leaves subcollections (firestore_service.dart)

**Issue:** `deleteGroup(groupId)` only deleted the group document. Subcollections `expenses` and `settled_cycles` (and nested `settled_cycles/{id}/expenses`) remained, so the group path still appeared in the Firestore console and "This document does not exist" could show for the parent path.

**Fix:** `deleteGroup` now removes all group data: (1) all documents in `groups/{groupId}/expenses`, (2) for each settled cycle, all documents in `groups/{groupId}/settled_cycles/{cycleId}/expenses` then the cycle document, (3) the group document. Deletion uses batched deletes (500 per batch) to stay within Firestore limits. The group and its path are fully removed from the database.

---

## Fixed: Settlement confirmation label (settlement_confirmation.dart)

**Issue:** The screen showed `group.amount` (cycle total) with the label "Settlement amount". That's the **total** cycle amount, not the amount the current user owes or is owed.

**Fix:** Label changed to "Cycle total" so it's clear this is the total being closed.

---

## Fixed: Route arguments contract

**Issue:** Several screens used `ModalRoute.of(context)!.settings.arguments as Group` (or similar) without checking for null or wrong type. If a route was opened without arguments or with the wrong type, the app would throw.

**Fix:** Added `lib/utils/route_args.dart` with `RouteArgs.getGroup(context)` and `RouteArgs.getMap(context)` for safe casts. Screens that require a `Group` or map (group_members, settlement_confirmation, payment_result, cycle_settled, cycle_history_detail, expense_input) use these helpers and pop if arguments are missing or wrong type.

---

## Fixed: Edit expense when expense no longer exists (edit_expense.dart)

**Issue:** If the user opened Edit Expense and the expense was deleted (e.g. by another device or a previous action), `existing` could be null on save. The code still called `repo.updateExpense` with `existing?.date ?? 'Today'`, etc., and the Firestore update could fail.

**Fix:** Before calling `updateExpense`, the screen now checks `existing != null`. If the expense was deleted, it shows a SnackBar "Expense not found. It may have been deleted." and pops.

---

---

## Fixed: EditExpense doesn't recalculate splits when amount changes

**Issue:** When editing an expense and changing the total amount, the existing `splitAmountsById` was preserved as-is. This meant changing a 1000 expense to 800 would leave split amounts summing to 1000, causing incorrect balance calculations.

**Fix:** When the expense amount is changed and `splitAmountsById` is present, splits are now re-proportioned by the ratio (newAmount / oldAmount). Also added `isNaN` and `isInfinite` checks for the amount.

---

## Fixed: CreateGroup doesn't persist settlement rhythm/day

**Issue:** The CreateGroup screen collected `rhythm` and `settlementDay` from the user but never passed them to the repository or Firestore. The values were lost.

**Fix:** Updated `CreateGroup.handleCreate` to pass `settlementRhythm` and `settlementDay` to `CycleRepository.addGroup`, which now accepts these parameters and passes them to `FirestoreService.createGroup` for storage.

---

## Fixed: expense_validation missing isInfinite check

**Issue:** `validateExpenseAmount` checked for `isNaN` and `amount <= 0` but not `isInfinite`. Infinite values could pass validation.

**Fix:** Added `amount.isInfinite` check to `validateExpenseAmount`.

---

## Fixed: SettlementEngine _buildNetBalances edge cases

**Issue:** The settlement engine didn't explicitly filter out invalid expense amounts (`NaN`, `Infinity`, `<= 0`) or validate that participant IDs correspond to actual group members. Split amounts weren't validated for `NaN`/`Infinity`.

**Fix:** Added validation for expense amounts (skip if invalid), filtered participant IDs to only include actual members, and added `isNaN`/`isInfinite` checks for individual split amounts and per-share calculations.

---

## Fixed: GroupDetail may crash if group deleted externally

**Issue:** If a group was deleted from Firestore while a user was viewing `GroupDetail`, `repo.getGroup(groupId)` would return null, potentially causing crashes or showing stale data.

**Fix:** Added a null check for `defaultGroup` in `GroupDetail`. If the group no longer exists, the user is navigated back to the groups list via `popUntil`.

---

## Fixed: ExpenseInput doesn't validate infinite/NaN amounts

**Issue:** `ExpenseInput.handleSubmit` and `_canSubmit` only checked if the amount was `> 0`, but didn't validate for `NaN` or `isInfinite` values that could be parsed from user input.

**Fix:** Added explicit `isNaN` and `isInfinite` checks in both `handleSubmit` and `_canSubmit`.

---

## Fixed: UndoExpenseOverlay timer continues after unmount

**Issue:** The periodic timer in `_UndoExpenseOverlayContentState` checked `mounted` before state updates but could still call `widget.onDismiss()` after the widget was disposed, or continue running unnecessarily.

**Fix:** Added `_timer?.cancel()` when `!mounted`, and added a second `mounted` check before calling `onDismiss()`.

---

## Fixed: InviteMembers Done button dead code path

**Issue:** When `groupArg` was null, the Done button would create a new orphan `Group` object with the current timestamp as ID and navigate to group detail. This group wouldn't exist in Firestore.

**Fix:** Removed the dead code path. If `groupArg` is null or the group no longer exists, the user is navigated back to the groups list.

---

## Fixed: _dateStringToSortKey year rollover bug

**Issue:** When parsing a date like "Jan 5" in December, the function would use the current year, making it appear as a future date and sorting incorrectly.

**Fix:** If the parsed date is more than 1 day in the future, it's assumed to be from the previous year and adjusted accordingly.

---

## Fixed: CycleRepository.addGroup fire-and-forget error handling

**Issue:** `addGroup` called `FirestoreService.createGroup` without awaiting or handling errors. If group creation failed, the error was silently lost and the UI would navigate as if successful.

**Fix:** Made `addGroup` async and wrapped the `createGroup` call in try/catch with rethrow. Updated `CreateGroup.handleCreate` to await the result and show a SnackBar on failure.

---

*Audit performed by reviewing cycle_repository, settlement_engine, firestore_service, main routes, group_detail, expense_input, edit_expense, undo_expense, settlement_confirmation, payment_result, profile, phone_auth_service, create_group, and invite_members.*
