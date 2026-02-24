# Expenso

**Group expense tracking done right.** Track who paid what, see who owes whom, settle via UPI, repeat.

```
  ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐
  │  ADD    │      │  TRACK  │      │  SEE    │      │  PAY    │
  │ EXPENSE │ ───► │ SPLITS  │ ───► │ BALANCE │ ───► │  & GO   │
  └─────────┘      └─────────┘      └─────────┘      └─────────┘
      │                                                   │
      └───────────────────── REPEAT ◄─────────────────────┘
```

> *"Dinner 1200 with Ash"* → Magic Bar parses it → Split calculated → Everyone knows what they owe

---

## Project Overview

Expenso is a Flutter app that solves shared-expense tracking for small groups (friends, roommates, trips). It removes the pain of manual tallying and "who paid for what" confusion by enforcing a clear model: one group creator, an active expense cycle, and a two-phase settlement (freeze cycle, then archive and start new). Expenses are recorded with flexible splits (even, exact, exclude, percentage, shares); balances and settlement instructions are derived automatically. In-app settlement via UPI with app picker (GPay, PhonePe, Paytm, etc.). The app exists to give groups a single source of truth and a repeatable way to settle and reset.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           THE EXPENSO CYCLE                                  │
└─────────────────────────────────────────────────────────────────────────────┘

     ┌──────────┐          ┌──────────┐          ┌──────────┐
     │  CREATE  │          │  TRACK   │          │  SETTLE  │
     │  GROUP   │────────► │ EXPENSES │────────► │    UP    │
     └──────────┘          └──────────┘          └──────────┘
          │                      │                     │
          │                      │                     │
          ▼                      ▼                     ▼
   ┌─────────────┐        ┌─────────────┐       ┌─────────────┐
   │ Add members │        │ "Dinner     │       │ Pay via UPI │
   │ via phone   │        │  1200 with  │       │ (GPay, etc) │
   │ or contacts │        │  Ash"      │       │ or Cash     │
   └─────────────┘        └─────────────┘       └─────────────┘
                                │                     │
                                ▼                     ▼
                         ┌─────────────┐       ┌─────────────┐
                         │ Auto-split  │       │ Start new   │
                         │ & balance   │       │ cycle ──────┼──────┐
                         │ calculation │       │             │      │
                         └─────────────┘       └─────────────┘      │
                                                                    │
                                ┌───────────────────────────────────┘
                                │
                                ▼
                         ┌─────────────┐
                         │   REPEAT    │
                         │   ∞         │
                         └─────────────┘
```

---

## Expense Entry — Magic Bar

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NATURAL LANGUAGE INPUT                               │
└─────────────────────────────────────────────────────────────────────────────┘

  You type:                          Expenso understands:
  ─────────                          ────────────────────

  "Dinner 1200 with Ash"       ──►  ₹1,200 • Dinner • Split with Ash

  "Auto 450 paid by Ash"         ──►  ₹450 • Auto • Ash paid • Split all

  "Groceries 800 exclude Ash" ──►  ₹800 • Groceries • Exclude Ash from split

  "Movie 300 Ash Ash"           ──►  ₹300 • Movie • Split: You + Ash + Ash

                                          │
                                          ▼
                                   ┌─────────────┐
                                   │  CONFIRM &  │
                                   │    SAVE     │
                                   └─────────────┘
```

---

## Settlement Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PAYMENT & CONFIRMATION                               │
└─────────────────────────────────────────────────────────────────────────────┘

  PAYER                                              RECEIVER
  ─────                                              ────────

  ┌─────────────────┐                          ┌─────────────────┐
  │  "Settle now"   │                          │                 │
  │                 │                          │                 │
  │  You owe ₹450   │                          │  ₹450 incoming  │
  │  to Ash         │                          │  from Ash    │
  └────────┬────────┘                          └────────┬────────┘
           │                                            │
           ▼                                            │
  ┌─────────────────┐                                   │
  │  Pay via UPI    │                                   │
  │  ┌────┬────┬────┤                                   │
  │  │GPay│PhPe│Paytm                                   │
  │  └────┴────┴────┘                                   │
  └────────┬────────┘                                   │
           │                                            │
           ▼                                            │
  ┌─────────────────┐                                   │
  │  Payment sent   │                                   │
  │  ─────────────  │                                   │
  │  Mark as paid ✓ │──────────── notification ────────►│
  └────────┬────────┘                                   │
           │                                            ▼
           │                                   ┌─────────────────┐
           │                                   │  Confirm        │
           │                                   │  received? ✓    │
           │                                   └────────┬────────┘
           │                                            │
           ▼                                            ▼
  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │                      ✓ SETTLED                              │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘
```

---

## Decision Clarity Card

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ALWAYS KNOW WHERE YOU STAND                          │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────┐
                    │                                 │
                    │   CYCLE TOTAL      ₹4,500       │
                    │   ─────────────────────────     │
                    │   You spent        ₹2,100       │
                    │   Your share       ₹1,500       │
                    │   ─────────────────────────     │
                    │                                 │
                    │   ┌─────────────────────────┐   │
                    │   │  YOU GET BACK  ₹600  ▲  │   │  ◄── Green = others owe you
                    │   └─────────────────────────┘   │
                    │                                 │
                    │           ── or ──              │
                    │                                 │
                    │   ┌─────────────────────────┐   │
                    │   │  YOU OWE      ₹300   ▼  │   │  ◄── Red = you owe others
                    │   └─────────────────────────┘   │
                    │                                 │
                    └─────────────────────────────────┘
```

---

## Key Features

- **Groups** — Create groups, add members by phone or contacts, pin up to 3 groups, delete (creator only).
- **Expenses** — Add via Magic Bar (natural language, Groq/Llama) or manual form. Splits: Even, Exact, Exclude, Percentage, Shares. Decision Clarity card shows cycle total, spent-by-you, and your net status (credit/debt).
- **Settlement** — Two-phase: Settle (freeze cycle) then Start New Cycle (creator). Pay dues via in-app UPI (select from installed apps like GPay, PhonePe, Paytm) or cash. Payment tracking with payer/receiver confirmation flow.
- **Profile** — Display name, avatar (Firebase Storage), UPI ID for payment settings, logout.
- **Auth** — Phone (OTP) sign-in via Firebase when configured; optional mock flow when not.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW                                       │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
  │    USER      │     │   FLUTTER    │     │   FIREBASE   │
  │   ACTION     │────►│     APP      │────►│  FIRESTORE   │
  └──────────────┘     └──────────────┘     └──────────────┘
                              │                    │
                              │                    │
                       ┌──────┴──────┐      ┌──────┴──────┐
                       │             │      │             │
                       ▼             ▼      ▼             ▼
                ┌───────────┐  ┌─────────┐  ┌─────────────────┐
                │  MAGIC    │  │ SETTLE- │  │     REAL-TIME   │
                │   BAR     │  │  MENT   │  │      SYNC       │
                │  (Groq)   │  │ ENGINE  │  │                 │
                └───────────┘  └─────────┘  └─────────────────┘
                     │              │              │
                     │              ▼              │
                     │       ┌───────────┐         │
                     │       │  BALANCE  │         │
                     └──────►│   CALC    │◄────────┘
                             └───────────┘
                                   │
                                   ▼
                            ┌─────────────┐
                            │  DECISION   │
                            │  CLARITY    │
                            │   CARD      │
                            └─────────────┘
```

| Layer | Component | Role |
|-------|-----------|------|
| **UI** | Screens, Widgets | User interaction |
| **State** | CycleRepository | Single source of truth, Firestore sync |
| **Logic** | SettlementEngine | Balance math, debt minimization |
| **AI** | GroqExpenseParserService | Natural language → structured expense |
| **Payments** | UpiPaymentService | UPI app discovery, deep links |
| **Backend** | Firebase (Auth, Firestore, Storage) | Persistence, real-time sync |

On launch, the app shows a splash then routes by Firebase Auth state: unauthenticated users see Phone Auth; authenticated users sync identity to a singleton `CycleRepository` and then either onboarding (name) or the groups list. The repository subscribes to Firestore streams for groups (where the user is a member) and each group’s current-cycle expenses; it maintains in-memory state (`_groups`, `_expensesByCycleId`, `_membersById`) and notifies listeners. Group detail reads the active cycle and uses `SettlementEngine` to compute debts and net balances for the Decision Clarity card and Balances section. Expense writes go to `groups/{groupId}/expenses`; settlement is creator-only: Phase 1 sets cycle status to `settling`, Phase 2 archives expenses into `settled_cycles/{cycleId}/expenses`, clears current expenses, and creates a new active cycle. Magic Bar calls `GroqExpenseParserService` (with optional local number fallback); the result is confirmed in UI then persisted via `CycleRepository.addExpenseFromMagicBar`. Payments use `upi_india` to detect installed UPI apps and launch transactions directly; payment attempts are tracked in Firestore with payer/receiver confirmation states.

---

## Tech Stack

- **Client:** Flutter (Dart), Material 3
- **Backend / services:** Firebase (Phone Auth, Cloud Firestore, Cloud Functions, Storage)
- **APIs:** Groq (Llama 3.3 70B) for natural-language expense parsing
- **Payments:** UPI deep links via `upi_india` package (GPay, PhonePe, Paytm, BHIM, etc.)
- **Local:** SharedPreferences (pinned groups), `flutter_contacts`, `flutter_dotenv` (e.g. `GROQ_API_KEY`)

---

## Getting Started

### Prerequisites

- Flutter SDK (Dart 3.10+)
- Firebase project with Phone Auth, Firestore, and (optional) Storage and Cloud Functions
- For Magic Bar: Groq API key
- For in-app UPI payments: Android device with UPI apps installed (GPay, PhonePe, etc.)

### Installation

```bash
git clone <repo-url>
cd Expenso
flutter pub get
```

### Configuration

- **Firebase:** Run `dart run flutterfire configure` to generate `lib/firebase_options.dart` and link Android/iOS. Enable Phone sign-in in Firebase Console. Deploy Firestore rules from `firestore.rules` (Console or `firebase deploy --only firestore`).
- **Environment:** Create a `.env` in the project root (listed in `pubspec.yaml` assets). Set `GROQ_API_KEY` for Magic Bar; omit for manual-only expense entry.
- **UPI Payments:** No configuration needed. The app detects installed UPI apps automatically on Android. On iOS, add UPI URL schemes to `Info.plist` (already configured).
- **Data encryption (optional):** To encrypt sensitive data at rest, set `DATA_ENCRYPTION_MASTER_KEY` in Firebase Functions config. Use a 32-byte key as **64 hex characters** (e.g. `9f3c7a1d8b4e2f0c...` — 64 chars total). Deploy `getUserEncryptionKey` and `getGroupEncryptionKey`; the app will encrypt/decrypt automatically when the key is available.

### Running locally

```bash
flutter run
```

Use a device or emulator with the same Firebase/Google config (e.g. `google-services.json` / `GoogleService-Info.plist`) as your project.

---

## Usage

- **Groups:** From the groups list, use the FAB to create a group, then add members (phone or contacts; supports 15 international country codes). Swipe left to pin/unpin (max 3), swipe right to delete (creator only).
- **Expenses:** In group detail, use the Magic Bar (e.g. "Dinner 1200 with Ash") or tap to add manually. Choose payer, split type, and participants; confirm. Recent add shows an undo screen for a few seconds.
- **Settlement:** Creator taps "Settle now" to freeze the cycle; when status is "Settling", creator taps "Start New Cycle" to archive and begin a new cycle. Members pay dues via UPI (in-app picker shows installed apps) or mark cash payments; receivers confirm receipt.
- **Profile:** Set display name (used in Magic Bar matching), avatar, and UPI ID. Log out to switch accounts.

Detailed flows, routes, and logic are in [APP_BLUEPRINT.md](APP_BLUEPRINT.md). Additional docs are in [docs/](docs/):
- [PRODUCT_NORTH_STAR.md](docs/PRODUCT_NORTH_STAR.md) — Core product philosophy ("I want my money back — without asking")
- [STABILIZATION.md](docs/STABILIZATION.md) — Invariants, limitations, and change safety guidance
- [DATA_SPINE.md](docs/DATA_SPINE.md) — Formal data entity definitions
- [DATA_FLOW_TABLES.md](docs/DATA_FLOW_TABLES.md) — Screen-to-database data mapping (SQL table format)
- [features/MONEY_BALANCE_LOGIC.md](docs/features/MONEY_BALANCE_LOGIC.md) — Balance computation specification
- [features/MONEY_TESTS.md](docs/features/MONEY_TESTS.md) — Golden test cases for balance computation
- [features/MONEY_CANONICALIZATION.md](docs/features/MONEY_CANONICALIZATION.md) — Canonical implementation plan
- [features/MONEY_PHASE2.md](docs/features/MONEY_PHASE2.md) — Phase 2 invariant enforcement plan

---

## Project Status

Expenso is at **V4** (in progress). Core logic (expense recording, split calculation, settlement engine, cycle management) is stable. All primary flows are implemented, tested where critical, and documented. V4 adds cross-group identity, global balance view, and debt minimization. See [docs/releases/V4_RELEASE.md](docs/releases/V4_RELEASE.md) for the current release scope.

**Past releases:** V3 added logout, international phone number support (15 countries), settlement activity feed, offline resilience, and Dynamic UPI QR. See [docs/releases/V3_RELEASE.md](docs/releases/V3_RELEASE.md).

**Planned features** (not yet implemented) are listed in APP_BLUEPRINT.md Section 9. No timeline commitments.

---

## Contributing

This repository is shared for reference. If you have permission to contribute: prefer small, focused PRs; follow the logic and conventions in APP_BLUEPRINT.md and the existing code style; run `flutter test` before submitting. For behavioral or product changes, align with the release contracts in `docs/releases/`.

---

## License

Proprietary. Copyright (c) 2025 Rishi Praseeth Krishnan. All rights reserved. This repository and source code are made visible for viewing and reference only. No license is granted to use, copy, modify, distribute, or create derivative works without express written permission from the copyright holder. See [LICENSE](LICENSE).
