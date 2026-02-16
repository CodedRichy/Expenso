<!-- When adding features or changing the app, update README.md and APP_BLUEPRINT.md. -->

<p align="center">
  <strong>Expenso</strong>
</p>
<p align="center">
  <em>System-driven group expense management</em>
</p>
<p align="center">
  <sub>Flutter · Dart · Material 3</sub>
</p>

---

> Expenso is a group-centric expense ledger designed to **eliminate the social friction** of shared spending.  
> Unlike traditional split-based apps, it’s built around settlement cycles, centralized authority, and a system-enforced workflow—no manual reminders, no awkward follow-ups.

---

## What it does

| | |
|:---|:---|
| **NLP expense entry** | Log with natural language via the **Magic Bar** (Groq + Llama 3) on group detail, or the manual expense form. Amounts, participants, category, split type (even / exact / exclude), and payer are parsed. Confirmation shows per-person amounts; for exact splits the sum is validated before saving. |
| **Creator-led groups** | One creator per group with full control over cycles, settlements, and ledger integrity. |
| **Two-phase settlement** | Cycles move **Active → Settling → Closed** so expenses are frozen and verifiable before archival. |
| **Repository-first logic** | Rules live in the data layer, not in the UI—predictable behavior and ready for backend integration. |
| **Minimal UI** | High-contrast, fast to scan. Readability and trust over decoration. |

---

## Status

**Backend:** Cloud Firestore (Test Mode) with real split logic and archive. **Auth** is Firebase-only: `onAuthStateChanged` drives the app (logged in → ledger; not → login). All UIDs come from Firebase Auth; no mock user.

| | |
|:---|:---|
| **Stack** | Flutter (Dart), Material 3, Cloud Firestore |
| **Auth** | Firebase Auth (phone/OTP). `PhoneAuthService` handles verifyPhoneNumber, codeSent, verificationCompleted; errors and test-number hint (code 123456). Run `dart run flutterfire configure`, enable Phone sign-in and Firestore in Firebase Console. |
| **Firestore** | `users` (uid → displayName, phoneNumber, photoURL), `groups` (groupName, members, creatorId, activeCycleId, cycleStatus), `groups/{id}/expenses` (current cycle), `groups/{id}/settled_cycles/{cycleId}` (archived). Settle moves cycle to settling; only creator can archive (expenses → settled_cycles) and start new cycle. |
| **Creator** | Only `creatorId` can trigger Settle and Archive; `isCurrentUserCreator(groupId)` gates the UI. |
| **Env** | `.env` for secrets (e.g. **GROQ_API_KEY** for the Magic Bar AI parser). Copy `.env.example` to `.env`. `.env` is gitignored; loaded in `main()` via `flutter_dotenv`. |
| **Loading UX** | No full-screen buffer: auth or groups loading show the Groups scaffold with a list **skeleton shimmer** (same chrome, animated placeholders). |
| **Testing** | Unit tests for expense validation (`lib/utils/expense_validation.dart`) and Groq parser result (`ParsedExpenseResult`). Run: `flutter test`. |
| **Docs** | [APP_BLUEPRINT.md](APP_BLUEPRINT.md) — routes, screens, data layer, Firestore layout, conventions |

---

## License

See [LICENSE](LICENSE).
