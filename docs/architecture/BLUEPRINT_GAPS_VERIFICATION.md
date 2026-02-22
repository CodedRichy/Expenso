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

### 4. Contacts syncing incomplete — **PARTIALLY FIXED**
- **Permission denial:** InviteMembers now shows message: "Contacts access was denied. You can still add members by entering a number below." plus "Access Contacts" button.
- **Dedupe:** Contact suggestions exclude phones that are already members or pending (`_getFilteredContacts(existingPhones)`). UID resolution when user joins later and large-list performance remain as future work.

### 5. Group invite link logic UI-only — **PARTIALLY FIXED**
- **Invite link:** `handleCopyLink()` now builds `expenso://join/<groupId>` and copies to clipboard via `Clipboard.setData`. Link generation + copy done.
- **Revocation / deep link / pending lifecycle:** Not implemented (link is stable per group; no token revocation or incoming deep-link handling yet).

---

## IMPORTANT

### 6. Settlement engine edge cases
- **Rounding:** Uses `_tolerance = 0.01`; display uses `amount.round()` in instructions; no deterministic "who absorbs paisa" or consistent rounding strategy.
- **Verdict:** **Accurate.**

### 7. Reports / History clarity
- **CycleHistory / CycleHistoryDetail:** Present; no summary totals per cycle, "who paid most" / "who owed most", or opening/closing balance.
- **Verdict:** **Accurate.**

### 8. Reminder system
- **Verdict:** **Accurate.** Not implemented (no scheduler, no notifications).

### 9. Profile completeness
- Avatar/display/UPI exist; avatar fallbacks and logout cleanup edge cases not fully centralized.
- **Verdict:** **Accurate.**

---

## POLISH / TECH

### 10–13. Receipts, UPI QR, category intelligence, smart nudges
- **Verdict:** **Accurate** — not implemented as stated.

### 14. Tests coverage minimal
- **Verdict:** **Accurate.** No SettlementEngine, cycle transition, or permission tests found.

### 15. Offline behavior undefined
- **Verdict:** **Accurate.** No explicit cache strategy, write queue, or "sync pending" UI.

---

## Summary

| Item | Verdict | Status |
|------|--------|--------|
| 1 UndoExpense | Was accurate | **FIXED** (repo last-added, UndoExpense screen wired) |
| 2 EmptyStates | Partially accurate | **FIXED** (zero-waste-cycle in EmptyStates; inline removed) |
| 3 ErrorStates | Was accurate | **FIXED** (Firestore + auth session-expired → route) |
| 4 Contacts | Was accurate | **PARTIALLY FIXED** (denial message + dedupe) |
| 5 Invite link | Was accurate | **PARTIALLY FIXED** (generate + copy; no revoke/deep link) |
| 6–15 | Accurate | Not yet addressed |
