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
> It’s built around settlement cycles, a single creator per group, and a system-enforced workflow—no manual reminders, no awkward follow-ups.

---

## What it does (current state)

| | |
|:---|:---|
| **Groups list** | All groups you’re in. **Swipe left** = Pin/Unpin (max 3 pinned; pinned stay at top). **Swipe right** = Delete group (creator only; confirm then removed from Firestore). Black FAB = create group. |
| **Creator** | One creator per group: 👑 in member list, can Settle, Start New Cycle, and Delete group. |
| **Smart Bar** | At bottom of group detail: type e.g. “Dinner 500 with Pradhyun” → Groq (Llama 3.3) parses to amount, description, split type, participants. Confirm dialog with per-person amounts; exact splits validated. Keyboard icon = manual expense form. |
| **Expense log** | List of current-cycle expenses (description, date, amount). Tap to edit (creator can edit even when settling). “Dinner 2000” in a 2-person group → “Dinner – with [other]”; no “with” → no suffix. |
| **Two-phase settlement** | **Settle now** (creator) → confirm → cycle goes to **Settling** (frozen), then one tap **Start New Cycle** closes and starts a new cycle at ₹0. “Pay via UPI” path uses settlement-confirmation screen. |
| **Cycle history** | Past settled cycles and archived expenses per group. |
| **Invite & members** | Add by phone/name; contact suggestions via `flutter_contacts`. Member list shows 👑 next to creator. |
| **Data & rules** | All logic in `CycleRepository`; Firestore for users, groups, expenses, settled_cycles. Phone auth (Firebase); **GROQ_API_KEY** in `.env` for Smart Bar. |

---

## Status

**Backend:** Cloud Firestore (Test Mode). All writes use the real Firebase Auth `User.uid`. No mock user.

| | |
|:---|:---|
| **Stack** | Flutter (Dart), Material 3, Cloud Firestore |
| **Auth** | Firebase Auth (phone/OTP). `PhoneAuthService`: verifyPhoneNumber, OTP; test-number hint (code 123456). Run `dart run flutterfire configure`, enable Phone sign-in and Firestore. |
| **Firestore** | `users` (uid → displayName, phoneNumber), `groups` (groupName, members, creatorId, activeCycleId, cycleStatus), `groups/{id}/expenses` (current cycle), `groups/{id}/settled_cycles/{cycleId}` (archived). Creator can delete group doc via `deleteGroup`. |
| **Creator** | Only `creatorId` can Settle, Archive/Start New Cycle, and Delete group; `isCurrentUserCreator(groupId)` gates the UI. |
| **Pinned groups** | User preference (max 3) in SharedPreferences; list sorted pinned-first. |
| **Env** | `.env` with **GROQ_API_KEY** for Smart Bar. `.env` is gitignored; loaded in `main()` via `flutter_dotenv`. |
| **Loading** | Auth/groups loading show Groups scaffold with list **skeleton shimmer**. |
| **Tests** | `flutter test` — expense validation and `ParsedExpenseResult` (Groq parser). |
| **Docs** | [APP_BLUEPRINT.md](APP_BLUEPRINT.md) — routes, screens, data layer, design, conventions. |

---

## License

See [LICENSE](LICENSE).
