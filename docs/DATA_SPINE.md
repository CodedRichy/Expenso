# Expenso Data Spine

**Purpose:** Formal definition of core domain entities  
**Scope:** Conceptual locking — no refactors proposed

---

## Overview

This document defines the fundamental data structures that Expenso operates on. Each entity is classified by its semantic role (event, state, or derived view) and its ideal mutability. This spine serves as a reference for understanding data ownership and identifying areas requiring extra care.

---

## Entity Classification Key

| Type | Definition |
|------|------------|
| **Event** | An immutable record of something that happened. Append-only. Never edited or deleted in an ideal system. |
| **State** | A mutable snapshot of current reality. Can be updated. Represents "what is true now." |
| **Derived View** | Computed from other entities. Not stored. Recalculated on demand. |

---

## Core Domain Entities

### 1. User

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | State |
| **Ideal Mutability** | Mutable |
| **Primary Storage** | Firestore `users/{uid}` |
| **Local Cache** | SharedPreferences via `UserProfileCache` |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Firebase Auth UID |
| `phone` | `String` | Primary identifier for invitations |
| `displayName` | `String` | User-settable name |
| `photoURL` | `String?` | Avatar URL (Firebase Storage) |
| `upiId` | `String?` | Payment identifier |

**Notes:** User represents the authenticated identity. Changes (name, avatar, UPI) are legitimate state updates. Phone number is effectively immutable once set (changing it breaks identity linkage).

**Local Cache:** The current user's profile is cached locally in `SharedPreferences` via `UserProfileCache`. On cold start, `main()` loads this cache **before** Firebase Auth resolves, enabling instant profile avatar rendering. The cache syncs whenever Firestore data is fetched and clears on logout. Other users' profiles are not cached locally.

---

### 2. Group

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | State |
| **Ideal Mutability** | Mutable |
| **Storage** | Firestore `groups/{groupId}` |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Unique group identifier |
| `name` | `String` | Display name |
| `creatorId` | `String` | UID of group owner |
| `memberIds` | `List<String>` | Current members (UIDs) |
| `pendingMembers` | `List<{phone, name}>` | Invited but not joined |
| `activeCycleId` | `String` | Current expense cycle |
| `cycleStatus` | `String` | `'active'` or `'settling'` |
| `settlementRhythm` | `String?` | Optional schedule hint |
| `settlementDay` | `int?` | Optional schedule day |

**Notes:** Group is legitimately mutable (members join/leave, cycles progress). The `creatorId` should be immutable after creation.

**⚠️ Overload detected:** Group currently carries both organizational state (members, name) and cycle coordination state (activeCycleId, cycleStatus). These are distinct concerns.

---

### 3. Expense

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Event |
| **Ideal Mutability** | **Immutable** |
| **Storage** | Firestore `groups/{groupId}/expenses/{expenseId}` |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Unique expense identifier |
| `description` | `String` | What was purchased |
| `amount` | `double` | Total cost |
| `date` | `String` | When it occurred |
| `paidById` | `String` | Who paid (UID) |
| `participantIds` | `List<String>` | Who owes |
| `splitAmountsById` | `Map<String, double>?` | Per-person amounts |
| `splitType` | `String` | `'Even'`, `'Exact'`, `'Exclude'`, etc. |
| `category` | `String` | Optional categorization |

**💰 MONEY TRUTH:** This entity records financial facts. Changes directly affect what people owe.

**✅ Append-only model implemented:** Edits and deletions use compensation events (negate original + append replacement), preserving full audit history. See [EXPENSE_REVISIONS.md](features/EXPENSE_REVISIONS.md) for details.

**Notes:** An expense represents "Person A paid X for Y, split among Z." This is fundamentally an event — it happened. The compensation model ensures corrections are separate events, not overwrites.

---

### 4. Cycle

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | State (active) / Event (closed) |
| **Ideal Mutability** | Mutable while active; **Immutable when closed** |
| **Storage** | Active: `groups/{groupId}` fields; Closed: `groups/{groupId}/settled_cycles/{cycleId}` |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Unique cycle identifier |
| `groupId` | `String` | Parent group |
| `status` | `CycleStatus` | `active`, `settling`, `closed` |
| `startDate` | `String?` | When cycle began |
| `endDate` | `String?` | When cycle closed |
| `expenses` | `List<Expense>` | In-memory only; expenses stored separately |

**Notes:** A cycle is a container for expenses within a settlement period. Active cycles accept new expenses; settling cycles are frozen for payment; closed cycles are historical record.

**⚠️ Overload detected:** Cycle has a dual nature — it's mutable state while active but should become an immutable historical record when closed. The transition is one-way but not enforced at the data layer.

---

### 5. Member

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Derived View |
| **Ideal Mutability** | N/A (computed) |
| **Storage** | In-memory cache (`_membersById`) |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | UID or `p_{phone}` for pending |
| `phone` | `String` | Contact identifier |
| `name` | `String` | Display name |
| `photoURL` | `String?` | Avatar |

**Notes:** Member is a view combining User data with group membership context. It's assembled from `users/{uid}` documents and group `pendingMembers` arrays. Not independently stored as a first-class entity.

---

### 6. GroupInvitation

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | State (transient) |
| **Ideal Mutability** | Immutable (accept/decline deletes it) |
| **Storage** | Derived from `groups/{groupId}.pendingMembers` + `pendingPhones` |

| Field | Type | Notes |
|-------|------|-------|
| `groupId` | `String` | Target group |
| `groupName` | `String` | For display |
| `creatorId` | `String` | Who invited |

**Notes:** Represents a pending invitation. Not a first-class document — derived from group's pending arrays. Accepting promotes user to member; declining removes from pending.

---

### 7. SystemMessage

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Event |
| **Ideal Mutability** | **Immutable** |
| **Storage** | Firestore `groups/{groupId}/system_messages/{msgId}` |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Unique message identifier |
| `type` | `String` | `'joined'`, `'declined'`, `'left'`, `'created'` |
| `userId` | `String` | Who performed action |
| `userName` | `String` | Display name at time of action |
| `date` | `String` | Human-readable date |
| `timestamp` | `int` | Milliseconds since epoch |

**Notes:** Activity feed entries. Correctly implemented as append-only events. The `userName` is denormalized (snapshot at creation time) to preserve historical accuracy.

---

### 8. SettlementEvent

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Event |
| **Ideal Mutability** | **Immutable** |
| **Storage** | Firestore `groups/{groupId}/settlement_events/{eventId}` |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Unique event identifier (`se_{timestamp}`) |
| `type` | `String` | `'cycle_settlement_started'`, `'payment_initiated'`, `'payment_confirmed_by_payer'`, `'payment_confirmed_by_receiver'`, `'payment_disputed'`, `'cycle_archived'` |
| `amountMinor` | `int?` | Payment amount in minor units (for payment events) |
| `timestamp` | `int` | Milliseconds since epoch |
| `paymentAttemptId` | `String?` | Reference to related PaymentAttempt |

**Notes:** Read-only activity feed for settlement progress. Append-only, no user names stored (neutral system voice). Events are logged automatically by CycleRepository when payment status changes or cycle state transitions occur.

---

### 9. Debt

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Derived View |
| **Ideal Mutability** | N/A (computed) |
| **Storage** | In-memory only |

| Field | Type | Notes |
|-------|------|-------|
| `fromId` | `String` | Debtor UID |
| `toId` | `String` | Creditor UID |
| `amount` | `double` | Amount owed |

**💰 MONEY TRUTH:** This entity represents computed financial obligations. Derived from Expense records.

**Notes:** Computed by `SettlementEngine.computeDebts()`. Represents the minimal set of transfers needed to settle all balances. Never stored — always recalculated from expenses.

---

### 8b. PaymentRoute

| Attribute | Value |
|-----------|-------|
| **Name** | PaymentRoute |
| **Mutability** | Immutable (derived) |
| **Storage** | Memory only (computed by SettlementEngine) |

| Field | Type | Notes |
|-------|------|-------|
| `fromMemberId` | `String` | Payer UID |
| `toMemberId` | `String` | Recipient UID |
| `amount` | `MoneyMinor` | Amount in minor units |

**💰 MONEY TRUTH:** Represents a computed payment instruction. Derived from net balances using greedy debt minimization.

**Notes:** Computed by `SettlementEngine.computePaymentRoutes()`. Returns minimal payment instructions to settle all balances. Use `getPaymentsForMember()` to filter to payments a specific member must make, or `getPaymentsToMember()` for incoming payments. Never stored — always recalculated.

---

### 10. SettlementTransfer

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Derived View |
| **Ideal Mutability** | N/A (computed) |
| **Storage** | In-memory only |

| Field | Type | Notes |
|-------|------|-------|
| `creditorPhone` | `String` | Who receives payment |
| `creditorDisplayName` | `String` | For display |
| `amount` | `double` | Amount to transfer |

**💰 MONEY TRUTH:** Represents a specific payment the current user should make.

**Notes:** A user-specific projection of Debt for the settlement UI. Computed by `getSettlementTransfersForCurrentUser()`.

---

### 11. NetBalance (implicit)

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Derived View |
| **Ideal Mutability** | N/A (computed) |
| **Storage** | In-memory only |

| Field | Type | Notes |
|-------|------|-------|
| `memberId` | `String` | UID |
| `balance` | `double` | Positive = credit, negative = debt |

**💰 MONEY TRUTH:** The fundamental "who owes what" calculation.

**Notes:** Computed by `SettlementEngine.computeNetBalances()`. This is the source of truth for the Decision Clarity card and Balances section. Sum across all members must equal zero.

---

## Entity Responsibility Analysis

### Entities with Multiple Responsibilities

| Entity | Responsibilities | Concern |
|--------|------------------|---------|
| **Group** | (1) Organizational container (name, members) (2) Cycle coordinator (activeCycleId, cycleStatus) | Two distinct concerns in one document. Cycle state changes frequently; group identity rarely. |
| **Cycle** | (1) Active expense container (2) Historical archive | Dual lifecycle — mutable while active, should be immutable when closed. No enforcement at data layer. |
| **Expense** | (1) Financial record (2) Editable user content | Resolved via compensation events — edits append negation + replacement, preserving audit trail. |

### Money Truth Entities

These entities directly affect financial calculations. Changes require extra care.

| Entity | Role | Risk |
|--------|------|------|
| **Expense** | Primary record | Edits change what people owe |
| **Expense.splitAmountsById** | Per-person amounts | Must sum to total (not enforced on read) |
| **NetBalance** | Derived totals | Logic errors cause wrong settlement amounts |
| **Debt** | Derived transfers | Algorithm errors cause wrong payment instructions |
| **SettlementTransfer** | User-facing payment | Incorrect display causes real-world payment errors |

---

## Data Flow Summary

```
User ─────────────────────────────────────┐
                                          │
Group ──┬── memberIds ────────────────────┼──► Member (derived)
        │                                 │
        ├── activeCycleId ──► Cycle ──────┤
        │                        │        │
        │                        ▼        │
        │                    Expense ─────┼──► NetBalance (derived)
        │                        │        │         │
        │                        │        │         ▼
        └── pendingMembers ──────┼────────┼──► Debt (derived)
                                 │        │         │
                                 ▼        │         ▼
                          SystemMessage   │   SettlementTransfer (derived)
                                          │
GroupInvitation (derived) ◄───────────────┘
```

---

## Intermediate Accounting Entities

### 11. NormalizedExpense

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Intermediate (accounting event) |
| **Ideal Mutability** | **Immutable** |
| **Storage** | In-memory only (transient during expense creation) |

| Field | Type | Notes |
|-------|------|-------|
| `total` | `MoneyMinor` | Total cost in minor units (positive integer) |
| `description` | `String` | Expense description (not validated, UI concern) |
| `category` | `String` | Optional categorization (not validated) |
| `date` | `String` | Date string (not validated) |
| `payerContributionsByMemberId` | `Map<String, MoneyMinor>` | Who paid how much (sum = total) |
| `participantSharesByMemberId` | `Map<String, MoneyMinor>` | Who owes how much (sum = total) |

**Design Principles:**
- **UI-agnostic:** No UI concepts (slots, selections, confirmation state)
- **Timeless:** Can be reconstructed from storage without current group state
- **Replay-safe:** Produces identical LedgerDeltas regardless of when computed
- **Integer-only:** All money values use `MoneyMinor` (no floating-point)
- **Single-currency:** All amounts in an expense use the same currency

**Money Invariants (enforced):**
- sum(payerContributions.amountMinor) == total.amountMinor (exact integer equality)
- sum(participantShares.amountMinor) == total.amountMinor (exact integer equality)
- All MoneyMinor instances share the same currencyCode
- All map keys are valid member IDs (no `p_` prefixes)

**Non-invariants (NOT validated):**
- Description content (UI concern)
- Category validity
- Date format

**Notes:** Canonical model for accounting events. All person references are member IDs (UUIDs), never names. "Everyone" semantics must be expanded to concrete IDs before construction.

---

### 12. LedgerDelta

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Derived View |
| **Ideal Mutability** | **Immutable** |
| **Storage** | In-memory only (computed on demand) |

| Field | Type | Notes |
|-------|------|-------|
| `memberId` | `String` | Member UID |
| `delta` | `MoneyMinor` | Balance change in minor units (+credit, -debit) |
| `expenseId` | `String` | Source expense identifier |
| `timestamp` | `DateTime` | When the expense occurred |

**💰 MONEY TRUTH:** Fundamental unit of balance computation. Sum of all deltas for an expense is exactly zero (integer arithmetic, no tolerance).

**Design Principles:**
- **UI-agnostic:** No UI concepts
- **Timeless:** Computed from stored data only, not current group state
- **Deterministic:** Same input always produces same output
- **Replay-safe:** Old expenses produce identical deltas regardless of membership changes
- **Integer-only:** Uses `MoneyMinor` for exact arithmetic

**Replay Safety Guarantee:**
The `expenseToLedgerDeltas()` function uses ONLY explicitly stored data (amountMinor, payerId, splitAmountsByIdMinor, currencyCode). It does NOT use current group membership, "everyone" semantics, or dynamic participant lists.

**Notes:** Pure derived view from NormalizedExpense or Expense. For each payer: +paidAmount. For each participant: -shareAmount. This is the atomic unit for Splitwise-style ledger accounting. Balances are computed by aggregating deltas, never stored directly.

---

### 13. Currency

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Metadata |
| **Ideal Mutability** | **Immutable** |
| **Storage** | Static registry in code |

| Field | Type | Notes |
|-------|------|-------|
| `code` | `String` | ISO 4217 currency code (e.g., "INR", "USD", "JPY") |
| `minorUnitScale` | `int` | Number of decimal places (0, 2, or 3) |

**Notes:** Currency metadata is declarative and drives all accounting behavior. Supported currencies include INR, USD, EUR, GBP (scale 2), JPY, KRW (scale 0), and KWD, BHD (scale 3). New currencies can be added to `CurrencyRegistry` without touching accounting logic.

---

### 14. MoneyMinor

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Value Object |
| **Ideal Mutability** | **Immutable** |
| **Storage** | Integer in minor units |

| Field | Type | Notes |
|-------|------|-------|
| `amountMinor` | `int` | Amount in minor units (paise, cents, fils) |
| `currencyCode` | `String` | ISO 4217 currency code |

**Notes:** Core type for all accounting math. Using integers eliminates floating-point errors. Conversion to/from display values happens at UI boundaries via `MoneyConversion.parseToMinor()` and `MoneyConversion.toDisplay()`.

---

### 15. PaymentAttempt

| Attribute | Value |
|-----------|-------|
| **Semantic Role** | Event / State Tracker |
| **Ideal Mutability** | **Status Mutable** |
| **Storage** | Firestore (`groups/{groupId}/payment_attempts/{attemptId}`) |

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Unique attempt ID (format: `pa_{timestamp}`) |
| `groupId` | `String` | Parent group ID |
| `cycleId` | `String` | Cycle this payment belongs to |
| `fromMemberId` | `String` | Payer member ID |
| `toMemberId` | `String` | Payee member ID |
| `amountMinor` | `int` | Payment amount in minor units |
| `currencyCode` | `String` | ISO 4217 currency code |
| `status` | `String` | One of: `not_started`, `initiated`, `confirmed_by_payer`, `confirmed_by_receiver`, `disputed` |
| `createdAt` | `int` | Epoch millis when attempt was created |
| `initiatedAt` | `int?` | Epoch millis when UPI app was launched |
| `confirmedAt` | `int?` | Epoch millis when marked as paid |

**Notes:** Tracks state of each UPI payment. Created lazily when user first taps "Pay via UPI" for a route. State machine: `notStarted` → `initiated` (on UPI launch) → `confirmedByPayer` (on "Mark as paid") → optionally `confirmedByReceiver` (on receiver confirmation). `disputed` state available for conflict resolution. Payments are **never auto-confirmed**; explicit user action required. Attempts persist per-cycle; deleted when cycle archives.

---

## Invariants Implied by This Spine

1. **Expense amounts must be positive and finite** — enforced
2. **Split amounts must sum to expense amount** — enforced at NormalizedExpense construction
3. **Net balances must sum to zero** — enforced by algorithm design and LedgerDelta invariant
4. **Closed cycles should not accept new expenses** — assumed, not enforced at data layer
5. **A user cannot be in both members and pendingMembers** — assumed, transaction-dependent
6. **creatorId is immutable after group creation** — assumed, not enforced
7. **Sum of LedgerDeltas for any expense is zero** — enforced by toLedgerDeltas assertion
8. **NormalizedExpense contains only member IDs, never names** — enforced at construction

---

## Usage Notes

This document describes **what the entities are**, not **how they should be changed**. It serves as a reference for:

- Understanding which fields affect money calculations
- Identifying where extra caution is needed during modifications
- Recognizing implicit invariants that the code assumes but doesn't enforce

No refactors are proposed. The current implementation continues to work as designed.
