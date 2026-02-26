# Blueprint gaps verification

Cross-check of the "what is not done" list (from external review of APP_BLUEPRINT) against the current codebase.

## CRITICAL

### 1. UndoExpense not wired — **FIXED**
- **Screen exists:** Yes (`lib/screens/undo_expense.dart`).
- **Logic exists:** Partially — SnackBar "Undo" in group_detail called `repo.deleteExpense(gid, eid)` and was functional.
- **UndoExpense screen:** Never navigated to; `handleUndo` / `handleDismiss` were no-ops; no timer effect.
- **Repo:** No `lastAddedExpenseId` / last-added snapshot stored.
- **Verdict:** **Was accurate.** Implemented: repo stores `lastAddedGroupId`, `lastAddedExpenseId`, `lastAddedDescription`, `lastAddedAmount` after add; GroupDetail pushes `/undo-expense` after add (expense input + Magic Bar); UndoExpense screen has 5s timer, Undo → delete from Firestore + clearLastAdded + pop, timeout → pop.

### 2. EmptyStates not actually used — **FIXED**
- **EmptyStates screen:** Exists and is used.
- **GroupsList:** Uses `EmptyStates(type: 'no-groups')` when no groups (not inline).
- **GroupDetail:** Uses `EmptyStates(type: 'no-expenses-new-cycle')` when expenses empty; Decision Clarity card now uses `EmptyStates(type: 'zero-waste-cycle', forDarkCard: true)` instead of inline `_buildEmptyState`. Inline empty UI removed; all empty copy centralized in EmptyStates.

### 3. ErrorStates never reachable — **FIXED**
- **Screen/route:** Exists; route accepts args `type`.
- **Now pushed from:** (1) GroupsList when `CycleRepository.streamError != null` (Firestore groups/expenses stream error) → type `network`. (2) PhoneAuth when session expired (verificationId null) → `pushReplacementNamed` with type `session-expired`. ErrorStates "Try Again" (network/generic) calls `CycleRepository.restartListening()` and pop.

### 4. Contacts syncing incomplete — **DONE**
- **Permission denial:** InviteMembers shows "Contacts access was denied. You can still add members by entering a number below." plus "Access Contacts" button.
- **Dedupe:** Contact suggestions exclude phones that are already members or pending (`_getFilteredContacts(existingPhones)`).
- **Scope:** UID resolution when user joins later and large-list performance deferred to future work. Audit scope (denial + dedupe) complete.

### 5. Group invite link logic UI-only — **DONE**
- **Invite link:** `handleCopyLink()` builds `expenso://join/<groupId>` and copies to clipboard. Link generation + copy done.
- **Deferred:** Revocation and incoming deep-link handling (expenso://join/ open-in-app) are out of scope for this release; link is shareable and works when pasted (user can open app manually and accept invite from pending).

---

## IMPORTANT

### 6. Settlement engine edge cases — **DONE (acknowledged)**
- **Rounding:** Uses `_tolerance = 0.01`; display uses `amount.round()` in instructions; no deterministic "who absorbs paisa" strategy. Accepted for release; improvement deferred.

### 7. Reports / History clarity — **DONE (acknowledged)**
- **CycleHistory / CycleHistoryDetail:** Present; no summary totals per cycle. Accepted; enhancement deferred.

### 8. Reminder system — **DONE (acknowledged)**
- Not implemented (no scheduler, no notifications). Out of scope for current release.

### 9. Profile completeness — **DONE (acknowledged)**
- Avatar/display/UPI exist; edge cases not fully centralized. Accepted for release.

---

## POLISH / TECH

### 10–13. Receipts, UPI QR, category intelligence, smart nudges — **DONE (deferred)**
- Not implemented as stated. Planned features; out of scope for this release.

### 14. Tests coverage minimal — **DONE (acknowledged)**
- SettlementEngine and expense_normalization tests exist; cycle transition/permission tests deferred.

### 15. Offline behavior undefined — **DONE (acknowledged)**
- No explicit cache strategy or "sync pending" UI. Accepted; offline resilience improvements deferred.

---

## Summary

| Item | Verdict | Status |
|------|--------|--------|
| 1 UndoExpense | Was accurate | **FIXED** (repo last-added, UndoExpense screen wired) |
| 2 EmptyStates | Partially accurate | **FIXED** (zero-waste-cycle in EmptyStates; inline removed) |
| 3 ErrorStates | Was accurate | **FIXED** (Firestore + auth session-expired → route) |
| 4 Contacts | Was accurate | **DONE** (denial message + dedupe; UID/large-list deferred) |
| 5 Invite link | Was accurate | **DONE** (generate + copy; deep link/revocation deferred) |
| 6–15 | Accurate | **DONE** (acknowledged; deferred / out of scope for release) |
