# Development timeline

Chronological view of notable development events for **Expenso**, derived from commit history (messages and change scope).

---

## Summary by type

- **feature**: 20 notable commit(s)
- **refactor**: 1 notable commit(s)
- **doc**: 4 notable commit(s)
- **test**: 3 notable commit(s)
- **other**: 17 notable commit(s)

---

## Timeline (newest first)

### 2026-02-20 — a33cfd6 **[other]**

Create TERMINAL_ERRORS_LOG.md

Scope: 1 files, +69 -0

---

### 2026-02-19 — d8b1add **[other]**

Auto-sync: EADME.md

Scope: 1 files, +67 -21

<details>
<summary>Commit body</summary>

1 file changed, 67 insertions(+), 21 deletions(-)

</details>

---

### 2026-02-19 — c05c2f3 **[other]**

Auto-sync: EADME.md

Scope: 1 files, +16 -75

<details>
<summary>Commit body</summary>

1 file changed, 16 insertions(+), 75 deletions(-)

</details>

---

### 2026-02-19 — 3c43720 **[other]**

Auto-sync: PP_BLUEPRINT.md, EADME.md, group_detail.dart, settlement_confirmation.dart, razorpay_order_service.dart (+4 more)

Scope: 9 files, +346 -116

<details>
<summary>Commit body</summary>

9 files changed, 346 insertions(+), 116 deletions(-)

</details>

---

### 2026-02-19 — 1453388 **[other]**

Auto-sync: models.dart, cycle_repository.dart, route_args.dart, ubspec.yaml, functions (+1 more)

Scope: 7 files, +137 -1

<details>
<summary>Commit body</summary>

7 files changed, 137 insertions(+), 1 deletion(-)

</details>

---

### 2026-02-19 — ca2fecd **[test]**

Auto-sync: EXPENSE_PARSER_PROMPT_REFINEMENT.md, groq_expense_parser_service.dart, parsed_expense_result_test.dart

Scope: 3 files, +78 -78

<details>
<summary>Commit body</summary>

3 files changed, 78 insertions(+), 78 deletions(-)

</details>

---

### 2026-02-19 — 3dd820b **[test]**

Auto-sync: 2026-02-19 17:10:36 UTC - group_detail.dart, parsed_expense_result_test.dart

Scope: 2 files, +19 -1

---

### 2026-02-19 — c0d845d **[test]**

Auto-sync: 2026-02-19 17:08:20 UTC - parsed_expense_result_test.dart, settlement_engine_test.dart

Scope: 2 files, +150 -0

---

### 2026-02-19 — 6c56395 **[other]**

Auto-sync: 2026-02-19 16:54:23 UTC - group_detail.dart

Scope: 1 files, +148 -13

---

### 2026-02-19 — d3655b1 **[other]**

Auto-sync: 2026-02-19 16:38:27 UTC - group_detail.dart

Scope: 1 files, +350 -193

---

### 2026-02-19 — c509f86 **[other]**

Auto-sync: 2026-02-19 16:30:18 UTC - edit_expense.dart, group_detail.dart

Scope: 2 files, +337 -28

---

### 2026-02-19 — 5069301 **[other]**

Auto-sync: 2026-02-19 16:09:26 UTC - PP_BLUEPRINT.md, BLUEPRINT_GAPS_VERIFICATION.md, empty_states.dart, group_detail.dart, invite_members.dart (+1 more)

Scope: 6 files, +99 -76

---

### 2026-02-19 — af4a74e **[other]**

Auto-sync: 2026-02-19 15:57:33 UTC - PP_BLUEPRINT.md, BLUEPRINT_GAPS_VERIFICATION.md, main.dart, cycle_repository.dart, error_states.dart (+4 more)

Scope: 9 files, +138 -74

---

### 2026-02-19 — 4b4cc29 **[other]**

Auto-sync: 2026-02-19 15:49:43 UTC - BLUEPRINT_GAPS_VERIFICATION.md

Scope: 1 files, +79 -0

---

### 2026-02-19 — f37840c **[feature]**

Add research on prompt refinement & parsing

Scope: 2 files, +241 -0

<details>
<summary>Commit body</summary>

Add a comprehensive research doc (docs/RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md) summarizing literature and practical guidance for prompt refinement and structured expense parsing (structured output, few-shot, error-driven refinement, ambiguity handling, temperature, negative constraints, evaluatio

</details>

---

### 2026-02-19 — 02d96d4 **[feature]**

Add rules/docs and fix expense parsing/flow

Scope: 10 files, +350 -81

<details>
<summary>Commit body</summary>

Add Firestore rules and docs for expense split semantics and prompt refinement; refine debug docs. Improve CycleRepository stability by adding onError handlers for streams, making addExpense/addExpenseFromMagicBar async, validating active cycles, defaulting empty participant lists to all group membe

</details>

---

### 2026-02-18 — 752b828 **[feature]**

Add safe route args and handle missing data

Scope: 7 files, +60 -30

<details>
<summary>Commit body</summary>

Introduce RouteArgs helpers and tighten argument/error handling across several screens. Changes:
- Add lib/utils/route_args.dart and reference it in screens.
- Use RouteArgs.getGroup/getMap in cycle_history_detail, cycle_settled, expense_input, and payment_result; pop silently if args are missing or

</details>

---

### 2026-02-18 — 3271755 **[other]**

Enhance profile uploads, deletion and confirm UX

Scope: 15 files, +494 -87

<details>
<summary>Commit body</summary>

Multiple improvements across profile, Firestore, parsing, and expense confirmation UX:

- Firestore: deleteGroup now removes current expenses, all settled cycle expenses and cycle docs in batched deletes (500) to avoid orphaned paths and console "This document does not exist" entries. Added _deleteC

</details>

---

### 2026-02-18 — 7dea1ad **[feature]**

Add user profile, avatar, UPI support and fixes

Scope: 26 files, +1235 -70

<details>
<summary>Commit body</summary>

Add Profile screen, ProfileService and MemberAvatar widget to support uploading and showing user avatars and saving a UPI ID. Persist photoURL and upiId in Firestore (FirestoreService.setUser), expose and sync them from CycleRepository (getters, update methods, load/write logic), and surface the pro

</details>

---

### 2026-02-18 — 1d797c2 **[feature]**

Add survey feature requests and responses PDF

Scope: 3 files, +92 -0

<details>
<summary>Commit body</summary>

Add docs/SURVEY_FEATURE_REQUESTS.md summarizing feature requests from the Jan 2026 Expenso idea survey and the raw export docs/Expenso_Survey_Form_Responses_Jan2026.pdf. Update APP_BLUEPRINT.md to reference the survey summary. The summary groups top asks (reminders, settlement/“I paid, don’t worry”,

</details>

---

### 2026-02-18 — 72d5741 **[feature]**

Add V1 release document and README link

Scope: 2 files, +194 -0

<details>
<summary>Commit body</summary>

Add docs/V1_RELEASE.md containing the formal Expenso V1 release contract (Magic Bar parser rules, Decision Clarity UI, Authority model, SettlementEngine spec and algorithm, Quality Bar, philosophy, and V2 "Not Now" list). Update README.md to include a link to the new V1 release document. This establ

</details>

---

### 2026-02-18 — 57f6716 **[feature]**

Add Decision Clarity, haptics, and cleanup

Scope: 25 files, +39 -81

<details>
<summary>Commit body</summary>

Introduce a Decision Clarity summary (docs + UI) and small UX improvements: add AnimatedSwitcher to DecisionClarity card and HapticFeedback.lightImpact on AI confirm and slidable actions. Update docs to mention computeNetBalances and the new summary card. Remove many placeholder/commented UI markers

</details>

---

### 2026-02-18 — a870bfa **[feature]**

Refactor GroupDetail UI and add net-balance API

Scope: 5 files, +322 -211

<details>
<summary>Commit body</summary>

Refactor GroupDetail layout and clarify settlement flow: compact header with centered group title, move member button, add a _DecisionClarityCard for pending/clarity, reorganize Settle/UPI actions and spacing; import shimmer and flutter services. Add a net-balance API in SettlementEngine: computeNet

</details>

---

### 2026-02-18 — 7dc1f58 **[doc]**

Revise README: clarify design and Smart Bar

Scope: 1 files, +20 -21

<details>
<summary>Commit body</summary>

Reworks README content for clarity and structure: replaces the generic Overview/Features sections with a focused “Why this design” and “What it does” layout, highlights settlement cycles and the single-group-creator model, and reorganizes the feature table for clearer descriptions. Marks the Smart B

</details>

---

### 2026-02-17 — af75f1c **[feature]**

Add splash, settlement engine & parser updates

Scope: 14 files, +721 -112

<details>
<summary>Commit body</summary>

Add a launch splash (assets + SplashScreen) and make '/splash' the initial route. Introduce a SettlementEngine util and wire it into GroupDetail to show a real “Balances” section. Expand the AI expense parser and Smart Bar to support new split types (percentage, shares), add a richer system prompt

</details>

---

### 2026-02-16 — e462f90 **[feature]**

Revise README: feature details & status

Scope: 1 files, +19 -15

<details>
<summary>Commit body</summary>

Rework README content to clarify current app behavior and UX. Renamed "What it does" to "What it does (current state)" and expanded entries: Groups list, Creator, Smart Bar (Groq / Llama 3.3), Expense log, Two‑phase settlement, Cycle history, Invite & members, and Data & rules. Updated Status sectio

</details>

---

### 2026-02-16 — 9c5887c **[feature]**

Add pinned groups & swipe actions

Scope: 7 files, +414 -112

<details>
<summary>Commit body</summary>

Introduce pinned-groups feature and swipe actions in the groups list. Adds PinnedGroupsService (SharedPreferences-backed, max 3 pins) and integrates it into GroupsList: swipe left to Pin/Unpin, pinned groups appear at the top (pin order preserved) and show a pin icon; creators get a swipe-right Dele

</details>

---

### 2026-02-16 — 1e72e6d **[other]**

Smart Bar, Groq parser improvements, UI tweaks

Scope: 12 files, +577 -296

<details>
<summary>Commit body</summary>

Rename Magic Bar → Smart Bar in docs and UI; move NLP input to a bottom Smart Bar component and adjust GroupDetail layout. Add richer participant resolution & confirmation flow (_ParticipantSlot, _ExpenseConfirmDialog), keyboard shortcut to open manual expense form, and better handling of payer/part

</details>

---

### 2026-02-16 — ebf0b22 **[feature]**

Add expense category & validation + tests

Scope: 11 files, +278 -53

<details>
<summary>Commit body</summary>

Introduce expense validation and category support across the app. Add lib/utils/expense_validation.dart with validateExpenseAmount/validateExpenseDescription and unit tests (test/expense_validation_test.dart). Extend Expense model to include an optional category and persist it in Firestore reads/wri

</details>

---

### 2026-02-16 — ea79514 **[other]**

Firestore backend, phone auth & Groq AI parser

Scope: 24 files, +1946 -339

<details>
<summary>Commit body</summary>

Introduce Firestore-backed data layer and Groq (Llama) Magic Bar parsing. Added .env.example and dotenv loading, ignored .env in .gitignore, and updated Android gradle props. Main now streams Firebase Auth (via PhoneAuthService) and shows a groups skeleton while loading. Added services: FirestoreSer

</details>

---

### 2026-02-15 — 652a32a **[feature]**

Add Firebase configs and platform options

Scope: 4 files, +97 -4

<details>
<summary>Commit body</summary>

Add Firebase configuration for Android and iOS: new android/app/google-services.json and ios/Runner/GoogleService-Info.plist. Update android/gradle.properties with a comment recommending Java 17. Replace the firebase_options.dart stub with a platform-aware implementation that provides FirebaseOption

</details>

---

### 2026-02-15 — 8247061 **[feature]**

Add optional Firebase phone auth support

Scope: 14 files, +330 -45

<details>
<summary>Commit body</summary>

Introduce optional Firebase phone/OTP authentication and integrate it into the app flow. main.dart now attempts Firebase.initializeApp() and sets a firebaseAuthAvailable flag (lib/firebase_app.dart); a firebase_options.dart stub is included for flutterfire configuration. PhoneAuth screen was updated

</details>

---

### 2026-02-15 — 93e2741 **[feature]**

Add docs rule and update README/APP_BLUEPRINT

Scope: 3 files, +16 -1

<details>
<summary>Commit body</summary>

Add a new .cursor rule (docs-on-app-changes.mdc) instructing maintainers to update README.md and APP_BLUEPRINT.md when adding features, changing behavior, or refactoring. Update APP_BLUEPRINT wording to explicitly mention updating sections 1–8 and README, and add a README comment reminding contribut

</details>

---

### 2026-02-15 — 7cd3d90 **[doc]**

Rewrite README layout and content

Scope: 1 files, +26 -30

<details>
<summary>Commit body</summary>

Reformatted and modernized the README: replaced plain prose with a centered intro, tagline and tech stack, and converted key concepts into a feature table for clearer scannability. Condensed the status section into a brief summary and added a small stack/docs table referencing APP_BLUEPRINT.md. Remo

</details>

---

### 2026-02-15 — 409ffb4 **[feature]**

Add proprietary LICENSE; update README

Scope: 2 files, +13 -0

<details>
<summary>Commit body</summary>

Add a LICENSE file declaring the repository proprietary and view-only (copyright 2025 Rishi Praseeth Krishnan). Update README to reference the new LICENSE and state that the source is for viewing only—no use, copy, or distribution without permission.

</details>

---

### 2026-02-15 — eee5c5e **[doc]**

Update README.md

Scope: 1 files, +40 -0

---

### 2026-02-15 — 75f65b0 **[feature]**

Add settling phase and archive/restart cycle

Scope: 3 files, +217 -175

<details>
<summary>Commit body</summary>

Introduce a two-phase settlement flow and update UI/logic accordingly.

- APP_BLUEPRINT.md: document the new CycleStatus flow (active → settling → closed+new), describe passive/settling UI behaviour and planned features (new §9).
- lib/repositories/cycle_repository.dart: prevent edits while a cycle

</details>

---

### 2026-02-15 — a04b68e **[feature]**

Add blueprint, auth flow & contacts support

Scope: 19 files, +835 -965

<details>
<summary>Commit body</summary>

Add APP_BLUEPRINT.md and consolidate navigation/auth logic and contact permissions. Implement initial-route decision in main.dart (uses CycleRepository to show PhoneAuth → OnboardingName → GroupsList), add onboarding_name screen, and update CycleRepository to store/set global phone and name via setG

</details>

---

### 2026-02-12 — 68968d3 **[other]**

Normalize screen filenames and update imports

Scope: 20 files, +27 -42

<details>
<summary>Commit body</summary>

Rename all screen files from PascalCase to snake_case (lib/screens/*.dart) and update imports in lib/main.dart and affected screens accordingly. Replace a debug print call (print -> debugPrint) in main.dart, fix imports to empty_states.dart in GroupDetail and GroupsList, adjust a minor widget tree f

</details>

---

### 2026-02-12 — ad15777 **[feature]**

Add member management, balances & UI updates

Scope: 14 files, +1026 -563

<details>
<summary>Commit body</summary>

Introduce member and creator metadata (Group.creatorId, Group.memberIds, Member.name) and extend Expense with participantPhones and paidByPhone. Refactor CycleRepository to manage members, provide currentUser stubs, add member add/remove, pending amount, balance calculation, settlement instructions

</details>

---

### 2026-02-12 — d475331 **[refactor]**

Remove figma UI bundle and update Dart screens

Scope: 85 files, +160 -7806

<details>
<summary>Commit body</summary>

Delete the entire figma design/prototype bundle (README, components, styles, configs and UI files) to remove unused React/Figma assets. Also apply updates to Dart code: lib/repositories/cycle_repository.dart and several screens (CreateGroup.dart, CycleSettled.dart, EditExpense.dart, GroupDetail.dart

</details>

---

### 2026-02-12 — 1a2b9a2 **[other]**

Use Cycle model in CycleHistoryDetail

Scope: 2 files, +12 -23

<details>
<summary>Commit body</summary>

Replace hardcoded/default props and sample expenses in CycleHistoryDetail with real Cycle data passed via route arguments. The screen now reads a Map args (expects 'cycle' and 'groupName'), builds cycleDate from start/end, computes settledAmount by summing expense amounts, and uses cycle.expenses fo

</details>

---

### 2026-02-12 — a51c6a6 **[feature]**

Add Cycle model & repository, connect screens

Scope: 12 files, +611 -458

<details>
<summary>Commit body</summary>

Introduce a Cycle model and CycleRepository singleton (ChangeNotifier) to manage cycles and expenses in-memory. Move HistoryCycle into models.dart and implement repository APIs (getActiveCycle, add/update/getExpense, settleAndRestartCycle, getHistory). Update many screens to consume the repository a

</details>

---

### 2026-01-13 — e98f105 **[doc]**

Update README.md

Scope: 1 files, +1 -16

---

### 2026-01-13 — b16cdeb **[other]**

Initial project setup with all core files

Scope: 234 files, +18065 -0

<details>
<summary>Commit body</summary>

Add initial Flutter project structure including platform-specific files for Android, iOS, macOS, Linux, and Windows. Include main Dart source files, shared data models, navigation and screen implementations, Figma UI assets, configuration files, and documentation for bug tracking, exceptions, and fl

</details>

---

*Generated from Git commits. Deterministic; no LLM inference.*
