# Expenso

**Group expense tracking with settlement cycles and one creator per group.** Most expense apps never close the loop: you see who owes what, but there’s no clear “we’re settled” moment, and anyone can change the group. Expenso gives each group a single creator, explicit **Settlement** and **Start New Cycle** actions, and live balances so groups can close cycles and start fresh without ambiguity.

---

## Why this design

Typical split apps keep one endless ledger. That leads to drift (old debts mixed with new), unclear ownership of the group, and no built-in way to say “this period is done.” Expenso addresses that with:

- **Settlement cycles** — The creator can **Settle** (freeze the current cycle) and **Start New Cycle** to archive expenses and begin a new period. Past cycles stay in history; the active view is always the current cycle only.
- **Single group creator** — One creator per group (shown in the UI). Only the creator can Settle, Start New Cycle, and delete the group. No committee, no confusion about who can close a cycle.

The rest of the app is built around that: per-group expense log, real-time “who owes whom” from a deterministic settlement engine, and optional natural-language entry (Smart Bar) for faster input.

---

## What it does

| Area | Description |
|------|-------------|
| **Groups** | Create groups via FAB; add members by phone or contacts. List shows all groups; pin/unpin (max 3); delete (creator only). |
| **Creator** | One creator per group; only creator can Settle, Start New Cycle, and Delete group. |
| **Expenses** | Add via Smart Bar (natural language, parsed by optional Groq/Llama integration) or manual form. Edit/undo; description, date, amount; splits: Even, Exact, or Exclude. Light haptic on AI parse success and on manual confirm. |
| **Summary card** | Group detail shows a “Decision Clarity” card: cycle total, spent by you, your status (credit/debt). Empty cycle shows “Zero-Waste Cycle” and a prompt to use the Magic Bar. |
| **Balances** | Per-group “who owes whom” from the settlement engine; shown when the cycle has expenses. |
| **Settlement** | Two steps: **Settle** (cycle status → “Settling”), then **Start New Cycle** (creator only) to archive and start a new cycle. Optional “Pay via UPI” flow. |
| **Auth & data** | Firebase Phone Auth (OTP). Cloud Firestore for users, groups, expenses, and settled cycles. |

---

## Tech stack

- **Flutter** (Dart), **Material 3**
- **Firebase:** Auth (phone/OTP), Cloud Firestore
- **Smart Bar:** Groq API (Llama 3.3) for parsing natural-language expenses (optional; requires `GROQ_API_KEY`)
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
   - Add `GROQ_API_KEY=<your-groq-api-key>` for the Smart Bar (optional; manual expense entry works without it).

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
|------|---------|
| `.env` | `GROQ_API_KEY` — used by Smart Bar for expense parsing (optional). |
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

- **[APP_BLUEPRINT.md](APP_BLUEPRINT.md)** — Routes, screens, data layer, design system, conventions, and file layout. Primary reference for implementation and contributions.

---

## License

See [LICENSE](LICENSE).
