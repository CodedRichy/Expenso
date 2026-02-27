# Expenso — App Blueprint

**Use this as the primary reference for all future logic and UI changes.**

**Sections 1–8** describe the **current implementation** (what is built and live).  
**Section 9** lists **planned features** (not implemented yet), grouped into three suites for later prioritization.  
**Logic audit:** See **docs/LOGIC_AUDIT.md** for a list of logical errors found and fixed (e.g. `_membersById` in cycle_repository) and follow-up items (undo screen, date sort, route args).

**Release docs:** See `docs/releases/` for version contracts:
- [V1_RELEASE.md](docs/releases/V1_RELEASE.md) — Core identity (Magic Bar, Decision Clarity, SettlementEngine)
- [V2_RELEASE.md](docs/releases/V2_RELEASE.md) — Profile pictures, UPI deep-linking, push foundation
- [V3_RELEASE.md](docs/releases/V3_RELEASE.md) — Settlement activity, offline resilience, Dynamic UPI QR (complete)
- [V4_RELEASE.md](docs/releases/V4_RELEASE.md) — Cross-group identity, God Mode debt minimization, FCM infrastructure (current)

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

**Initial route:** `/splash` → then `/`.

**Cold start optimization:** In `main()`, before `runApp`, `UserProfileCache.load()`, `ThemeService.load()`, and `LocaleService.load()` are awaited and `CycleRepository.loadFromLocalCache()` is called. This hydrates the user's identity (name, photoURL, upiId) and theme/locale from `SharedPreferences` **before Firebase resolves**, enabling instant avatar and settings on cold start.

On launch, **SplashScreen** shows the app logo (light background) for ~1.5s, then navigates to `/`.

The home route `/` uses **Firebase Auth state** first, then repo state:

1. **StreamBuilder** on `PhoneAuthService.instance.authStateChanges`.
2. If **user == null** → repo is cleared (including local cache) and **PhoneAuth** (login) is shown.
3. If **user != null** → repo is synced in-memory (`setAuthFromFirebaseUserSync(uid, phone, displayName)`, merging cached photoURL), then after the frame `continueAuthFromFirebaseUser()` runs (writes `users/{uid}`, starts Firestore listeners, updates local cache with fresh data). Then:
   - If `currentUserName.isEmpty` → **OnboardingNameScreen**
   - Else → **GroupsList** (ledger).

Every UID in the app comes from Firebase Auth; there is no mock user id.

**PhoneAuth** — User enters +91 phone → OTP step.

- **When Firebase is configured** (`firebaseAuthAvailable`): `PhoneAuthService` calls `FirebaseAuth.instance.verifyPhoneNumber`; `codeSent` → OTP screen; user enters 6-digit code; on verify, `signInWithCredential` then auth state updates and repo is synced. Errors `invalid-verification-code` and `too-many-requests` are caught; for the test number (+91 79022 03218) the UI shows that code **123456** is the required dev bypass.
- **When Firebase is not configured**: mock flow — any 10 digits → OTP step, any 6 digits → `setGlobalProfile` only (no UID; creator features unavailable until real auth).

To enable real phone auth: run `dart run flutterfire configure`, enable **Phone** sign-in in Firebase Console → Authentication → Sign-in method, and add `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) via FlutterFire or manually.

**OnboardingNameScreen** — “What should we call you?” → user taps “Get Started” → `setGlobalProfile(repo.currentUserPhone, name)` and `FirebaseAuth.instance.currentUser?.updateDisplayName(name)` so the name persists across restarts.

---

## 3. Routes and screens

### Core

| Route | Screen | Notes |
|-------|--------|--------|
| `/splash` | SplashScreen | Shown first; logo then navigates to `/`. |
| `/` | PhoneAuth / OnboardingName / GroupsList | Decided by auth stream then repo (see §2). |
| `/groups` | GroupsList | List of groups; header shows **profile avatar** (tap → `/profile`); **swipe left** = Pin/Unpin (max 3); **swipe right** = Delete (creator only). Pinned at top. Black FAB creates group. **Pending Invitations** section at top when user has been invited to groups (via phone number); shows group name with Join/Decline buttons. |
| `/create-group` | CreateGroup | New group → then InviteMembers. |
| `/invite-members` | InviteMembers | Add by phone/name; contact suggestions via `flutter_contacts` (import as `fc`). **Country code picker** (15 countries: IN, US, UK, UAE, SG, AU, DE, FR, JP, CN, KR, BR, MX, RU, ZA). Invite link: `expenso://join/<groupId>` generated and copied to clipboard. Contacts: permission-denial message; suggestions deduped against existing + pending members. |
| `/group-detail` | GroupDetail | Compact top bar (back, group name, members). **Decision Clarity** summary card (gradient Deep Navy→Slate, shadow): “Cycle Total: ₹X”, 50/50 row “Spent by You: ₹Y” and “Your Status: ±₹Z” (green accent = credit, red = debt); empty state “Zero-Waste Cycle” + Magic Bar prompt. Then **Pay / Settle** (or **View settlement**) and **Close cycle** (creator only), **Balances**, expense log, **Smart Bar**. **Expense confirmation dialog**: Real-time sum of exact amounts as user types. Label "Total: ₹X | Assigned: ₹Y" for Exact/Percentage/Shares. For Exact split, amount per slot is editable (TextField); assigned sum updates live. Confirm enabled only when amount > 0, description non-empty, total assigned == total (0.01 tolerance), and all slots have a member; otherwise grey Confirm and red subtext; heavy haptic on Confirm tap when math invalid. **Justice Guard**: "Settle & Restart" and "Start New Cycle" both require a confirmation popup (even for creator). Haptics: light on AI parse success and confirm; heavy on validation failure; groups list swipe (Pin/Delete) unchanged. |
| `/expense-input` | ExpenseInput | One field (e.g. “Dinner 1200 with”); Who paid? Who’s involved; **NLP** auto-selects participants by typed names. |

### Expense and members

| Route | Screen | Notes |
|-------|--------|--------|
| `/edit-expense` | EditExpense | Args: `expenseId`, `groupId`. Shows description, amount, date, payer, **split type** (Even/Exact/Exclude from Firestore), and **people involved** (from saved `splits`; participant resolution uses normalized phone so parser-derived participants are not dropped). |
| `/undo-expense` | UndoExpense | Shown after add (expense input or Magic Bar). Args: `groupId`, `expenseId`, `description`, `amount`. 5s timer then auto-dismiss; Undo deletes from Firestore and pops. |
| `/group-members` | GroupMembers | List / edit members; **👑** next to creator name. **Removal Guard:** Creator can only remove members with zero balance; otherwise blocked with alert ("Settle their outstanding debt before removing them"). Pending members show gray name with **Invited** badge; creator sees FAB to add more members. |
| `/member-change` | MemberChange | Confirm member removal. Args: `groupId`, `groupName`, `memberId`, `memberPhone`, `action`. On confirm, calls `repo.removeMemberFromGroup`. |
| ~~`/delete-group`~~ | — | **Not in routes.** Group delete is confirmed via dialog in GroupsList; no full-page DeleteGroup screen in navigation. DeleteGroup widget exists for reference only. |

### Settlement and history

| Route | Screen | Notes |
|-------|--------|--------|
| `/settlement-confirmation` | SettlementConfirmation | Args: `Group` or `{ group, method }` (method: `'system'` \| `'upi'` \| `'razorpay'`). Shows current user's dues per creditor with UpiPaymentCard for each. Includes **SettlementActivityFeed** showing recent settlement events (payment initiated, confirmed, cycle closed). Neutral system voice, no names unless necessary. |
| `/payment-result` | PaymentResult | After payment. |
| `/cycle-settled` | CycleSettled | Cycle settled. |
| `/cycle-history` | CycleHistory | Past cycles. |
| `/cycle-history-detail` | CycleHistoryDetail | One past cycle. |

### Profile

| Route | Screen | Notes |
|-------|--------|--------|
| `/profile` | ProfileScreen | Identity: avatar (upload via ProfileService), display name (synced to Firestore + Groq fuzzy matching). Payment Settings: UPI ID. **Log out** button (confirmation dialog, clears auth, returns to login). Deep Navy & Slate card theme. |

### Utility

| Route | Screen |
|-------|--------|
| `/empty-states` | EmptyStates. Types: `no-groups`, `no-expenses`, `new-cycle`, `no-expenses-new-cycle`, `zero-waste-cycle` (optional `forDarkCard` for Decision Clarity card). |
| `/error-states` | ErrorStates. Args: `type` ('network', 'session-expired', 'payment-unavailable', 'generic'). Pushed on Firestore stream error (GroupsList), auth session expired (PhoneAuth). All error screens have a back button and clear, calm messaging that reassures users their data is safe. "Try Again" calls `CycleRepository.restartListening()` and pop. |

---

## 4. Data layer

### Cloud Firestore (Test Mode)

**Security rules** (`firestore.rules`): Users can read/write only their own `users/{uid}`. Groups, expenses, and settled_cycles (and subcollections) are readable/writable only by group members (`isGroupMember`). No access to other groups or to orphaned data after group delete. Deploy with `firebase deploy --only firestore`.

**Data encryption (at rest):** Sensitive fields are encrypted before write and decrypted after read so a DB dump is not readable without keys. Keys are derived server-side (Cloud Functions `getUserEncryptionKey`, `getGroupEncryptionKey`) from a master secret (`DATA_ENCRYPTION_MASTER_KEY`); the app fetches keys after auth and caches them in memory. Encrypted: user (displayName, phoneNumber, photoURL, upiId), group (groupName, pendingMembers), expense (description, amount, date, splits, participantIds, category, etc.). Rules-relevant fields (e.g. `members`, `creatorId`) and settled cycle meta (`startDate`, `endDate`) stay plaintext. Implemented in `DataEncryptionService` and `FirestoreService`; optional — if the master key is not set, the app runs without encryption (backward compatible). **Used throughout the project:** all Firestore access goes through `FirestoreService` (no direct `FirebaseFirestore` usage elsewhere), so encryption is applied on every read/write that touches sensitive data. See **docs/DATA_ENCRYPTION.md** for coverage and the one intentional gap (createGroup initial write).

All writes use the real Firebase Auth `User.uid` (e.g. test number +91 79022 03218).

- **users** — Document ID = Firebase UID. Fields: `displayName`, `phoneNumber`, `photoURL`, `upiId`.
- **groups** — Fields: `groupName`, `members` (array of UIDs), `creatorId`, `activeCycleId`, `cycleStatus` ('active' | 'settling'), optional `pendingMembers` (phone/name for invite-by-phone), `pendingPhones` (flat array of normalized phone numbers for queryable invitations).
- **groups/{groupId}/expenses** — Current-cycle expenses. All person references are by member id (uid). Fields: `groupId`, `amount`, `payerId`, `splitType`, `participantIds`, `splits` (uid → amount_owed), `description`, `date`, `dateSortKey`, optional `category`.
- **groups/{groupId}/settled_cycles/{cycleId}** — One doc per settled cycle: `startDate`, `endDate`. Subcollection **expenses** holds archived expense docs (same shape).

**Archive logic:** Settle (Phase 1) sets `cycleStatus` to `settling`. Archive (Phase 2, creator-only) copies current-cycle expenses into `settled_cycles/{cycleId}/expenses`, deletes from current `expenses`, then sets new `activeCycleId` and `cycleStatus: 'active'`.

### FirestoreService

**Location:** `lib/services/firestore_service.dart` — Singleton. Low-level Firestore: `setUser(uid, displayName?, phoneNumber?, photoURL?, upiId?)`, `getUser`, `userStream`, `createGroup`, `deleteGroup`, `groupsStream(uid)`, `expensesStream(groupId)`, `addExpense`, `updateExpense`, `deleteExpense`, `archiveCycleExpenses`, `getSettledCycles`, `getSettledCycleExpenses`.

### GroqExpenseParserService

**Location:** `lib/services/groq_expense_parser_service.dart` — Stateless. Aligned with CLI and **PARSER_OUTCOME_CONTRACT.md** (parseConfidence, constraintFlags, reject, splitType unresolved). The system prompt and few-shot examples in this file are the app’s **proprietary “secret formula”** for turning casual speech into structured expenses; treat as core IP. The **prompt is model-agnostic** (see **docs/EXPENSE_PARSER_PROMPT_REFINEMENT.md**). Implementation calls Groq API (`llama-3.3-70b-versatile`). Expects raw JSON (same schema). Injects group member names so the model can map “split with Ash” or "Ash paid 500 for me" to names. **GROQ_API_KEY** must be set in `.env`. **Rate limiting:** on 429, waits per `retry-after` header (default 2s, clamped 1–60s) and retries once; if still 429, throws `GroqRateLimitException` (Magic Bar shows 30s cooldown and “try manual entry”). On other failure or unparseable response, caller shows snackbar. GroupDetail Magic Bar uses this and, on success, shows confirmation dialog (per-person amount on each chip; for exact splits, sum must match total or Confirm is disabled; payer defaults to current user but can be set by AI). Saving calls `CycleRepository.addExpenseFromMagicBar` so Firestore gets a full `splits` map and correct `splitType` (Even / Exact / Exclude / Percentage / Shares; Unresolved is persisted as Even). Parser follows **PARSER_OUTCOME_CONTRACT.md**: `parseConfidence` (confident | constrained | reject), `splitType` can be **unresolved**; on reject the service throws and no dialog is shown.

### UpiPaymentService

**Location:** `lib/services/upi_payment_service.dart` — Uses `upi_india` package for industry-grade UPI integration. Core classes:
- **`UpiAppInfo`**: Wrapper for installed UPI app (name, icon, underlying `UpiApp`).
- **`UpiPaymentData`**: Holds payee UPI ID, name, amount (minor units), transaction note, and reference ID. `qrData` getter returns UPI deep link string for QR fallback.
- **`UpiTransactionResult`**: Payment outcome with status (`success`, `failure`, `submitted`, `cancelled`, `unknown`), transaction ID, response code, and approval ref.

Key methods:
- `getInstalledUpiApps()` → returns list of `UpiAppInfo` (cached); sorted by priority (GPay, PhonePe, Paytm first).
- `createPaymentData(...)` → builds `UpiPaymentData` with note "Expenso • {GroupName} • Cycle".
- `initiateTransaction(data, appInfo)` → launches selected UPI app, handles exceptions (`UpiIndiaAppNotInstalledException`, `UpiIndiaUserCancelledException`, etc.), returns `UpiTransactionResult`.
- `getStatusMessage/Icon/Color(result)` → UI helpers for displaying transaction outcome.

On Android, shows installed UPI apps grid via `UpiAppPicker`. On iOS, limited UPI support; falls back to QR code. No Razorpay/escrow involvement.

**Payment Flow (Zomato-style):**
1. User taps "Pay via UPI" → `UpiAppPicker` shows bottom sheet with app grid
2. User selects app → full-screen `UpiPaymentWaitingOverlay` appears
3. Overlay shows: animated pulse, amount card, 90-second countdown timer
4. UPI app launches with pre-filled payment data
5. User returns → overlay shows result (success/failure/pending/cancelled)
6. Actions: "I've already paid" (manual confirm), "Try Again" (retry), "Cancel" (back to app grid)
7. On success or manual confirm → `UpiAppPickerResult.isSuccess = true` → payment marked as paid

### PaymentAttempt

**Location:** `lib/models/payment_attempt.dart` — Tracks state of each UPI payment attempt. `PaymentAttemptStatus` enum: `notStarted`, `initiated`, `confirmedByPayer`, `confirmedByReceiver`, `disputed`. When user taps "Pay via UPI", state transitions to `initiated` and persists to Firestore (`groups/{groupId}/payment_attempts`). After returning to app, user sees "Mark as paid" button; on tap → `confirmedByPayer`. Receiver can later confirm with `confirmedByReceiver`. Payments are **not auto-confirmed** — explicit user action required. `PaymentAttempt` stores `groupId`, `cycleId`, `fromMemberId`, `toMemberId`, `amountMinor`, `currencyCode`, `status`, `createdAt`, `initiatedAt`, `confirmedAt`. CycleRepository methods: `loadPaymentAttempts`, `getOrCreatePaymentAttempt`, `markPaymentInitiated`, `markPaymentConfirmedByPayer`, `markPaymentConfirmedByReceiver`, `markPaymentDisputed`.

### CycleRepository

**Location:** `lib/repositories/cycle_repository.dart`  
**Type:** Singleton, `ChangeNotifier`. Backed by Firestore: subscribes to `groupsStream(currentUserId)` and each group's `expensesStream`; maps snapshots to `_groups`, `_expensesByCycleId`, `_membersById` and notifies listeners.

| Area | Details |
|------|---------|
| **Identity** | `loadFromLocalCache()` (called in `main()`) hydrates identity from `UserProfileCache` **before** Firebase resolves; `setAuthFromFirebaseUserSync` sets in-memory state and merges cached photoURL; `continueAuthFromFirebaseUser()` (post-frame) writes `users/{uid}` and starts Firestore listeners; `clearAuth()` stops listeners, clears state and local cache. |
| **Groups** | `_groups` from Firestore (members array-contains uid). `addGroup` → `FirestoreService.createGroup`. |
| **Members** | `_membersById`. Creator in `addGroup` gets `currentUserName`. |
| **Display names** | `getMemberDisplayName(phone)` → current user: `currentUserName` or “You”; others: member name or formatted phone. Ashe display name is sent to the AI expense parser for Magic Bar fuzzy matching. |
| **Profile** | `currentUserPhotoURL`, `currentUserUpiId`; `updateCurrentUserPhotoURL`, `updateCurrentUserUpiId`; `getMemberPhotoURL(memberId)`, `getMemberUpiId(memberId)`. `setGlobalProfile` persists name to Firestore and local cache. All profile updates sync to `UserProfileCache` for instant availability on next cold start. |
| **Cycles** | `getActiveCycle` from `_groupMeta` + `_expensesByCycleId`. CRUD writes to `groups/{id}/expenses`. `settleAndRestartCycle` / `archiveAndRestart` creator-only; archive moves expenses to `settled_cycles`. `getHistory(groupId)` async, reads `settled_cycles`. |
| **Balances** | `calculateBalances` uses each expense's `splitAmountsByPhone` from Firestore when present (else equal split); `getSettlementInstructions` uses `getMemberDisplayName`; `getSettlementTransfersForCurrentUser(groupId)` returns list of `SettlementTransfer` (creditor, amount) for the current user as debtor. **SettlementEngine** (see below) computes debts for the Balances section in Group Detail. |
| **Payment Attempts** | `loadPaymentAttempts(groupId)` fetches from Firestore; `getPaymentAttempts(groupId)` returns cached list; `getPaymentAttemptForRoute(groupId, fromId, toId)` finds attempt by route. `getOrCreatePaymentAttempt(...)` creates if missing. `markPaymentInitiated`, `markPaymentConfirmedByPayer`, `markPaymentConfirmedByReceiver`, `markPaymentDisputed` update status with timestamps. State persists in `groups/{groupId}/payment_attempts`. |
| **Smart Bar splits** | `addExpenseFromMagicBar(groupId, …)` builds `splits` for Even (equal among participants; **empty participants = everyone**), Exclude (equal among all minus excluded), Exact (per-person amounts); writes `splitType` and full `splits` map to Firestore. **Phone→UID** resolution uses `_uidForPhone` with normalized phone (digits, last 10 for IN) so parser-derived participants are not dropped when formats differ. On read, `_expenseFromFirestore` builds `participantPhones` and `splitAmountsByPhone` from `splits` and reads `splitType`; edit expense and balances use this saved data. See **docs/EXPENSE_SPLIT_USE_CASES.md** for all split scenarios and who-paid semantics. |
| **Authority** | Only `creatorId` can call `settleAndRestartCycle` and `archiveAndRestart`. GroupDetail shows "Start New Cycle" only for creator when settling. |
| **Last-added / Undo** | After `addExpense` or `addExpenseFromMagicBar`, repo stores `lastAddedGroupId`, `lastAddedExpenseId`, `lastAddedDescription`, `lastAddedAmount`. GroupDetail pushes `/undo-expense` with those; UndoExpense screen shows 5s countdown, Undo → `deleteExpense` + `clearLastAdded` + pop, timeout → pop. |
| **Stream error / ErrorStates** | `streamError` set when groups or expenses stream `onError`; `clearStreamError()`, `restartListening()`. GroupsList pushes `/error-states` (type `network`) when `streamError != null`; ErrorStates "Try Again" calls `restartListening()` and pop. |
| **Bounded loading** | Loading states are time-bounded (6–8s) to prevent indefinite spinners. After timeout, UI shows a slow-loading hint with retry option. Groups list and cycle history both use bounded loading. |

### Models

**Location:** `lib/models/`

- **models.dart** — `Group`, `Member` (optional `photoURL` for avatar), `Expense` (participantIds, paidById, splitAmountsById; category; splitType; `displayDate` getter returns human-friendly format: "Today", "Yesterday", "3 days ago", "Feb 15", "Feb 15, 2025". All person references use member id, not phone.), `SettlementTransfer` (creditorPhone, creditorDisplayName, amount — phone/name filled from uid for display)
- **payment_attempt.dart** — `PaymentAttemptStatus` (notStarted, initiated, confirmedByPayer, confirmedByReceiver, disputed), `PaymentAttempt` (id, groupId, cycleId, fromMemberId, toMemberId, amountMinor, currencyCode, status, createdAt, initiatedAt, confirmedAt). Tracks UPI payment state with Firestore persistence.
- **cycle.dart** — `CycleStatus` (active, settling, closed), `Cycle`
- **utils/expense_validation.dart** — `validateExpenseAmount`, `validateExpenseDescription`; repo throws `ArgumentError` with message when invalid; UI shows snackbar.
- **utils/settlement_engine.dart** — `Debt` (fromId, toId, amount), `SettlementEngine.computeDebts(expenses, members)` (who owes whom), `SettlementEngine.computeNetBalances(expenses, members)` (member id → net: + credit, − debt). Used by Group Detail **Balances** and **Decision Clarity** card (“Your Status”).

---

## 5. Design system

### Design Tokens (lib/design/)

Centralized design tokens in `lib/design/`:

| File | Contents |
|------|----------|
| `colors.dart` | `AppColors` + `AppColorsDark` — theme colors. `AppColorsX` extension for theme-aware access via `context.colorXxx`. |
| `typography.dart` | `AppTypography` — text styles. `ThemedTypography` extension for theme-aware styles via `context.screenTitle`, etc. |
| `spacing.dart` | `AppSpacing` — spacing scale (space2xs through space9xl), semantic spacing constants |

### Theme Support

The app supports **Light**, **Dark**, and **System** theme modes via `ThemeService` (singleton, persists to `SharedPreferences`). Toggle via animated sun/moon eclipse icon in Profile screen header.

### Colors

#### Light Mode (AppColors)

| Token | Value | Use |
|-------|-------|-----|
| `background` | `#FFFFFF` | Scaffold background |
| `cardGradientStart/End` | `#FFFFFF → #EFEFEF` | Card backgrounds |
| `cardBorder` | `#DADADA` | Card borders |
| `primary` | `#1A1A1A` | Buttons, headlines |
| `textPrimary/Secondary` | `#1A1A1A / #6B6B6B` | Text hierarchy |
| `gradientStart/End` | `#1A1A1A → #6B6B6B` | Profile header cards |

#### Dark Mode (AppColorsDark)

| Token | Value | Use |
|-------|-------|-----|
| `backgroundGradientStart/End` | `#0B0B0D → #121216` | Scaffold gradient |
| `cardGradientStart/End` | `#18181C → #232329` | Card backgrounds |
| `cardBorder` | `#2C2C34` | Card borders |
| `primary` | `#E5E5E5` | Buttons, headlines |
| `textPrimary/Secondary` | `#F5F5F5 / #B0B0B0` | Text hierarchy |

Use `context.colorXxx` for theme-aware color access.

### Typography

| Use | Size | Weight | LetterSpacing |
|-----|------|--------|---------------|
| Large titles (e.g. “Groups”) | 34px | w600 | -0.6 |
| Screen titles, **pending amount** | 28px | w600 | -0.5 |
| Body | 17px | — | — |
| Labels / small | 15px | — | — |
| Overlines (e.g. “EXPENSE LOG”) | 13px | w500 | 0.3 |

### Spacing (AppSpacing)

Scale: `space2xs` (2) → `spaceXl` (16) → `space3xl` (24) → `space9xl` (96).
Semantic: `screenPaddingH` (24), `inputPadding` (16), `buttonPaddingV` (14).

### Theme (main.dart)

`_buildTheme(Brightness)` generates light/dark `ThemeData` with theme-appropriate colors for all components.

### GradientScaffold (lib/widgets/gradient_scaffold.dart)

Wrapper that applies dark mode background gradient (`#0B0B0D → #121216`). Used by main screens instead of plain `Scaffold`.

### Branding

- **App logo** — Shown on splash only.
- **Theme toggle** — Animated sun (with rays) / crescent moon icon in Profile header.

### Components

- **Primary buttons** — Theme defaults; 8px radius, 0 elevation.
- **FAB** — Theme-aware colors, 14px radius.
- **Cards** — Use `context.colorCardGradientStart/End` for gradient backgrounds.

---

## 6. Key logic conventions

### Action hierarchy (GroupsList)

- The **black FAB** is the only way to create a group.
- Do **not** add a blue “Create Group” text button.
- Empty state CTA may still navigate to create-group.
- **Swipe left** on a row: Pin / Unpin (user preference; max 3 pinned; pinned groups shown at top).
- **Swipe right** on a row: Delete Group (red; only if `isCurrentUserCreator`; confirm dialog then `repo.deleteGroup`).

### Settlement — Passive state (Freeze before Wipe) & God Mode (GroupDetail)

- **CycleStatus:** `active` → **settling** (Phase 1: freeze) → **closed** + new active (Phase 2: archive & restart).
- **Settlement UI (Group Detail):** Two actions. (1) **Pay / Settle** or **View settlement** (everyone): opens `/settlement-confirmation`. (2) **Close cycle** or **Start New Cycle** (creator only): dialog; on Confirm, active cycle → `settleAndRestartCycle(groupId)` (Phase 1: `CycleStatus.settling`); settling cycle → `archiveAndRestart(groupId)` (Phase 2). See **docs/features/SETTLEMENT_UI_FLOW.md**.
- **Passive state (`isPassive = activeCycle.status == CycleStatus.settling`):** Amount and status use muted gray (0xFF9B9B9B); status text “Cycle Settled - Pending Restart”. Hide “Add expense” row. Disable expense log item taps (no navigation to edit). “Settle up” remains visible. Only “Start New Cycle” performs the wipe.
- **Permissions:** `canEditCycle` returns false when cycle is **settling** for everyone (including leader). Edit screen and add expense are read-only / hidden.
- **If member (non-creator):** Only Pay / Settle or View settlement; no Close cycle button.
- **“Pay via UPI”** (secondary): navigates to settlement-confirmation with `{ group, method: 'razorpay' }`. User sees their dues and can pay via Razorpay Checkout. Design: primary button black, borderRadius 8, no elevation; balanced vertical padding before Expense Log.

### Recording vs settlement (we only mark it down)

- **Expenses we record** (e.g. “A paid 300”, “B paid 75”) are **real-world payments that already happened**. The app does **not** process or collect those amounts; we only **note them down** (who paid, amount, split). No money flows through the app for the original expense.
- **Settlement** (who pays whom to clear the books) is **derived** from those records. E.g. B owes A 75, C owes 100 to A and 25 to B. Any in-app payment facilitation (UPI deep link, Razorpay collect-and-disburse, etc.) applies **only to these settlement flows**, not to the original “A paid 300” / “B paid 75”.

### Phone format

- Store/display with country code prefix (e.g. `+91XXXXXXXXXX`, `+1XXXXXXXXXX`). Supports 15 country codes (IN, US, UK, UAE, SG, AU, DE, FR, JP, CN, KR, BR, MX, RU, ZA).
- Normalize to digits when needed for matching.

### Expense parsing (ExpenseInput)

- Amount: first `[\d,]+`, then strip commas and parse.
- Description / “with” used for participants.
- Submit enabled when `input.trim().isNotEmpty` and `parseExpense(input).amount > 0`.

### Smart Bar (GroupDetail) — AI expense parser + manual fallback

- **Input:** Single text field at bottom of group detail (when cycle is active). User types e.g. “Dinner 500 with Ash”.
- **Debounce:** Send is allowed only 500ms after the user stops typing (prevents accidental spam).
- **Engine:** `GroqExpenseParserService.parse(userInput, groupMemberNames)` — **GROQ_API_KEY** from env; implementation uses Groq (`llama-3.3-70b-versatile`). System prompt is model-agnostic (see docs/EXPENSE_PARSER_PROMPT_REFINEMENT.md). Service retries once on 429 (wait per `retry-after` header, else 2s; see docs/features/GROQ_RATE_LIMITS.md) then throws `GroqRateLimitException`.
- **Loading:** In-bar loading only during the actual API call (including retry wait); keeps UI snappy.
- **Success:** Confirmation dialog with amount, description, category, split type, and participant chips. If a participant name from the AI cannot be resolved to a phone number, it is shown as a **"Select Member"** chip; the user must tap that chip to pick the correct member from the group list before Confirm is enabled. On Confirm → `CycleRepository.addExpenseFromMagicBar(…, category: result.category)`. Validation (amount > 0, non-empty description) runs in repo; on `ArgumentError` UI shows snackbar with message. Edit expense preserves `splitAmountsByPhone` and `category`; update uses them when present.
- **Failure:** Only if no number could be extracted (API failed and fallback found no number); snackbar: “Couldn’t parse that. Try a clearer format like ‘Dinner 500’.”
- **Rate limit (429 after retry):** Smart Bar enters a 30s cooldown; use keyboard icon for manual entry; placeholder becomes “AI is cooling down... try manual entry”. **Manual “Add expense manually” remains enabled** so the user can always add expenses.

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
assets/
  images/
    logoWhiteBg.png            # App logo on white; used for splash + Groups header
    logoBlackBg.png            # Logo on black (e.g. dark splash)
lib/
  main.dart                    # Routes, initial route /splash then /, Firebase init
  firebase_app.dart            # firebaseAuthAvailable flag (set by main, read by PhoneAuth)
  firebase_options.dart        # Generated by: dart run flutterfire configure (stub in repo until then)
  models/
    models.dart                # Group, Member, Expense
    cycle.dart                 # Cycle, CycleStatus
    currency.dart              # Currency, CurrencyRegistry (ISO 4217 metadata)
    money_minor.dart           # MoneyMinor, MoneyConversion, MoneySplitter (integer money)
    normalized_expense.dart    # NormalizedExpense (UI-agnostic, ID-only, integer-based)
    payment_attempt.dart       # PaymentAttempt, PaymentAttemptStatus (UPI payment state tracking)
    settlement_event.dart      # SettlementEvent, SettlementEventType (activity feed events for settlement)
  repositories/
    cycle_repository.dart      # Singleton; Firestore-backed (groups, members, cycles, expenses, identity)
  services/
    phone_auth_service.dart   # Firebase verifyPhoneNumber, codeSent, verificationCompleted, error handling
    firestore_service.dart    # Firestore: users, groups, expenses, settled_cycles; deleteGroup (creator-only)
    pinned_groups_service.dart # User pin preference (max 3 groups); SharedPreferences
    user_profile_cache.dart   # Local cache for user profile (name, photoURL, upiId); enables instant avatar on cold start before Firestore
    groq_expense_parser_service.dart  # AI expense parser (model-agnostic prompt; implementation: Groq/Llama). Parse NL → JSON. See docs/EXPENSE_PARSER_PROMPT_REFINEMENT.md
    profile_service.dart              # Firebase Storage avatar upload (users/{uid}/avatar.jpg)
    razorpay_order_service.dart       # createRazorpayOrder(amountPaise) via Cloud Function → orderId, keyId
    upi_payment_service.dart          # UPI deep link generation for direct P2P payments; QR fallback
    data_encryption_service.dart      # AES-GCM encryption for sensitive Firestore fields
  utils/
    expense_validation.dart   # validateExpenseAmount, validateExpenseDescription
    route_args.dart          # RouteArgs.getGroup, getMap — safe route arguments (avoids crash on missing/wrong type)
    settlement_engine.dart     # Debt, PaymentRoute, computeDebts, computeNetBalances, computePaymentRoutes, getPaymentsForMember (integer-based, greedy debt minimization)
    ledger_delta.dart          # LedgerDelta, toLedgerDeltas, expenseToLedgerDeltas (integer-based)
    expense_normalization.dart # Re-exports normalization_workflow.dart
    normalization_workflow.dart # UI workflow: normalizeExpense, ParticipantSlot, NormalizationResult
    expense_revision.dart      # Expense lifecycle guards (edit/delete validation)
  widgets/
    member_avatar.dart        # Letter avatar renders IMMEDIATELY; photo loads as upgrade layer via CachedNetworkImage. Zero visible waiting—letter is always the base.
    expenso_loader.dart       # Animated loading indicator
    upi_payment_card.dart     # Per-payment UPI card with app picker, QR fallback, and payment attempt state tracking
    upi_app_picker.dart       # Full UPI payment flow: app grid → waiting overlay → result handling
    upi_payment_waiting.dart  # Zomato-style waiting overlay with countdown, pulse animation, manual confirm option
    settlement_activity_feed.dart  # Read-only activity feed for settlement events; neutral system voice, no names
    settlement_progress_indicator.dart  # "X of Y payments settled" with progress bar; shows during settling cycle
  screens/
    splash_screen.dart          # Logo splash; navigates to / after ~1.5s
    phone_auth.dart
    onboarding_name.dart
    groups_list.dart
    group_list_skeleton.dart   # Shimmer skeleton while groups load
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
    profile.dart
    empty_states.dart
    error_states.dart
test/
  expense_validation_test.dart   # Unit tests for validateExpenseAmount, validateExpenseDescription
  parsed_expense_result_test.dart # Unit tests for ParsedExpenseResult.fromJson and parser outcome (parseConfidence, constraintFlags, rejectReason)
  expense_normalization_test.dart # Unit tests for NormalizedExpense, normalizeExpense, toLedgerDeltas
  settlement_engine_test.dart     # Unit tests for SettlementEngine (net balances, debts, payment routes, G9, balance-after-settlements contract)
  expense_revision_test.dart      # Unit tests for negateDeltas and revision lifecycle
  data_encryption_test.dart       # Unit tests for encrypt/decrypt and key handling
  widgets/
    empty_states_test.dart        # Widget tests for EmptyStates (no-groups, no-expenses, zero-waste-cycle, etc.)
    expenso_loader_test.dart      # Widget tests for ExpensoLoader
integration_test/
  app_test.dart                   # Integration test: app launches and shows MaterialApp
tool/
  parser_cli.dart                 # CLI for testing the expense parser (Groq API). Use for parser tests: run with input to get outcome/JSON; same contract as app. Batch: --stress [file].
  parser_runs.log                 # Log of CLI runs (input + raw JSON) for debugging and golden data
```

**Parser tests:** For parser/outcome tests, the **CLI parser** (`tool/parser_cli.dart`) can be used: run e.g. `dart tool/parser_cli.dart "Dinner 500"` (or `--stress` for batch) to get real API outcomes; unit tests can assert on `ParsedExpenseResult.fromJson` with CLI-produced or contract JSON. Same outcome contract as the app (see PARSER_OUTCOME_CONTRACT.md).

---

## 8. Dependencies

| Package | Notes |
|---------|--------|
| `flutter` | SDK. |
| `cupertino_icons` | Icons. |
| `flutter_contacts` ^1.1.9+1 | Import as `fc` to avoid `Group` clash. |
| `firebase_core` | Required for Firebase. Run `dart run flutterfire configure` to generate `lib/firebase_options.dart` (stub in repo is replaced). |
| `firebase_auth` | Phone (OTP) sign-in when Firebase is configured. |
| `cloud_firestore` | Groups, expenses, settled_cycles; Test Mode. All writes use real User.uid. |
| `firebase_storage` | Profile avatar uploads (users/{uid}/avatar.jpg). |
| `flutter_dotenv` | Loads `.env`; **GROQ_API_KEY** required for Magic Bar AI parsing. |
| `http` | Groq API requests (chat completions). |
| `cached_network_image` | MemberAvatar: load and cache profile photos. |
| `image_picker` | Profile screen: pick photo from gallery for avatar. |
| `flutter_slidable` | Swipe actions on GroupsList (Pin left, Delete right). |
| `shared_preferences` | User pin preference (pinned group IDs, max 3). |
| `razorpay_flutter` | In-app settlement: open Razorpay Checkout with order from Cloud Function. |
| `cloud_functions` | Call `createRazorpayOrder` (asia-south1) to create Razorpay order; returns orderId and keyId. |

**Permissions:**

- **Android:** `READ_CONTACTS`
- **iOS:** `NSContactsUsageDescription` in Info.plist

---

## 9. Planned features (not implemented)

The following are **not built yet**. Each feature has a **verdict**, **why it matters**, and **when to add** so you can come back later and implement in the right order.  
**Status** = Not implemented until you ship it.

**User research:** Feature requests from the Jan 2026 Expenso idea survey are summarized in **docs/SURVEY_FEATURE_REQUESTS.md** (reminders, “I paid don’t worry”, reports, UPI, receipts, unequal split).

---

### 9.1 “Polished Local” suite (no server)

**Suite verdict:** ✅ **YES — do selectively.** Best pre-backend, pre-AI upgrades. This is where you win early.

| Feature | Verdict | When to add | Status |
|--------|---------|-------------|--------|
| **Receipt attachments** | ✅ Must-have polish | After settlement math, before Firebase. | Not implemented. Plus feature (3 free then paywall). See docs/features/RECEIPT_SCANNING_AND_ML.md for stack: Firebase ML Document Scanner + Text Recognition → text → Groq when adding scan-to-prefill. |
| **Dynamic UPI QR generator** | 🔥 Differentiator (India hit) | Early; no backend needed. Amount from your logic. | ✅ Implemented in V3 — `UpiPaymentCard` shows "Show QR" toggle; generates scannable QR with pre-filled amount via `qr_flutter`. |
| **Category intelligence** | ✅ Add later, keep dumb | After receipts/QR. Simple keyword → category map; don’t overdo NLP. | Not implemented |
| **Smart “nudge” templates** | ✅ Good — tone matters | Opt-in only. Don’t automate sending or nag. e.g. “₹2,480 pending. Settlement: Sunday.” | Not implemented |
| **Biometric lock** | ⏳ Nice-to-have, not urgent | After core flow is solid. Adds friction if too early; good for trust/credibility. | Not implemented |

**Implementation notes (Polished Local):**

- **Receipt attachments** — Ends arguments, reduces friction. Zero backend at first (local/file-based). High value. **Scan-to-prefill** (camera → OCR → Groq): use Firebase ML Kit (Document Scanner + Text Recognition); see docs/features/RECEIPT_SCANNING_AND_ML.md. Receipt attachments are Expenso Plus (MONETIZATION_EXECUTION).
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
| **Cross-group identity** | 🔥 Long-term core | Backend + stable member identity. Unlocks debt minimization later. Very high value. | ✅ Implemented in V4 — `IdentityService` unifies phone→identity across groups |
| **Cloud backup & sync** | ✅ Mandatory (boring) | Required once you leave MVP. Non-negotiable; users assume it. | ✅ Implemented in V4 — `SyncStatusService` tracks sync state |

**Implementation notes (Cloud Power):**

- **Join notifications** — When you add “a friend” by contact, they get a push to join. High value, Phase 2.
- **Live activity feed** — “Ash added Dinner” in real time. Feels social but can feel like Splitwise noise. Only if subtle and calm.
- **Cross-group identity** — Net balance across all groups with same person. Invisible at first, huge later. Foundation for God Mode math.
- **Cloud backup & sync** — Not exciting; required. Do when you leave MVP.

---

### 9.3 “AI & Hit-Maker” suite (final vision)

**Suite verdict:** ⚠️ **Dangerous if rushed; massive if timed right.** Many apps die here by overpromising.

| Feature | Verdict | When to add | Status |
|--------|---------|-------------|--------|
| **Bill splitting via camera (OCR)** | 🚫 Do NOT touch early | After everything else works. Not MVP, not Phase 2. OCR + item–person matching = support nightmare. | Not implemented |
| **Voice command entry** | ❌ Skip or postpone | Low real usage. Accent/noise/debug pain. Sounds cool, rarely used. | Not implemented |
| **Debt minimization (“God Mode” math)** | 🔥 Signature feature | After cross-group identity. A owes B, B owes C → A pays C. Saves money, fewer txns, feels magical. | ✅ Implemented in V4 |
| **Spending insights** | ⚠️ Optional, tone-sensitive | If done wrong, feels like a finance app and breaks “calm.” Useful but can feel preachy. | Not implemented |

**Implementation notes (AI & Hit-Maker):**

- **Natural language expense parsing** — **Implemented.** GroupDetail “Magic Bar” uses the AI expense parser (model-agnostic prompt; implementation uses Groq) to parse free text → JSON; confirmation dialog then `CycleRepository.addExpense`. See §4 GroqExpenseParserService, §6 Smart Bar, docs/EXPENSE_PARSER_PROMPT_REFINEMENT.md.
- **Bill splitting via OCR** — One photo, AI items, drag onto people. Very high risk: accuracy, edge cases, support. Do last. When implemented: same receipt stack (Firebase ML OCR → text or structured extraction); consider Gemini for image→expense or dedicated receipt API; see docs/features/RECEIPT_SCANNING_AND_ML.md.
- **Voice entry** — “Hey Expenso, I paid 400 for movies with the boys.” Low real value; skip or postpone indefinitely.
- **Debt minimization** — Real intelligence. Builds on members, balances, cross-group identity. Can be your signature feature. Extremely high value.
- **Spending insights** — “Hey, 20% more on travel this month. Time to settle up!” Medium value; tone matters.

---

### Suggested implementation order (when you return)

1. **Polished Local (selective):** Receipt attachments → Dynamic UPI QR → (optional) Category intelligence → Nudge templates → (later) Biometric lock.
2. **Cloud (after local is solid):** Cloud backup & sync → Real-time join notifications → Cross-group identity → (optional, subtle) Live activity feed.
3. **AI / Hit-Maker (last):** Debt minimization (“God Mode” math) → (optional) Spending insights. Skip or defer OCR and voice.

---

*When you add features or change the app: update **APP_BLUEPRINT** (sections 1–8) and **README.md**. When you implement a feature in §9, change its Status and add a one-line “Implemented in …” if helpful.*
