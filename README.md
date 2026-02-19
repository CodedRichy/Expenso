# Expenso

Group expense tracking with **settlement cycles** and **one creator per group**. Track who paid what, see live “who owes whom,” and close the loop with **Settle** → **Start New Cycle**. Optional **Magic Bar** (natural language) for quick entry.

*This repo is my implementation; shared to show the work.*

---

## What it does

- **Groups** — Create, add members by phone/contacts, pin (max 3), delete (creator only).
- **Expenses** — Add via Magic Bar (Groq/Llama) or manual form. Splits: Even, Exact, Exclude, Percentage, Shares. Decision Clarity card: cycle total, spent by you, your status.
- **Settlement** — Settle (freeze cycle) → Start New Cycle (creator). Settle up via Razorpay Checkout for in-app payment of dues.
- **Profile** — Display name, avatar (Firebase Storage), UPI ID.

---

## Tech stack

- **Flutter** (Dart), Material 3
- **Firebase** — Phone Auth, Cloud Firestore, Cloud Functions (Razorpay order), Storage (avatars)
- **Magic Bar** — Groq API (Llama 3.3) for NL expense parsing (optional)
- **Local** — SharedPreferences (pinned groups), `flutter_contacts`, `flutter_dotenv`

---

## Run locally

Requires Flutter, a Firebase project (Phone Auth, Firestore, optional Storage & Functions), and optionally `.env` with `GROQ_API_KEY` for the Magic Bar.

```bash
flutter pub get
flutter run
```

Full setup (Firebase config, Firestore rules, Razorpay keys, etc.) is in **[APP_BLUEPRINT.md](APP_BLUEPRINT.md)** and **docs/** if you want to run or extend it.

---

## Tests

```bash
flutter test
```

Covers expense validation, parser (splits, participants), and settlement engine.

---

## License

See [LICENSE](LICENSE).
