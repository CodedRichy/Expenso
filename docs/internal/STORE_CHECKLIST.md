# Store submission checklist — Expenso

Use this when submitting to Google Play or App Store.

## Privacy & data

- [x] **Privacy policy** — In-app link from Profile → Privacy policy opens `kPrivacyPolicyUrl` (set in `lib/screens/profile.dart`). Policy hosted at repo: [PRIVACY.md](../../PRIVACY.md). Replace URL with your own if needed.
- [x] **Data handling** — PRIVACY.md describes what data is collected (phone, name, expense data), how it is used, and Firebase/third-party usage.
- [x] **Permissions** — App requests only: phone (auth), contacts (optional, for invite), camera/storage (optional, for avatar). Declare in store listing and in-app only what you use.

## App integrity

- [x] **Auth** — Phone (OTP) sign-in via Firebase. No guest/anonymous write access.
- [x] **Security** — Firestore rules deployed; group delete restricted to creator. Optional encryption documented in docs/features/DATA_ENCRYPTION.md.
- [x] **Offline** — Offline banner shown; all Firestore writes guarded (no write when offline). Prevents failed writes and data inconsistency.

## Store listing

- **Short description** — e.g. "Group expense tracking — split bills, settle via UPI."
- **Full description** — Use README “How it works” and “Key features” as a base.
- **Screenshots** — Groups list, group detail with Decision Clarity card, settlement screen, Profile.
- **Category** — Finance or Productivity.
- **Content rating** — Complete questionnaire (no mature content; expense/money handling).
- **Target audience** — All ages or 13+ per your policy.

## Pre-submit

- [ ] Run `flutter test` — all tests pass (unit + widget: 187+).
- [ ] Run integration test (optional): `flutter test integration_test/app_test.dart -d windows` (or your target device).
- [ ] Run release build — `flutter build apk` or `flutter build appbundle` (Android), `flutter build ios` (iOS).
- [ ] Test on a real device — sign-in, create group, add expense, settlement flow.
- [ ] Confirm Firebase project has correct package name / bundle ID and `google-services.json` / `GoogleService-Info.plist` in the app.

## Post-submit

- Monitor Firebase Console for crashes and usage.
- Respond to store review feedback; keep PRIVACY.md and in-app policy URL up to date.
