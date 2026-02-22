# Expenso V1 Release Document

**Lead Product Engineering · V1 Lock**  
This document formalizes the core identity of Expenso as an AI-driven group expense manager at the V1 release boundary. It serves as the single source of truth for product and engineering decisions that define “what V1 is” and “what V1 is not.”

---

## 1. The 'Magic Bar' Standard

The Magic Bar is the primary natural-language input for expenses. Its behavior is governed by a **contract** that ensures reliability and safety regardless of input quality or API availability.

### 1.1 NLP Contract

- **Fragments and typos**  
  The parser must accept fragmentary or misspelled input and normalize it to a clear, title-case description (1–3 words). A defined fragment map covers common abbreviations (e.g. `dinr` → Dinner, `ght` + next word → that word, `cff` → Coffee, `tkt` → Tickets). If nothing meaningful can be inferred, the description MUST fall back to `"Expense"`. The amount MUST still be extracted when possible.

- **Fuzzy name matching**  
  Names in the user message are matched to the group member list with:
  - **Exact match** (case-insensitive): use as-is; no user verification required.
  - **Single partial match** (e.g. substring, nickname): treat as a **guess**; the confirmation UI MUST surface it for verification (e.g. highlighted or “?”) so the user can correct before confirm.
  - **Ambiguous or no match**: slot is left as “Select Member”; the user MUST choose before confirming.  
  The AI may output the best-guess spelling from the member list; the app resolves to phone and flags guesses so the user never commits an expense to the wrong person without seeing it.

- **Sacred Amount fallback**  
  The **amount** is the one field that must never be wrong at persist time:
  - **Validation before persist:** `validateExpenseAmount(amount)` rejects `NaN`, `<= 0`, and invalid numbers. No expense is written with an invalid amount.
  - **Parser fallback:** If the AI fails (network, rate limit, malformed JSON, or amount missing/invalid in the response), the flow MUST fall back to **local number extraction** from the raw user input (e.g. first number in text, supporting “500”, “1,200”, “₹500”). If that yields a valid positive number, a minimal `ParsedExpenseResult` (amount + description from input or “Expense”) is returned so the Magic Bar “never fails as long as a number is typed.”
  - **Confirmation gate:** The user always sees amount, description, and participants before confirming. If validation fails on confirm (e.g. edge case), the app MUST show a SnackBar and MUST NOT crash.

- **No input shall crash the app**  
  All parser paths (API success, API failure, fallback parse, JSON decode errors, `fromJson` errors) MUST either return a valid result or throw a catchable, user-friendly error. The UI MUST catch these (and `ArgumentError` from the repository) and surface a message (e.g. “Couldn’t parse that. Try a clearer format like ‘Dinner 500’.”) or “Invalid expense.”) without terminating the app.

### 1.2 Summary

| Requirement              | Behavior |
|---------------------------|----------|
| Fragments / typos         | Normalize to 1–3 word description; fallback description “Expense”. |
| Fuzzy name match          | Single partial → guess, shown in confirmation for verification. |
| Sacred Amount             | Validate before persist; fallback to local number extraction when AI fails. |
| No crash                  | All errors caught; user-friendly message or fallback result. |

---

## 2. The 'Decision Clarity' UI

The group detail screen is built around a **Decision Clarity** summary so the user immediately understands cycle state and their own position.

### 2.1 Summary Card Architecture

- **Placement**  
  The summary is the primary “header” content below the compact top bar (back, group name, members). It is a single, prominent card; no competing totals above the fold.

- **Background and weight**  
  The card uses a **Container** with:
  - A subtle **linear gradient** (e.g. Deep Navy → Slate) and rounded corners.
  - A **BoxShadow** to give it visual weight and separation from the background.

- **Three metrics (when the cycle has expenses)**  
  1. **Total Spend (Cycle Total)**  
     Sum of all expense amounts in the active cycle. Displayed as the headline: e.g. `Cycle Total: ₹X`.  
  2. **Personal Spend (Spent by You)**  
     Sum of expenses where the current user is the payer. Displayed in a 50/50 row, left side: e.g. `Spent by You: ₹Y`.  
  3. **Net Balance (Your Status)**  
     Current user’s net from the SettlementEngine (credit vs. debt). Displayed in the same row, right side: e.g. `Your Status: ±₹Z`.  
     - **Color coding:** `Colors.greenAccent` for credit (positive or zero), `Colors.redAccent` for debt (negative).  
  Data source: **SettlementEngine.computeNetBalances** and **CycleRepository** (expenses for the active cycle). No derived or duplicated logic; the card reads from the same engine as the Balances section.

- **Empty state**  
  When there are no expenses in the cycle, the card MUST show a **Zero-Waste Cycle** message and a short prompt to add expenses via the Magic Bar or manual entry. The card retains a **minimum height** so layout does not jump when the first expense is added.

- **Stability**  
  The card MUST NOT “jump” when data loads or when switching between empty and non-empty. Use a **minimum height** and, where appropriate, **AnimatedSwitcher** (or equivalent) for the inner content so transitions are smooth and predictable.

---

## 3. The Authority Model

Expenso uses a **single-owner** model per group to avoid ambiguity over who can close cycles and perform destructive actions.

### 3.1 Creator Crown

- **One creator per group**  
  The group has a single creator (the user who created the group). The creator is identified in the UI (e.g. crown icon 👑 next to their name in Group Members).

- **Creator-only actions**  
  - **Settle & Restart** (close cycle and start a new one).  
  - **Start New Cycle** (after a cycle is in “Settling” state).  
  - **Delete Group** (permanent; confirm dialog required).  
  Non-creators can add/edit expenses and view balances; they cannot settle, restart, or delete the group. The UI MUST hide or disable these actions for non-creators and show clear feedback (e.g. “Only the group creator can start a new cycle.”).

### 3.2 Destructive Action Permissions

- **Delete Group** is **creator-only**. Swipe-to-delete (or equivalent) on the group list MUST be shown only for the current user when they are the creator. Any delete path MUST check `isCurrentUserCreator(groupId)` before allowing the action and MUST require an explicit confirmation dialog describing permanence (group and expense history).

- **Settle / Start New Cycle** are **creator-only**; they change group and cycle state and archive data. Non-creators may see “Pay via UPI” and settlement instructions for their own use but cannot trigger the cycle-state transition.

---

## 4. The Math Engine

The **SettlementEngine** is the single source of truth for “who owes whom” and “what is my net position.”

### 4.1 Formal Specification

- **Inputs**  
  - List of **Expenses** (each with payer, amount, and split: equal or exact per participant).  
  - List of **Members** (identified by phone; used to scope who is in the settlement).

- **Net balance**  
  For each member (by phone), **net = Total Paid − Total Owed**:
  - Total Paid: sum of `expense.amount` for expenses where `expense.paidByPhone == member.phone`.
  - Total Owed: from each expense, the member’s share (from `splitAmountsByPhone` if present, else equal split among `participantPhones`).  
  Only members in the provided list are included. All others are ignored for net and debt computation.

- **Debt list (who owes whom)**  
  From the net balances:
  - **Debtors:** members with net < −ε (they owe money).  
  - **Creditors:** members with net > ε (they are owed money).  
  A small **tolerance** (e.g. 0.01) is used to avoid floating-point dust.

### 4.2 Minimum Debt Path (Greedy Algorithm)

The engine produces a **minimum number of debt edges** (transfers) by:

1. **Sort** debtors by amount owed (largest first) and creditors by amount owed (largest first).
2. **Match** in order: repeatedly take the current largest debtor and largest creditor; create a **Debt(fromPhone, toPhone, amount)** where `amount = min(debtor.amount, creditor.amount)`; subtract that amount from both; advance to the next debtor or creditor when their remaining amount is below tolerance.
3. **Output** the list of **Debt** records. This is the set of “A owes B ₹X” instructions shown in the Balances section and used for settlement.

This greedy approach minimizes the number of transactions (minimum debt path) while preserving exact net balances. The same net balances are exposed via **computeNetBalances** for the Decision Clarity card (e.g. “Your Status”).

---

## 5. The Quality Bar

V1 defines a set of **micro-interactions and stability guarantees** that are part of the product contract.

### 5.1 Required Micro-Interactions

- **Haptic feedback**  
  - **Light impact** on every **AI parse success** (when the Magic Bar returns a result and the confirmation dialog is about to be shown).  
  - **Light impact** on **manual confirm** (when the user taps Confirm in the expense confirmation dialog and the expense is persisted).  
  - **Light impact** on **swipe actions** (e.g. Pin/Unpin and Delete on the group list Slidable).  
  This gives consistent tactile confirmation for “action accepted.”

- **Layout stability**  
  - The Decision Clarity card MUST NOT jump or resize abruptly when data loads or when switching between empty and non-empty state. Use a **placeholder or minimum height** and, where appropriate, **AnimatedSwitcher** (or equivalent) for content transitions so the user does not experience a visible “pop” or reflow.

### 5.2 Summary

| Interaction / guarantee | Requirement |
|------------------------|-------------|
| Haptic on AI success   | `HapticFeedback.lightImpact()` before showing confirm dialog. |
| Haptic on manual confirm | `HapticFeedback.lightImpact()` on Confirm tap in expense dialog. |
| Haptic on swipe        | Light impact when Pin/Unpin or Delete is triggered. |
| Card stability         | Min height + AnimatedSwitcher (or similar) for card content. |

---

## 6. The Philosophy

V1 prioritizes **financial trust** and **cognitive ease** over social and engagement features.

- **Financial trust**  
  The app must feel reliable with money: correct math (SettlementEngine), clear ownership (Creator Crown), and no ambiguous edits (single creator for settle/delete). The **Sacred Amount** and validation ensure we never persist invalid amounts. Balances and “Your Status” are derived from one engine and one cycle, so the user can trust what they see.

- **Cognitive ease**  
  The user should understand “what is the total,” “what did I spend,” and “am I owed or do I owe” in one glance (Decision Clarity card). Input should be low-friction (Magic Bar with fragments and fuzzy names) without requiring perfect grammar or spelling. Confirmation and guess-highlighting keep the user in control without overwhelming them.

- **What we deferred**  
  We explicitly did **not** prioritize profile pictures, rich social identity, or engagement mechanics in V1. The product is about **getting the numbers right** and **making the next decision obvious**, not about looking good or staying in the app longer. This keeps scope and risk manageable and aligns the first release with “trust and clarity first.”

---

## 7. V2 Roadmap (The “Not Now” List)

The following are **out of scope for the V1 lock**. They are acknowledged as valuable for a future version but are not part of the V1 contract or design.

| Item | Notes |
|------|--------|
| **Profile pictures** | User avatars or photos in the app; deferred in favor of identity via name/phone and trust/clarity. |
| **UPI deep-linking** | Opening UPI apps with pre-filled payee/amount from settlement instructions; V1 may show instructions only. |
| **Push notifications** | Reminders, “X added an expense,” or settlement nudges; not required for V1. |

No V1 behavior or UI should **depend** on these. They may be revisited in a dedicated V2 plan.

---

## Document Control

- **Version:** 1.0  
- **Status:** V1 Lock  
- **Audience:** Product, Engineering, and anyone defining or implementing “Expenso V1.”  
- **Updates:** Changes to this document after V1 lock should be explicitly versioned and communicated, as they may affect the release boundary.
