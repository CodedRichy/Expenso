# Expenso — App Blueprint

**Use this as the primary reference for all future logic and UI changes.**

**Sections 1–8** describe the **current implementation** (what is built and live).  
**Section 9** lists **planned features** (not implemented yet), grouped into three suites for later prioritization.

---

## Table of contents

1. [App overview](#1-app-overview)
2. [Entry and auth flow](#2-entry-and-auth-flow)
3. [Routes and screens](#3-routes-and-screens)
4. [Data layer](#4-data-layer)
5. [Design system](#5-design-system)
6. [Key logic conventions](#6-key-logic-conventions)
7. [File layout](#7-file-layout)
8. [Dependencies](#8-dependencies)
9. [Planned features (not implemented)](#9-planned-features-not-implemented)

---

## 1. App overview

| | |
|---|---|
| **Name** | Expenso |
| **Purpose** | Track shared expenses in groups with automatic settlement cycles. |
| **Stack** | Flutter (Dart), Material 3. |

---

## 2. Entry and auth flow

**Initial route:** `/`

The home route is a `ListenableBuilder` on `CycleRepository.instance`. Which screen shows depends on repo state:

| Condition | Screen |
|-----------|--------|
| `currentUserPhone.isEmpty` | **PhoneAuth** |
| Phone set, `currentUserName.isEmpty` | **OnboardingNameScreen** |
| Both set | **GroupsList** |

**PhoneAuth** — User enters +91 phone → OTP. On success: `CycleRepository.instance.setGlobalProfile(formattedPhone, '')`. No navigation; home rebuilds and shows onboarding or groups.

**OnboardingNameScreen** — “What should we call you?” → user taps “Get Started” → `setGlobalProfile(repo.currentUserPhone, name)`. Home rebuilds and shows GroupsList.

---

## 3. Routes and screens

### Core

| Route | Screen | Notes |
|-------|--------|--------|
| `/` | PhoneAuth / OnboardingName / GroupsList | Decided by repo state (see §2). |
| `/groups` | GroupsList | List of groups. **Only the black FAB** creates a group (no blue text button). |
| `/create-group` | CreateGroup | New group → then InviteMembers. |
| `/invite-members` | InviteMembers | Add by phone/name; contact suggestions via `flutter_contacts` (import as `fc`). |
| `/group-detail` | GroupDetail | Group name, **28px** pending amount, **Settle now** + **Pay via UPI** in body (when pending > 0), expense log, “Add expense”. |
| `/expense-input` | ExpenseInput | One field (e.g. “Dinner 1200 with”); Who paid? Who’s involved; **NLP** auto-selects participants by typed names. |

### Expense and members

| Route | Screen | Notes |
|-------|--------|--------|
| `/edit-expense` | EditExpense | Args: `expenseId`, `groupId`. |
| `/undo-expense` | UndoExpense | Undo last expense. |
| `/group-members` | GroupMembers | List / edit members. |
| `/member-change` | MemberChange | Change one member. |
| `/delete-group` | DeleteGroup | Confirm delete. |

### Settlement and history

| Route | Screen | Notes |
|-------|--------|--------|
| `/settlement-confirmation` | SettlementConfirmation | Confirm settlement. |
| `/payment-result` | PaymentResult | After payment. |
| `/cycle-settled` | CycleSettled | Cycle settled. |
| `/cycle-history` | CycleHistory | Past cycles. |
| `/cycle-history-detail` | CycleHistoryDetail | One past cycle. |

### Utility

| Route | Screen |
|-------|--------|
| `/empty-states` | EmptyStates |
| `/error-states` | ErrorStates |

---

## 4. Data layer

### CycleRepository

**Location:** `lib/repositories/cycle_repository.dart`  
**Type:** Singleton, `ChangeNotifier`.

| Area | Details |
|------|---------|
| **Identity** | `currentUserId`, `currentUserPhone`, `currentUserName`. `setGlobalProfile(phone, name)` updates and notifies. |
| **Groups** | `_groups`, `addGroup`, `getGroup`, `getMembersForGroup`, `removeMemberFromGroup`, … |
| **Members** | `_membersById`. Creator in `addGroup` gets `currentUserName`. |
| **Display names** | `getMemberDisplayName(phone)` → current user: `currentUserName` or “You”; others: member name or formatted phone. |
| **Cycles** | `_cycles`, `getActiveCycle`, `getExpenses`, `addExpense`, `updateExpense`, `deleteExpense`, `settleAndRestartCycle` (Phase 1: freeze → settling), `archiveAndRestart` (Phase 2: close + new cycle), `getHistory`. |
| **Balances** | `calculateBalances`, `getSettlementInstructions` (uses `getMemberDisplayName`). |
| **Authority** | `isCreator(groupId, userId)`, `canEditCycle(groupId, userId)` (false when cycle is **settling** for everyone, including leader), `canDeleteGroup(groupId, userId)`. |

### Models

**Location:** `lib/models/`

- **models.dart** — `Group`, `Member`, `Expense`, `ExpenseItem`, `HistoryCycle`
- **cycle.dart** — `CycleStatus` (active, settling, closed), `Cycle`

---

## 5. Design system

### Colors

| Role | Value | Use |
|------|--------|-----|
| Background | `0xFFF7F7F8` | Scaffold (light gray). |
| Primary / text | `0xFF1A1A1A` | Headlines, body. |
| Secondary | `0xFF6B6B6B` | Body, labels. |
| Muted / hints | `0xFF9B9B9B`, `0xFFB0B0B0` | Hints, disabled. |
| Borders | `0xFFE5E5E5`, `0xFFD0D0D0` | Dividers, inputs. |
| Links / secondary actions | `0xFF5B7C99` | TextButton, links. |

### Typography

| Use | Size | Weight | LetterSpacing |
|-----|------|--------|---------------|
| Large titles (e.g. “Groups”) | 34px | w600 | -0.6 |
| Screen titles, **pending amount** | 28px | w600 | -0.5 |
| Body | 17px | — | — |
| Labels / small | 15px | — | — |
| Overlines (e.g. “EXPENSE LOG”) | 13px | w500 | 0.3 |

### Components

- **Primary buttons** — Background `0xFF1A1A1A`, white text, `borderRadius: 8`, elevation 0.
- **FAB** — Same; e.g. GroupsList uses 14px radius.
- **Inputs** — White fill, 8px radius, borders as above; focused border `0xFF1A1A1A`.
- **Empty states** — Centered copy, same palette; primary CTA = primary button style.

---

## 6. Key logic conventions

### Action hierarchy (GroupsList)

- The **black FAB** is the only way to create a group.
- Do **not** add a blue “Create Group” text button.
- Empty state CTA may still navigate to create-group.

### Settlement — Passive state (Freeze before Wipe) & God Mode (GroupDetail)

- **CycleStatus:** `active` → **settling** (Phase 1: freeze) → **closed** + new active (Phase 2: archive & restart).
- **Phase 1 — Freeze:** “Settle now” (leader) → dialog with `getSettlementInstructions` → on Confirm call `repo.settleAndRestartCycle(groupId)`. This only sets the current cycle to `CycleStatus.settling`; no new cycle yet. **Phase 2 — Archive & Restart:** When cycle is **settling** (passive), show “Start New Cycle” button; on tap call `repo.archiveAndRestart(groupId)` to close the settling cycle and create a new active cycle at ₹0.
- **Passive state (`isPassive = activeCycle.status == CycleStatus.settling`):** Amount and status use muted gray (0xFF9B9B9B); status text “Cycle Settled - Pending Restart”. Hide “Add expense” row. Disable expense log item taps (no navigation to edit). “Pay via UPI” remains visible. Only “Start New Cycle” performs the wipe.
- **Permissions:** `canEditCycle` returns false when cycle is **settling** for everyone (including leader). Edit screen and add expense are read-only / hidden.
- **If member:** “Settle now” → snackbar “Request sent to group leader.”
- **“Pay via UPI”** (secondary): navigates to settlement-confirmation. Design: primary button black, borderRadius 8, no elevation; balanced vertical padding before Expense Log.

### Phone format

- Store/display as `+91 XXXXX XXXXX` (10 digits).
- Normalize to digits (e.g. last 10) when needed.

### Expense parsing (ExpenseInput)

- Amount: first `[\d,]+`, then strip commas and parse.
- Description / “with” used for participants.
- Submit enabled when `input.trim().isNotEmpty` and `parseExpense(input).amount > 0`.

### NLP — Who’s involved (ExpenseInput)

- As the user types, match input (words or substrings, case-insensitive) to each member’s **display name** (`getMemberDisplayName`).
- When a name is found, add that member’s phone to the “Who’s involved” set so checkboxes auto-check.
- Implement in `_syncSelectedMembersFromInput(Group)` and call from the TextField `onChanged`.

### Smart description (GroupDetail expense log)

- **No participants:** Append current user name or “Just you” only if not already in the description (case-insensitive).
- **With participants:** Append “— with X, Y” only for names **not** already in the description (case-insensitive). Use `repo.getMemberDisplayName(phone)` for names.

### flutter_contacts (InviteMembers)

- Import: `import 'package:flutter_contacts/flutter_contacts.dart' as fc;`
- Use `fc.Contact`, `fc.FlutterContacts` only. Never use unqualified `Group` (clashes with app model).

---

## 7. File layout

```
lib/
  main.dart                    # Routes, initial route logic
  models/
    models.dart                # Group, Member, Expense, ExpenseItem, HistoryCycle
    cycle.dart                 # Cycle, CycleStatus
  repositories/
    cycle_repository.dart      # Singleton (groups, members, cycles, expenses, identity)
  screens/
    phone_auth.dart
    onboarding_name.dart
    groups_list.dart
    create_group.dart
    invite_members.dart
    group_detail.dart
    expense_input.dart
    edit_expense.dart
    undo_expense.dart
    group_members.dart
    member_change.dart
    delete_group.dart
    settlement_confirmation.dart
    payment_result.dart
    cycle_settled.dart
    cycle_history.dart
    cycle_history_detail.dart
    empty_states.dart
    error_states.dart
```

---

## 8. Dependencies

| Package | Notes |
|---------|--------|
| `flutter` | SDK. |
| `cupertino_icons` | Icons. |
| `flutter_contacts` ^1.1.9+1 | Import as `fc` to avoid `Group` clash. |

**Permissions:**

- **Android:** `READ_CONTACTS`
- **iOS:** `NSContactsUsageDescription` in Info.plist

---

## 9. Planned features (not implemented)

The following are **not built yet**. Each feature has a **verdict**, **why it matters**, and **when to add** so you can come back later and implement in the right order.  
**Status** = Not implemented until you ship it.

---

### 9.1 “Polished Local” suite (no server)

**Suite verdict:** ✅ **YES — do selectively.** Best pre-backend, pre-AI upgrades. This is where you win early.

| Feature | Verdict | When to add | Status |
|--------|---------|-------------|--------|
| **Receipt attachments** | ✅ Must-have polish | After settlement math, before Firebase. | Not implemented |
| **Dynamic UPI QR generator** | 🔥 Differentiator (India hit) | Early; no backend needed. Amount from your logic. | Not implemented |
| **Category intelligence** | ✅ Add later, keep dumb | After receipts/QR. Simple keyword → category map; don’t overdo NLP. | Not implemented |
| **Smart “nudge” templates** | ✅ Good — tone matters | Opt-in only. Don’t automate sending or nag. e.g. “₹2,480 pending. Settlement: Sunday.” | Not implemented |
| **Biometric lock** | ⏳ Nice-to-have, not urgent | After core flow is solid. Adds friction if too early; good for trust/credibility. | Not implemented |

**Implementation notes (Polished Local):**

- **Receipt attachments** — Ends arguments, reduces friction. Zero backend at first (local/file-based). High value.
- **Dynamic UPI QR** — Killer in India. Faster than links; amount from your engine. Makes “Pay now” feel real. Do before Firebase.
- **Category intelligence** — Icons (🍔 🚗 🏠) from keywords. Cosmetic but improves scan speed and perceived quality. Keep logic simple.
- **Nudge templates** — Funny/ruthless options only if optional. System reminder tone is safer. Aligned with “calm” philosophy.
- **Biometric lock** — Privacy/pro feel. Low–medium value for money awkwardness; do when you want premium trust, not in MVP.

---

### 9.2 “Cloud Power” suite (backend phase)

**Suite verdict:** ✅ **YES — only after local logic is rock-solid.** Backend-dependent and complex.

| Feature | Verdict | When to add | Status |
|--------|---------|-------------|--------|
| **Real-time “join” notifications** | ✅ High value | Phase 2. Needs auth, push, backend identity. Add too early = chaos. | Not implemented |
| **Live activity feed** | ⚠️ Only if subtle | After join notifications. Risk: noise, notification fatigue, anxiety. Keep calm. | Not implemented |
| **Cross-group identity** | 🔥 Long-term core | Backend + stable member identity. Unlocks debt minimization later. Very high value. | Not implemented |
| **Cloud backup & sync** | ✅ Mandatory (boring) | Required once you leave MVP. Non-negotiable; users assume it. | Not implemented |

**Implementation notes (Cloud Power):**

- **Join notifications** — When you add “Pradhyun” by contact, he gets a push to join. High value, Phase 2.
- **Live activity feed** — “Rekha added Dinner” in real time. Feels social but can feel like Splitwise noise. Only if subtle and calm.
- **Cross-group identity** — Net balance across all groups with same person. Invisible at first, huge later. Foundation for God Mode math.
- **Cloud backup & sync** — Not exciting; required. Do when you leave MVP.

---

### 9.3 “AI & Hit-Maker” suite (final vision)

**Suite verdict:** ⚠️ **Dangerous if rushed; massive if timed right.** Many apps die here by overpromising.

| Feature | Verdict | When to add | Status |
|--------|---------|-------------|--------|
| **Bill splitting via camera (OCR)** | 🚫 Do NOT touch early | After everything else works. Not MVP, not Phase 2. OCR + item–person matching = support nightmare. | Not implemented |
| **Voice command entry** | ❌ Skip or postpone | Low real usage. Accent/noise/debug pain. Sounds cool, rarely used. | Not implemented |
| **Debt minimization (“God Mode” math)** | 🔥 Signature feature | After cross-group identity. A owes B, B owes C → A pays C. Saves money, fewer txns, feels magical. | Not implemented |
| **Spending insights** | ⚠️ Optional, tone-sensitive | If done wrong, feels like a finance app and breaks “calm.” Useful but can feel preachy. | Not implemented |

**Implementation notes (AI & Hit-Maker):**

- **Bill splitting via OCR** — One photo, AI items, drag onto people. Very high risk: accuracy, edge cases, support. Do last.
- **Voice entry** — “Hey Expenso, I paid 400 for movies with the boys.” Low real value; skip or postpone indefinitely.
- **Debt minimization** — Real intelligence. Builds on members, balances, cross-group identity. Can be your signature feature. Extremely high value.
- **Spending insights** — “Rishi, 20% more on travel this month. Time to settle up!” Medium value; tone matters.

---

### Suggested implementation order (when you return)

1. **Polished Local (selective):** Receipt attachments → Dynamic UPI QR → (optional) Category intelligence → Nudge templates → (later) Biometric lock.
2. **Cloud (after local is solid):** Cloud backup & sync → Real-time join notifications → Cross-group identity → (optional, subtle) Live activity feed.
3. **AI / Hit-Maker (last):** Debt minimization (“God Mode” math) → (optional) Spending insights. Skip or defer OCR and voice.

---

*When you add features or change the app: update **APP_BLUEPRINT** (sections 1–8) and **README.md**. When you implement a feature in §9, change its Status and add a one-line “Implemented in …” if helpful.*
