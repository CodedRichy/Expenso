# Expenso Stabilization Document

**Generated:** February 2026  
**Purpose:** Post-hoc stabilization pass for maintainability and clarity

---

## 1. System Snapshot

### What Expenso Does

Expenso is a Flutter mobile application for tracking shared expenses within small groups. Users create groups, add members by phone number, record expenses with configurable split rules (even, exact amounts, percentages, shares, exclusions), and view derived balances showing who owes whom. The app follows a cycle-based settlement model: expenses accumulate in an active cycle until the group creator freezes it, at which point members settle debts (optionally via Razorpay) and the creator archives the cycle to start fresh. Data is stored in Firebase Firestore with optional field-level encryption. A natural-language "Magic Bar" feature uses the Groq API (Llama 3.3) to parse expense descriptions into structured data.

### What It Solves Well

- **Simple expense recording** for groups of 2-10 people (roommates, trips, dinners)
- **Flexible split types** without requiring users to manually calculate amounts
- **Clear settlement flow** with a two-phase model (freeze, then archive) that prevents mid-settlement confusion
- **Real-time sync** via Firestore streams so all members see updates immediately
- **Natural language input** that reduces friction for common expense patterns

### What It Does NOT Solve

- Multi-currency or exchange rate handling
- Recurring/scheduled expenses
- Expense categorization reporting or analytics
- Integration with bank accounts or automatic transaction import
- Audit logs or detailed change history
- Offline-first operation (requires network for all writes)
- Large group scaling (designed for <15 members per group)
- Partial settlements or payment tracking outside of full cycle settlement

---

## 2. Data Spine Extraction

### Core Domain Entities

| Entity | Fields | Mutability | Storage |
|--------|--------|------------|---------|
| **Group** | `id: String`, `name: String`, `status: String`, `amount: double`, `statusLine: String`, `creatorId: String`, `memberIds: List<String>` | Mutable | Firestore (`groups/{groupId}`) |
| **Member** | `id: String`, `phone: String`, `name: String`, `photoURL: String?` | Mutable | Firestore (`users/{uid}`) + in-memory cache |
| **Expense** | `id: String`, `description: String`, `amount: double`, `date: String`, `participantIds: List<String>`, `paidById: String`, `splitAmountsById: Map<String, double>?`, `category: String`, `splitType: String` | Mutable | Firestore (`groups/{groupId}/expenses/{expenseId}`) |
| **Cycle** | `id: String`, `groupId: String`, `status: CycleStatus`, `expenses: List<Expense>`, `startDate: String?`, `endDate: String?` | Mutable (status transitions) | Firestore (active: `groups/{groupId}`, settled: `groups/{groupId}/settled_cycles/{cycleId}`) |
| **GroupInvitation** | `groupId: String`, `groupName: String`, `creatorId: String` | Immutable (accept/decline deletes) | Firestore (`groups/{groupId}` pending arrays) |
| **SystemMessage** | `id: String`, `type: String`, `userId: String`, `userName: String`, `date: String`, `timestamp: int` | Immutable | Firestore (`groups/{groupId}/system_messages/{msgId}`) |
| **SettlementTransfer** | `creditorPhone: String`, `creditorDisplayName: String`, `amount: double` | Immutable (derived) | Memory only (computed at runtime) |
| **Debt** | `fromId: String`, `toId: String`, `amount: double` | Immutable (derived) | Memory only (computed by SettlementEngine) |

### Mutability Concerns

| Entity | Should Be Immutable? | Currently Immutable? | Notes |
|--------|---------------------|---------------------|-------|
| Expense | Yes (append-only ledger semantics) | **Yes** | Edits and deletes use compensation events (negate original + append replacement). Lifecycle guards prevent illegal operations. See `docs/features/EXPENSE_REVISIONS.md`. |
| Cycle | Partially (closed cycles) | **No** | Active cycles are mutable; closed cycles are stored separately but lack tamper protection. |
| SystemMessage | Yes | Yes | Append-only activity feed. |
| SettlementTransfer | Yes | Yes | Ephemeral, computed on demand. |

---

## 3. Execution Flow (Truth Mode)

### User Authentication and Bootstrap

1. App launches → `main()` loads `.env`, initializes Firebase
2. `StreamBuilder<User?>` on `FirebaseAuth.instance.authStateChanges()`
3. If unauthenticated: show `PhoneAuth` screen → Firebase phone verification → OTP → signed in
4. If authenticated but no display name: show `OnboardingNameScreen` → user enters name → `setGlobalProfile()` called
5. `CycleRepository.instance.continueAuthFromFirebaseUser()` runs:
   - Fetches/creates user encryption key (if encryption enabled)
   - Writes user profile to Firestore
   - Starts Firestore stream subscriptions (`groupsStream`, `pendingInvitationsStream`)
6. Route to `GroupsList`

### Viewing Groups and Expenses

1. `CycleRepository._groupsSub` receives Firestore snapshot
2. `_onGroupsSnapshot()` parses docs, populates `_groups`, `_groupMeta`, starts per-group expense subscriptions
3. For each group: `expensesStream(groupId)` subscription created
4. `_onExpensesSnapshot()` parses expense docs into `_expensesByCycleId[cycleId]`
5. `notifyListeners()` triggers UI rebuild
6. `GroupDetail` screen calls `getActiveCycle()`, `getExpenses()`, renders expense list
7. `SettlementEngine.computeNetBalances()` called to derive balance card data

### Adding an Expense (Magic Bar Path)

1. User types in Magic Bar text field, presses send
2. `GroqExpenseParserService.parseExpense()` called with text + member names
3. Groq API returns JSON: description, amount, payer, participants, split type, amounts
4. Confirmation UI shown with parsed data
5. User taps Confirm → `CycleRepository.addExpenseFromMagicBar()` called
6. Validation runs (`validateExpenseAmount`, `validateExpenseDescription`)
7. Splits computed based on split type
8. `FirestoreService.addExpense()` writes to Firestore (encrypted if enabled)
9. Firestore stream fires → local state updated → UI rebuilds
10. `_setLastAdded()` stores undo data for 5-second undo window

### Settlement Flow

1. User taps "Pay / Settle" or "View settlement" → navigates to settlement confirmation
2. `CycleRepository.loadPaymentAttempts()` fetches existing attempts from Firestore
3. `SettlementEngine.computePaymentRoutes()` derives minimal payment routes
4. `getPaymentsForMember()` filters to current user's outgoing payments
5. `UpiPaymentCard` shown per route with payee name, amount, UPI ID, status, UPI button
6. Tap "Pay via UPI":
   - `UpiPaymentService.getInstalledUpiApps()` queries installed UPI apps
   - `UpiAppPicker` shows bottom sheet with app grid (GPay, PhonePe, Paytm, etc.)
   - User taps an app → full-screen `UpiPaymentWaitingOverlay` appears (Zomato-style)
7. Waiting overlay shows:
   - Animated pulsing circle with spinner
   - Payment amount and payee name card
   - 90-second countdown timer
   - "I've already paid" button for manual confirmation
   - "Cancel" to return to app grid
8. `UpiPaymentService.initiateTransaction()` launches selected UPI app
9. User completes payment in UPI app and returns:
   - **Success**: Green checkmark, "Payment Successful!", transaction ID shown
   - **Failure**: Red X, "Payment Failed", "Try Again" button
   - **Pending/Submitted**: Orange hourglass, "Payment Pending", manual confirm option
   - **Cancelled**: "Payment Cancelled", retry or cancel options
10. On success or "I've already paid" tap:
    - `getOrCreatePaymentAttempt()` creates `PaymentAttempt` in Firestore
    - `markPaymentInitiated()` → `markPaymentConfirmedByPayer()` → status `confirmed_by_payer`
11. If no UPI apps installed → QR code shown for scanning
12. User returns to app → sees "Mark as paid" button for `initiated` payments
13. Tap "Mark as paid" → `markPaymentConfirmedByPayer()` → status `confirmed_by_payer`
14. Card shows green checkmark, amount struck through for confirmed payments
15. **Payments never auto-confirmed** — explicit user action required
16. Balance updates:
    - `getRemainingBalance()` subtracts settled payments from original net balance
    - Group detail card shows "Remaining: ₹X" (with original amount struck through)
    - Settlement screen shows pending total after confirmed payments
17. Receiver confirmation flow:
    - Receiver's settlement screen shows "Incoming payments" section
    - Lists UPI payments marked `confirmed_by_payer` and cash payments `cash_pending`
    - Receiver taps "Confirm" → `markPaymentConfirmedByReceiver()` → status `confirmed_by_receiver`
18. Activity feed shows enriched messages: "Ash marked ₹500 as paid to Ash", "Ash confirmed receiving ₹500"
13. Creator taps "Close cycle" (or "Start New Cycle" when settling) → dialog; on Confirm, `settleAndRestartCycle(groupId)` or `archiveAndRestart(groupId)` called
14. (When creator confirms Close cycle) Firestore updated: `cycleStatus: 'settling'`
15. UI shows settling state, expense editing disabled
16. Creator taps "Start New Cycle" → `archiveAndRestart(groupId)` called
17. `FirestoreService.archiveCycleExpenses()`:
    - Copies all expense docs to `settled_cycles/{cycleId}/expenses`
    - Deletes expense docs from current location
    - Creates cycle metadata doc
18. Payment attempts for archived cycle can be deleted via `deletePaymentAttemptsForCycle()`
19. Group updated: `activeCycleId: new_id`, `cycleStatus: 'active'`
20. New empty cycle begins

### State Locations

| State | Location | Authoritative? |
|-------|----------|---------------|
| User identity | `CycleRepository._currentUserId`, `_currentUserPhone`, `_currentUserName` | Yes (from Firebase Auth) |
| Groups list | `CycleRepository._groups` | Cache (Firestore is source) |
| Expenses | `CycleRepository._expensesByCycleId` | Cache (Firestore is source) |
| Members | `CycleRepository._membersById` + `_userCache` | Cache (Firestore is source) |
| Pinned groups | `PinnedGroupsService` (SharedPreferences) | Yes (local only) |
| Balances/Debts | Computed on demand | Derived (not stored) |
| Payment attempts | `CycleRepository._paymentAttemptsByGroup` | Cache (Firestore is source) |

---

## 4. Invariants & Safety Rules

### 4.1 Ledger-safe state machine (parser → ledger)

Parsed intents move through the following states. This is the backbone for production-grade handling.

| State | Meaning |
|-------|--------|
| **NEW** | Raw parsed intent. Nothing touched. |
| **VALIDATED** | Schema + invariants checked (amount > 0, payer exists, intent allowed). No balances updated yet. |
| **FROZEN** | Used for constrained expenses, advances, deferred splits. Stored, visible, not applied. |
| **APPLIED** | Balances updated. Irreversible without an adjustment. Only CONFIDENT events reach here. |
| **CANCELLED** | Rejected or invalidated. |

**Allowed transitions:**

- `NEW → VALIDATED → APPLIED`
- `NEW → VALIDATED → FROZEN`
- `NEW → CANCELLED`
- `FROZEN → APPLIED`

**Never:** `FROZEN → CANCELLED` (history matters); `APPLIED → EDITED` (use adjustment); `SETTLEMENT → FROZEN` (settlements are applied or rejected).

### 4.2 Ledger invariants (parser/ledger)

- **Sum of balances = 0** across all members.
- **Applied events are append-only.** No in-place edit; use compensation or adjustment.
- **Settlements never create debt.** They only clear or transfer existing balances.
- **Notes never affect money.** NOTE intents must not touch balances.
- **Confidence can downgrade, never upgrade automatically.** If confidence is wrong, the ledger is wrong.

### 4.3 System invariants (reference)

| # | Invariant | Status |
|---|-----------|--------|
| 1 | **Expense amounts must be positive and finite** | ✅ Enforced by code (`validateExpenseAmount`, `SettlementEngine` skips invalid) |
| 2 | **Every expense must have a non-empty description** | ✅ Enforced by code (`validateExpenseDescription`) |
| 3 | **Split amounts must sum to expense amount** | ⚠️ Assumed but not enforced. The code computes splits at write time but does not validate sum equality on read. Historical data may have rounding errors. |
| 4 | **Only the group creator can settle/archive a cycle** | ✅ Enforced by code (`isCreator` check in `settleAndRestartCycle`, `archiveAndRestart`) |
| 5 | **Only the group creator can delete a group** | ✅ Enforced by code (`canDeleteGroup` check) |
| 6 | **A user can only be in `members[]` OR `pendingMembers[]`, not both** | ⚠️ Assumed. Transactions handle promotion, but no explicit check on read. |
| 7 | **Net balances must sum to zero across all members** | ✅ Enforced by design (SettlementEngine computes balanced debits/credits) |
| 8 | **Closed cycles are read-only** | ⚠️ Assumed but not enforced. Firestore rules may not prevent writes to `settled_cycles`. |
| 9 | **Each group has exactly one active cycle at any time** | ✅ Enforced by code (`activeCycleId` field, archive-then-create flow) |
| 10 | **Phone numbers are normalized before comparison** | ✅ Enforced by code (`_normalizePhone` used consistently) |
| 11 | **Pending members use `p_` prefix in IDs** | ✅ Enforced by code (convention throughout codebase) |
| 12 | **Encryption keys must be fetched before encrypted read/write** | ⚠️ Assumed. `ensureUserKey()`/`ensureGroupKey()` called, but failure paths may leave data unreadable. |
| 13 | **Deleted expenses cannot be edited** | ✅ Enforced by code (`guardEdit` throws `ExpenseLifecycleError`) |
| 14 | **Deleted expenses cannot be deleted again** | ✅ Enforced by code (`guardDelete` throws `ExpenseLifecycleError`) |

---

## 5. Known Limitations

### Functional Limitations

1. **No offline support.** All writes require network. Firestore offline persistence is not explicitly configured; behavior depends on defaults.

2. **No partial settlement tracking.** The app does not record who has paid whom mid-cycle. Settlement is all-or-nothing at cycle close.

3. **No conflict resolution for concurrent edits.** If two users edit the same expense simultaneously, last-write-wins applies.

4. **Phone number as identity.** Users who change phone numbers lose access to their history unless manually migrated.

5. **Expense audit trail via compensation model.** Edits and deletes use compensation events (negate original + append replacement), preserving full audit history. Lifecycle guards prevent edit-after-delete and delete-after-delete. See `docs/features/EXPENSE_REVISIONS.md`.

### Scale Limitations

5. **In-memory member cache.** `_membersById` and `_userCache` grow unbounded across sessions. Large groups or many groups may consume significant memory.

6. **No pagination.** Group list, expense list, and history are loaded fully. Works for small datasets; will degrade with hundreds of expenses per cycle.

7. **Single-region encryption keys.** `DataEncryptionService` hardcodes `asia-south1`. Users in other regions may experience latency.

### Design Shortcuts

8. **Date stored as string.** Expense `date` field is `"Today"`, `"Yesterday"`, or `"Mon DD"`. This makes date math fragile and timezone-dependent.

9. **Category is free-form.** No category normalization or predefined list. Inconsistent categorization is expected.

---

## 6. Change Safety Guide

### Safe vs Dangerous Changes in Expenso

#### Safe to Modify

- **UI/presentation code** in `lib/screens/` — Visual changes, text updates, layout adjustments
- **New screens** that don't modify existing data flows
- **PinnedGroupsService** — Isolated local storage, no cross-dependencies
- **Validation utilities** in `lib/utils/expense_validation.dart` — Adding stricter rules is safe; loosening is not
- **Adding new fields** to Firestore documents (additive schema changes)

#### Risky to Modify

- **CycleRepository** — Central state hub; changes cascade to all screens. Test thoroughly.
- **SettlementEngine** — Balance calculation logic. Even small changes affect money. Unit tests exist; run them.
- **FirestoreService encryption paths** — Incorrect changes can render data unreadable.
- **Split calculation logic** — Multiple entry points (`addExpense`, `addExpenseFromMagicBar`, `updateExpense`). Changes must be synchronized.

#### Do Not Touch Without Tests

- **`SettlementEngine.computeNetBalances()`** — Existing tests cover basic cases. Extend tests before modifying.
- **`SettlementEngine.computeDebts()`** — Debt minimization algorithm. Incorrect changes cause users to pay wrong amounts.
- **`SettlementEngine.computePaymentRoutes()`** — Greedy debt minimization algorithm. Returns minimal payment instructions from net balances. Use `getPaymentsForMember()` to filter payments for a specific member.
- **Cycle archive flow** (`archiveCycleExpenses`) — Data loss risk if expenses are deleted but not copied.
- **Firestore security rules** — Not in this codebase but critical. Changes can expose or lock out data.

#### Example: Dangerous Change That Looks Easy

**"Rename `paidById` to `payerId` for consistency"**

This looks like a simple rename, but:
1. Existing Firestore documents use `payerId` (not `paidById`)
2. The Dart model uses `paidById`
3. `_expenseFromFirestore()` reads `payerId` and maps to `paidById`
4. Write paths use `payerId` in the Firestore payload
5. Renaming the field in the model breaks read compatibility
6. Historical data in `settled_cycles` would become unreadable

A "simple rename" requires: data migration, versioned read logic, and testing against production data.

---

## 7. Freeze Decision

**Conclusion:** Expenso can safely evolve without major refactor.

The codebase is functional, coherent, and reasonably well-structured for its scope. The singleton repository pattern, while not ideal for testability, provides clear state ownership. Critical business logic (balance calculation, settlement) is isolated in `SettlementEngine` with unit test coverage. The main risks are around the mutable expense model and lack of audit trails, but these are acceptable trade-offs for this stage of the expense tracker.

The app should not be frozen—it has room for incremental feature work (offline support, better date handling, expense history) without architectural upheaval. However, any changes to the settlement engine or cycle archive flow should be approached with caution and require test coverage expansion. A v2 rewrite is not justified unless the scope expands significantly (multi-currency, recurring expenses, enterprise features).
