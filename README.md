# Expenso

**Group expense management with settlement cycles and natural-language expense entry.**

Expenso is a mobile-first expense ledger for shared spending. It uses **settlement cycles**, a single group creator, and a structured workflow so groups can track who paid what, see who owes whom, and close cycles without manual chasing.

---

## Overview

- **Group-centric:** Create groups, add members (phone/contacts), and track expenses per group.
- **Settlement cycles:** Each group has an active cycle. Creator can **Settle** (freeze the cycle), then **Start New Cycle** to archive and begin fresh.
- **Smart Bar:** Type natural language (e.g. “Dinner 500 with Pradhyun”) — parsed by AI (Groq/Llama) into amount, description, split type, and participants. Manual expense form available.
- **Live balances:** Per-group view of who owes whom, computed from current expenses and splits.
- **Cycle history:** Past settled cycles and archived expenses per group.

---

## Features

| Area | Description |
|------|-------------|
| **Groups** | List all groups; pin/unpin (max 3); delete (creator only). Create via FAB. |
| **Creator** | One creator per group (crown in UI); only creator can Settle, Start New Cycle, and Delete group. |
| **Expenses** | Add via Smart Bar (NLP) or manual form. Edit/undo; description, date, amount, splits (Even / Exact / Exclude). |
| **Balances** | Real-time “who owes whom” from settlement engine; shown in group detail when cycle has expenses. |
| **Settlement** | Two-phase: Settle → cycle status “Settling”; then Start New Cycle to archive and begin new cycle. Optional “Pay via UPI” flow. |
| **Auth & data** | Firebase Phone Auth (OTP). Cloud Firestore for users, groups, expenses, settled cycles. |

---

## Tech stack

- **Flutter** (Dart), **Material 3**
- **Firebase:** Auth (phone/OTP), Cloud Firestore
- **Smart Bar:** Groq API (Llama 3.3) for parsing natural-language expenses
- **Local:** SharedPreferences (pinned groups), `flutter_contacts` (invite suggestions), `flutter_dotenv` (env)

---

## Getting started

### Prerequisites

- Flutter SDK (see `pubspec.yaml` for Dart constraint)
- Firebase project with Phone sign-in and Firestore enabled
- [FlutterFire CLI](https://firebase.flutter.dev/docs/overview): `dart run flutterfire configure`

### Setup

1. **Clone and install**
   ```bash
   git clone https://github.com/<your-org>/Expenso.git
   cd Expenso
   flutter pub get
   ```

2. **Environment**
   - Create a `.env` in the project root (gitignored).
   - Add `GROQ_API_KEY=<your-groq-api-key>` for the Smart Bar.

3. **Firebase**
   - Run `dart run flutterfire configure`.
   - Enable **Phone** in Authentication → Sign-in method.
   - Use Test Mode or configure Firestore rules as needed.

### Run

```bash
flutter run
```

For phone auth in development, the app supports a test-number hint (code `123456`) when configured.

---

## Configuration

| Item | Purpose |
|------|--------|
| `.env` | `GROQ_API_KEY` — used by Smart Bar for expense parsing. |
| Firebase | Phone Auth + Firestore; config via `flutterfire configure` and Console. |
| Pinned groups | Stored in SharedPreferences (max 3 per user). |

---

## Testing

```bash
flutter test
```

Tests cover expense validation and the Groq `ParsedExpenseResult` parser.

---

## Documentation

- **[APP_BLUEPRINT.md](APP_BLUEPRINT.md)** — Routes, screens, data layer, design system, conventions, and file layout. Use as the main reference for implementation and contributions.

---

## License

See [LICENSE](LICENSE).
