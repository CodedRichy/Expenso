# Expenso — App Blueprint

**Use this as the primary reference for all future logic and UI changes.**

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
| `/group-detail` | GroupDetail | Group name, **28px** pending amount, expense log, “Add expense”, **Settle** in AppBar, close cycle. |
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
| **Cycles** | `_cycles`, `getActiveCycle`, `getExpenses`, `addExpense`, `updateExpense`, `deleteExpense`, `settleAndRestartCycle`, `getHistory`. |
| **Balances** | `calculateBalances`, `getSettlementInstructions` (uses `getMemberDisplayName`). |
| **Authority** | `isCreator(groupId, userId)`, `canEditCycle(groupId, userId)`, `canDeleteGroup(groupId, userId)`. |

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

### God Mode — Settle (GroupDetail)

- AppBar has a **Settle** action. Use `repo.isCreator(groupId, repo.currentUserId)`.

**If leader:**

1. Show **“Settle & Restart”**.
2. On tap → dialog with `repo.getSettlementInstructions(groupId)`.
3. On Confirm → `repo.settleAndRestartCycle(groupId)` (cycle resets to ₹0).

**If member:**

- Show **“Request Settlement”**. On tap → snackbar: “Request sent to group leader.”

**If group already settled:** Hide the Settle action.

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

*Keep this file updated when adding routes, screens, design tokens, or repository contracts.*
