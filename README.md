# Expenso

Group expense tracking with settlement cycles and one creator per group. Track who paid what, see live who owes whom, and close the loop with Settle then Start New Cycle. Optional natural-language input (Magic Bar) for quick expense entry.

---

## Project Overview

Expenso is a Flutter app that solves shared-expense tracking for small groups (friends, roommates, trips). It removes the pain of manual tallying and "who paid for what" confusion by enforcing a clear model: one group creator, an active expense cycle, and a two-phase settlement (freeze cycle, then archive and start new). Expenses are recorded with flexible splits (even, exact, exclude, percentage, shares); balances and settlement instructions are derived automatically. In-app settlement can be completed via Razorpay Checkout. The app exists to give groups a single source of truth and a repeatable way to settle and reset.

---

## Key Features

- **Groups** — Create groups, add members by phone or contacts, pin up to 3 groups, delete (creator only).
- **Expenses** — Add via Magic Bar (natural language, Groq/Llama) or manual form. Splits: Even, Exact, Exclude, Percentage, Shares. Decision Clarity card shows cycle total, spent-by-you, and your net status (credit/debt).
- **Settlement** — Two-phase: Settle (freeze cycle) then Start New Cycle (creator). Settle up via Razorpay Checkout for in-app payment of dues; optional UPI/system flow.
- **Profile** — Display name, avatar (Firebase Storage), UPI ID for payment settings.
- **Auth** — Phone (OTP) sign-in via Firebase when configured; optional mock flow when not.

---

## Architecture / How It Works

On launch, the app shows a splash then routes by Firebase Auth state: unauthenticated users see Phone Auth; authenticated users sync identity to a singleton `CycleRepository` and then either onboarding (name) or the groups list. The repository subscribes to Firestore streams for groups (where the user is a member) and each group’s current-cycle expenses; it maintains in-memory state (`_groups`, `_expensesByCycleId`, `_membersById`) and notifies listeners. Group detail reads the active cycle and uses `SettlementEngine` to compute debts and net balances for the Decision Clarity card and Balances section. Expense writes go to `groups/{groupId}/expenses`; settlement is creator-only: Phase 1 sets cycle status to `settling`, Phase 2 archives expenses into `settled_cycles/{cycleId}/expenses`, clears current expenses, and creates a new active cycle. Magic Bar calls `GroqExpenseParserService` (with optional local number fallback); the result is confirmed in UI then persisted via `CycleRepository.addExpenseFromMagicBar`. Razorpay orders are created by a callable Cloud Function; the client opens Razorpay Checkout with the returned order ID and key.

---

## Tech Stack

- **Client:** Flutter (Dart), Material 3
- **Backend / services:** Firebase (Phone Auth, Cloud Firestore, Cloud Functions, Storage)
- **APIs:** Groq (Llama 3.3 70B) for natural-language expense parsing; Razorpay for in-app settlement
- **Local:** SharedPreferences (pinned groups), `flutter_contacts`, `flutter_dotenv` (e.g. `GROQ_API_KEY`)

---

## Getting Started

### Prerequisites

- Flutter SDK (Dart 3.10+)
- Firebase project with Phone Auth, Firestore, and (optional) Storage and Cloud Functions
- For Magic Bar: Groq API key
- For in-app payments: Razorpay keys and deployed `createRazorpayOrder` function

### Installation

```bash
git clone <repo-url>
cd Expenso
flutter pub get
```

### Configuration

- **Firebase:** Run `dart run flutterfire configure` to generate `lib/firebase_options.dart` and link Android/iOS. Enable Phone sign-in in Firebase Console. Deploy Firestore rules from `firestore.rules` (Console or `firebase deploy --only firestore`).
- **Environment:** Create a `.env` in the project root (listed in `pubspec.yaml` assets). Set `GROQ_API_KEY` for Magic Bar; omit for manual-only expense entry.
- **Razorpay:** Configure key/secret in Firebase Functions (e.g. `firebase functions:config:set razorpay.key_id="..." razorpay.key_secret="..."` or env vars in Console). See `functions/README.md` for the callable setup.
- **Data encryption (optional):** To encrypt sensitive data at rest, set `DATA_ENCRYPTION_MASTER_KEY` in Firebase Functions config. Use a 32-byte key as **64 hex characters** (e.g. `9f3c7a1d8b4e2f0c...` — 64 chars total). Deploy `getUserEncryptionKey` and `getGroupEncryptionKey`; the app will encrypt/decrypt automatically when the key is available.

### Running locally

```bash
flutter run
```

Use a device or emulator with the same Firebase/Google config (e.g. `google-services.json` / `GoogleService-Info.plist`) as your project.

---

## Usage

- **Groups:** From the groups list, use the FAB to create a group, then add members (phone or contacts). Swipe left to pin/unpin (max 3), swipe right to delete (creator only).
- **Expenses:** In group detail, use the Magic Bar (e.g. "Dinner 1200 with Pradhyun") or tap to add manually. Choose payer, split type, and participants; confirm. Recent add shows an undo screen for a few seconds.
- **Settlement:** Creator taps "Settle now" to freeze the cycle; when status is "Settling", creator taps "Start New Cycle" to archive and begin a new cycle. Use "Settle up" / "Pay via UPI" to pay dues via Razorpay Checkout.
- **Profile:** Set display name (used in Magic Bar matching), avatar, and UPI ID.

Detailed flows, routes, and logic are in [APP_BLUEPRINT.md](APP_BLUEPRINT.md). Additional docs (architecture, development timeline, audits, research) are in [docs/](docs/). For a stabilization analysis covering invariants, limitations, and change safety guidance, see [docs/STABILIZATION.md](docs/STABILIZATION.md). For formal data entity definitions, see [docs/DATA_SPINE.md](docs/DATA_SPINE.md).

---

## Project Status

Expenso is a **stabilized v1**. Core logic (expense recording, split calculation, settlement engine, cycle management) is considered frozen. All primary flows are implemented, tested where critical, and documented. Future changes should be incremental and cautious—consult [docs/STABILIZATION.md](docs/STABILIZATION.md) for invariants, known limitations, and change safety guidance before modifying core behavior.

**Planned features** (not yet implemented) are listed in APP_BLUEPRINT.md Section 9. No timeline commitments.

---

## Contributing

This repository is shared for reference. If you have permission to contribute: prefer small, focused PRs; follow the logic and conventions in APP_BLUEPRINT.md and the existing code style; run `flutter test` before submitting. For behavioral or product changes, align with the V1 contract in `docs/V1_RELEASE.md` where applicable.

---

## License

Proprietary. Copyright (c) 2025 Rishi Praseeth Krishnan. All rights reserved. This repository and source code are made visible for viewing and reference only. No license is granted to use, copy, modify, distribute, or create derivative works without express written permission from the copyright holder. See [LICENSE](LICENSE).
