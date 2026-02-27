# Pre-Release Audit — Expenso

**Role:** Team lead / senior dev + UI designer review before publish.  
**Scope:** Gaps that could block or undermine a production release.

Use this alongside [V4_TESTING_ISSUES.md](V4_TESTING_ISSUES.md), [LOGIC_AUDIT.md](LOGIC_AUDIT.md), and [STABILIZATION.md](../STABILIZATION.md).

---

## 1. Critical (fix before publish)

### 1.1 Firestore: Group delete allowed for any member

**Area:** Security  
**Issue:** `firestore.rules` for `groups/{groupId}` use:

```txt
allow delete: if request.auth != null && request.auth.uid in resource.data.members;
```

So **any group member** can delete the group. The app correctly enforces creator-only delete in `CycleRepository.deleteGroup` (via `canDeleteGroup`), but a custom client or compromised token could delete a group without being the creator.

**Recommendation:** Restrict delete to creator only, e.g.:

```txt
allow delete: if request.auth != null
  && request.auth.uid == resource.data.creatorId;
```

(Adjust to match your rules syntax; `creatorId` is stored on the group document.)

**Status:** Fixed. `firestore.rules` now use `request.auth.uid == resource.data.creatorId` for group delete.

**Deploy:** Run `firebase deploy --only firestore` (or deploy from Firebase Console) for the change to take effect. *(Deployed.)*

---

### 1.2 Dead route and misleading screen: `/delete-group` and `DeleteGroup`

**Area:** Code hygiene / UX  
**Issue:**

- The route `/delete-group` was registered in `main.dart` and built `const DeleteGroup()` with **no arguments**.
- No navigation in the app ever calls `pushNamed(..., '/delete-group')`. Group delete is done via **in-dialog confirmation** in `GroupsList._confirmDeleteGroup` (AlertDialog → `repo.deleteGroup(group.id)`).
- The `DeleteGroup` screen exists with two buttons: **"Delete Group"** (primary) and **"Cancel"**. The **"Delete Group"** button only calls `Navigator.pop(context)` — it does **not** call `repo.deleteGroup`. So the screen never performs a delete and is misleading.

**Status:** Route `/delete-group` and import of `DeleteGroup` removed from `main.dart`. The `DeleteGroup` screen file is kept with a top-of-file comment that it is not in the navigation flow (group delete is done via GroupsList dialog).

---

## 2. High (should fix or explicitly accept)

### 2.1 Accessibility (a11y) coverage

**Area:** UX / compliance  
**Issue:** Only a few key actions use `Semantics` (e.g. FAB Create group, Create Group button, Profile Log out, Settlement Back to Group). Most screens have no semantic labels for amounts, sections, or controls. TalkBack/screen-reader users get limited context.

**Recommendation:** Add a systematic pass: semantic labels for Decision Clarity card (cycle total, your status, amounts), expense list items, settlement amounts and buttons, and form fields. Prioritize flows that affect money (add expense, settlement, edit expense).

**Status:** Addressed. Semantics added to: Decision Clarity card (balance summary with cycle total, you paid, your status); settlement success message ("You're all settled"); expense input Submit button. Back to Group and other key actions were already covered (G1). Further screens can be added in a follow-up pass.

**Ref:** V4_TESTING_ISSUES.md G1 (partially addressed).

---

### 2.2 Route args: consistent use of `RouteArgs` and null handling

**Area:** Robustness  
**Current state:**

- **Good:** `EditExpense` handles missing/wrong args and shows `_buildErrorScreen`; `SettlementConfirmation`, `PaymentResult`, `CycleSettled`, `CycleHistory`, `CycleHistoryDetail`, `GroupDetail` pop or show fallback when group/args are null.
- **Inconsistent:** Several screens still use raw `ModalRoute.of(context)?.settings.arguments as Group?` (e.g. `CycleHistory`, `InviteMembers`, `GroupDetail`) instead of `RouteArgs.getGroup(context)`. They handle null but the pattern is mixed.
- **MemberChange:** When args are null or wrong type, `displayGroupId` and `displayMemberId` are empty; "Remove" calls `repo.removeMemberFromGroup('', '')`. No explicit pop for invalid args; screen shows degraded content.

**Recommendation:** Prefer `RouteArgs.getGroup(context)` (or a dedicated getter) everywhere a screen needs a `Group`. For `MemberChange`, consider popping when required args are missing (e.g. `groupId` or `memberId` empty) to avoid no-op remove.

**Status:** Addressed. `CycleHistory`, `InviteMembers`, and `GroupDetail` now use `RouteArgs.getGroup(context)`. `InviteMembers` pops when group is null (no group = no screen). `MemberChange` pops when `displayGroupId` or `displayMemberId` is empty.

---

### 2.3 InviteMembers: direct open with no group

**Area:** Edge case  
**Issue:** If a user lands on `/invite-members` without arguments (e.g. deep link or future nav), `groupArg` is null. LOGIC_AUDIT notes the "Done" dead code path was fixed to navigate back instead of creating an orphan group. Remaining risk: other actions (e.g. "Add by phone", invite link) may assume a valid group.

**Recommendation:** Ensure every action that needs `groupId` checks for a resolved group and either disables the control or pops back with a short message when group is null.

**Status:** Addressed. InviteMembers now uses `RouteArgs.getGroup(context)` and pops immediately when group is null, so the screen is never shown without a valid group. All actions (copy link, add by phone, Done) therefore always have a valid group.

---

## 3. Medium (polish / technical debt)

### 3.1 Date as string / timezone (G7)

**Area:** Data model / global use  
**Issue:** STABILIZATION §5 and V4_TESTING_ISSUES G7: expense `date` is stored as a human string ("Today", "Yesterday", "Mon DD"). Date math and "today" boundaries are timezone- and locale-fragile.

**Recommendation:** Document as known limitation for V4; plan a future schema change (e.g. store ISO date or timestamp, derive display strings in UI from device timezone).

---

### 3.2 No pagination (G8)

**Area:** Scale  
**Issue:** Groups list, expense list, and cycle history load in full. Acceptable for small datasets; will degrade with many groups or hundreds of expenses per cycle.

**Recommendation:** Acknowledge in STABILIZATION; prioritize when usage grows (e.g. cursor-based or page-based loading).

---

### 3.3 Integer-amounts migration (G4)

**Area:** Data consistency  
**Issue:** Phase 1 (write-path bridge with `amountMinor` / `splitsMinor`) is in place; some UI and code paths still use double amounts. Mixed scales (e.g. JPY/KRW vs INR) make double-based storage more prone to rounding.

**Phase 2 options:**

- **Backfill:** One-time pass over existing Firestore expenses: for each doc that has `amount`/`splits` but no `amountMinor`/`splitsMinor`, compute and write the minor fields (using group `currencyCode`). After that, all expenses use the integer path in settlement; no app/UI change.
- **Model/UI migration:** Make minor units the source of truth on `Expense` (store `amountMinor` / `splitAmountsByIdMinor`; derive `amount` / `splitAmountsById` for display). UI uses `formatMoneyWithCurrency(amountMinor, currencyCode)` everywhere; remove legacy double adapters (`computeNetBalancesAsDouble`, `computeDebtsAsDouble`, `expenseToLedgerDeltasLegacy`).

**Recommendation:** Document remaining double paths until Phase 2; run backfill if you want every existing expense on the integer path; plan model/UI migration when touching amount display broadly. See V4_TESTING_ISSUES.md G4.

---

### 3.4 Design system consistency

**Area:** UI  
**Observation:** Design tokens (`lib/design/`) and theme are centralized; many screens use `context.colorXxx` and `context.screenTitle` etc. Some screens still use hardcoded `fontSize`/`FontWeight`/colors (e.g. `PaymentResult`, `CycleSettled`, `MemberChange`). Empty and error states are consistent; gradient scaffold and cards are used widely.

**Recommendation:** Gradual pass: replace inline text styles with typography tokens and theme colors so dark/light and future rebrands stay consistent.

---

### 3.5 Loading and error UX

**Area:** UX  
**Observation:** Bounded loading (6–8s) and slow-loading hints are documented and used (e.g. groups list, cycle history). Error states push `/error-states` with type and "Try Again" calls `restartListening()`. Good. Ensure every async flow that can fail (e.g. add expense, delete group, settlement) shows a clear, calm message and a retry or back path.

---

## 4. UI/UX checklist (designer hat)

| Area | Status | Notes |
|------|--------|--------|
| **Empty states** | OK | No-groups, no-expenses, new-cycle, zero-waste; CTAs clear. |
| **Error states** | OK | network, session-expired, payment-unavailable, generic; back + Try Again. |
| **Settlement flow** | OK | Pay/Settle vs View settlement; incoming confirmations; "You're all settled" vs pending confirmations mutually exclusive (V4 fix). |
| **Decision Clarity card** | OK | Cycle total, spent-by-you, your status (credit/debt); empty state "Zero-Waste Cycle". |
| **Forms** | OK | Expense confirmation: total/assigned live sum; validation and haptics; Justice Guard on Settle/Start New Cycle. |
| **Keyboard overflow** | Addressed | WHO'S INVOLVED (expense), Profile UPI section wrapped in scroll (V4). |
| **Contrast** | Addressed | Settlement Rhythm / Day on Create group use onSurface (V4). |
| **Semantics** | Addressed | Decision Clarity card, settlement success, expense Submit, Back to Group; more screens in follow-up. |
| **Locale** | Addressed | formatMoneyWithCurrency uses device locale (intl); number words (lakh/crore) in parser (V4). |
| **Dead/orphan UI** | Addressed | DeleteGroup route removed from main; screen file kept for reference only. |

---

## 5. Summary

- **Critical (§1):** Fixed in code. Deploy Firestore rules (`firebase deploy --only firestore`) so creator-only group delete takes effect. DeleteGroup route removed.
- **High (§2):** Addressed (a11y, route args, MemberChange, InviteMembers null-group).
- **Remaining (non-blocking):** See §6 below. Plan or accept as documented.

After addressing §1 and deploying rules, the app is in good shape for a controlled release. §6 items are follow-ups for the next iteration.

---

## 6. Other gaps (documented elsewhere; not blocking)

These are tracked in V4_TESTING_ISSUES, STABILIZATION, or APP_BLUEPRINT. No code change required for publish unless you decide to prioritize.

| Gap | Where | Notes |
|-----|--------|--------|
| **G7 Date as string / timezone** | V4_TESTING_ISSUES G7, STABILIZATION §5 | Expense `date` is human string; timezone-fragile. Needs schema + migration to fix. |
| **G8 No pagination** | V4_TESTING_ISSUES G8, STABILIZATION §5 | Groups, expenses, history load in full. Add when scale demands. |
| **G4 Integer-amounts migration** | V4_TESTING_ISSUES G4, PRE_RELEASE §3.3 | Phase 1 done; double paths remain. Backfill + Phase 2 when touching amounts broadly. |
| **G9 Settlement test coverage** | V4_TESTING_ISSUES G9 | Payer/participant not in member list, large-number overflow not covered by tests. Add when touching settlement logic. |
| **Design token consistency** | PRE_RELEASE §3.4 | Some screens use hardcoded fontSize/colors. Gradual pass to use design tokens. |
| **Loading/error UX** | PRE_RELEASE §3.5 | Ensure every async flow has clear message + retry/back. Mostly in place. |
| **Assumed invariants** | STABILIZATION §4.3 | #6 members vs pendingMembers; #12 encryption keys — assumed, not enforced. Accept or add checks later. |
