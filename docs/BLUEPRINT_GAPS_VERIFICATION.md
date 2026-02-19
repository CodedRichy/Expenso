# Blueprint gaps verification

Cross-check of the "what is not done" list (from external review of APP_BLUEPRINT) against the current codebase.

## CRITICAL

### 1. UndoExpense not wired
- **Screen exists:** Yes (`lib/screens/undo_expense.dart`).
- **Logic exists:** Partially — SnackBar "Undo" in group_detail calls `repo.deleteExpense(gid, eid)` and is functional.
- **UndoExpense screen:** Never navigated to; `handleUndo` / `handleDismiss` are no-ops; no timer effect.
- **Repo:** No `lastAddedExpenseId` / last-added snapshot stored.
- **Verdict:** **Accurate.** Undo works via SnackBar only; the UndoExpense screen and repo last-added state are not wired.

### 2. EmptyStates not actually used
- **EmptyStates screen:** Exists and is used.
- **GroupsList:** Uses `EmptyStates(type: 'no-groups')` when no groups (not inline).
- **GroupDetail:** Uses `EmptyStates(type: 'no-expenses-new-cycle')` when expenses empty.
- **Verdict:** **Partially accurate.** EmptyStates is used in both places. "New cycle" empty copy exists as separate types in EmptyStates (`new-cycle`, `no-expenses-new-cycle`); no major duplication elsewhere.

### 3. ErrorStates never reachable
- **Screen/route:** Exists; no `Navigator.pushNamed(context, '/error-states')` (or equivalent) anywhere.
- **Errors:** Auth shows in-screen message; Firestore stream `onError` only `debugPrint`; Groq shows snackbar.
- **Verdict:** **Accurate.** ErrorStates is never pushed; no global or targeted route on auth/Firestore/Groq hard failure.

### 4. Contacts syncing incomplete
- **flutter_contacts:** Used in InviteMembers; permission requested and state tracked.
- **Permission denial:** UI shows "Access Contacts" when not granted; no dedicated denial/explanation flow.
- **Search/dedupe:** No indexing or debounce for large lists; no explicit dedupe of contacts vs existing/pending members; no UID resolution when user joins later.
- **Verdict:** **Accurate.**

### 5. Group invite link logic UI-only
- **InviteMembers:** "Copy invite link" runs `handleCopyLink()` which only sets `linkCopied = true`; no `Clipboard.setData`, no link generation, no revocation, no deep link handling.
- **pendingMembers:** Stored in Firestore and used; lifecycle (invite → join) not tied to any link.
- **Verdict:** **Accurate.** Link is visual only; no generation/revoke/deep link.

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

| Item | Verdict |
|------|--------|
| 1 UndoExpense | Accurate — wiring and repo state missing |
| 2 EmptyStates | Partially accurate — already used; could centralize types |
| 3 ErrorStates | Accurate — never pushed |
| 4 Contacts | Accurate |
| 5 Invite link | Accurate |
| 6–15 | Accurate |
