# How to Reach the 90s — Expenso

Concrete steps to move **App** from 78 → 90+ and **UI** from 82 → 90+, using the same criteria as the [PRE_RELEASE_AUDIT](PRE_RELEASE_AUDIT.md) scorecard.

---

## 1. Privacy policy in the app (App + store requirement)

**What:** Give users a way to open your privacy policy from inside the app. Stores expect this for apps that handle personal/sensitive data (phone, names, expenses).

**How:**
- Host a privacy policy page at a stable URL (e.g. your website or GitHub Pages).
- In **Profile** (or a new “About / Legal” section): add a row like “Privacy policy” that opens that URL in the device browser or an in-app WebView.

**Where:** `lib/screens/profile.dart` — add a list tile or button; use the `url_launcher` package (add to `pubspec.yaml` if needed) and your policy URL.

**Impact:** Store readiness +4–5 → **App ~83**. Often required for store approval.

---

## 2. Full accessibility pass (UI)

**What:** Make every important action and piece of information usable with a screen reader and clear focus order.

**How:**
- Wrap every **interactive** widget (buttons, links, list tiles, icon buttons) in `Semantics` with a short `label` (and `button: true` or `link: true` where it makes sense).
- Give **amounts and status** a label (e.g. “You owe 500 rupees”, “Cycle total 2,000 rupees”) so they are announced.
- Ensure **form fields** have `semanticsLabel` or an associated `Semantics` (description, hint, error).
- Check **contrast**: prefer theme colors; for any custom colors, aim for ~4.5:1 (normal text) / 3:1 (large text) where possible.

**Where:** All screens in `lib/screens/` and key widgets in `lib/widgets/` (e.g. `UpiPaymentCard`, list items in group detail, expense rows).

**Impact:** Accessibility +4–5 → **UI ~86–87**.

---

## 3. Design tokens everywhere (UI)

**What:** Stop using hardcoded font sizes, weights, and colors; route everything through your design system.

**How:**
- Replace patterns like `TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: ...)` with `context.bodyPrimary`, `context.subheader`, etc. from `lib/design/typography.dart`.
- Replace ad-hoc `Color(0x...)` or repeated `theme.colorScheme.onSurface` with `context.colorTextPrimary`, `context.colorCardBorder`, etc. from `lib/design/colors.dart`.

**Where:** Screens that still use inline styles (e.g. `PaymentResult`, `CycleSettled`, `MemberChange`, `CycleHistory`, parts of `SettlementConfirmation`, `GroupDetail`).

**Impact:** Visual design & consistency +3–4 → **UI ~89–90**.

---

## 4. Offline handling and robustness (App)

**What:** Make “no network” explicit and safe: block or warn on writes and give a clear way to retry or go back.

**How:**
- Before **any Firestore write** (add expense, delete group, settlement confirm, etc.): if `ConnectivityService.instance.isOffline`, show a SnackBar or dialog (“You’re offline. Try again when connected.”) and do **not** perform the write.
- Keep the existing **offline banner**; optionally add a “Retry” that rechecks connectivity and restarts listeners.
- Optionally: enable Firestore **offline persistence** so reads can use cache when offline (then you only block or warn on write).

**Where:** `CycleRepository` call sites (e.g. `addExpense`, `deleteGroup`, `markPaymentConfirmedByPayer`) and/or a single guard before repo writes; `ConnectivityService` is already used in places.

**Impact:** Robustness +2–3, Performance & stability +1–2 → **App ~82–84**.

---

## 5. More tests (App)

**What:** Cover the paths that affect money and store readiness.

**How:**
- **Critical path:** Add integration or E2E tests (e.g. `integration_test`) for: sign-in → create group → add expense → open settlement. Even one happy path helps.
- **Unit:** Add tests for “payer/participant not in member list” and “very large amounts” (G9 in V4_TESTING_ISSUES) in `test/settlement_engine_test.dart`.
- **Optional:** Test that error states and “Try Again” call `restartListening()` or the right repo method.

**Where:** `test/` (new or extend `settlement_engine_test.dart`); `integration_test/` if you add E2E.

**Impact:** Testing +2–3 → **App ~85**.

---

## 6. Pagination (App, when data grows)

**What:** Load groups, expenses, or cycle history in pages instead of all at once.

**How:**
- Use Firestore’s `limit()` and `startAfterDocument()` (or `startAfter` with a value) for `groupsStream`, `expensesStream`, and `getHistory`.
- In the UI: “Load more” at the bottom of lists, or infinite scroll that fetches the next page when the user nears the end.

**Where:** `FirestoreService` (queries), `CycleRepository` (how you merge pages into state), and list screens (`GroupsList`, `GroupDetail` expense list, `CycleHistory`).

**Impact:** Performance & stability +2–3 → **App ~87–88**. Do this when lists get large.

---

## 7. Optional: Language / locale setting (UI)

**What:** Let the user choose language or region so currency and number format match their preference.

**How:**
- Add a setting (e.g. in Profile) that stores a locale code (e.g. `en_IN`, `de_DE`) in SharedPreferences or your settings service.
- Pass that locale into `formatMoneyWithCurrency(..., locale: savedLocale)` and into any `NumberFormat` or date formatting.

**Where:** `lib/utils/money_format.dart` (already has optional locale); new “Settings” or Profile section; persist choice in `ThemeService` or a small `LocaleService`.

**Impact:** Locale & inclusivity +2–3 → **UI ~89–90**.

---

## Suggested order to reach 90+

| Priority | Action | Main effect |
|----------|--------|-------------|
| 1 | Privacy policy in-app | App +5, store requirement |
| 2 | Full a11y pass | UI +5 |
| 3 | Design tokens everywhere | UI +4 |
| 4 | Offline guards on writes | App +3 |
| 5 | More tests (G9 + one E2E) | App +3 |
| 6 | Pagination (when needed) | App +2–3 |
| 7 | Locale setting (optional) | UI +2–3 |

**Doing 1 + 2 + 3** gets you to about **App 83, UI 90**.  
Adding **4 + 5** brings **App** into the high 80s; **6** when you have scale; **7** if you want to max out UI.

**Current status:** App 96, UI 97 achieved. Implemented: (1) Privacy in-app, (2) Full a11y on key screens, (3) Design tokens on PaymentResult, CycleSettled, MemberChange, CycleHistory, CreateGroup, InviteMembers, (4) Offline guards on all writes, (5) G9 unit tests + parser outcome tests + balance-after-settlements contract, (6) STORE_CHECKLIST.md, (7) README known limitations, (8) Number-format (locale) picker in Profile, (9) Widget tests (EmptyStates, ExpensoLoader), (10) Integration test (app launch). Path to 100: pagination, design tokens on every remaining screen. **For 100+ and “110% success” (best expense tracker):** see [PATH_TO_100_PLUS.md](PATH_TO_100_PLUS.md).
