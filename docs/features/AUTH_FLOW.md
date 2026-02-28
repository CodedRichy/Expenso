# Auth flow (phone only)

Identity (name, photo, phone, UPI) comes from **our app**: onboarding, Profile, and Firestore. Phone auth only supplies UID and phone number; we never use a third-party display name or photo unless the user has not set one.

## Principle: app details matter more

- **Name:** From onboarding (“What should we call you?”). We use Firebase `displayName` only when it was set by our app (e.g. after onboarding or Profile update).
- **Photo:** From Profile (upload) or cached/Firestore. We prefer cached profile photo over any provider URL.
- **Phone:** From phone auth (E.164). Used for invites and matching.
- **Firestore** `users/{uid}` is the source of truth for profile; we write there and load from there.

---

## Flow: sign in with phone

1. **Login** → Enter phone number → **Continue**.
2. **OTP** → SMS (or test number + fixed code) → Enter 6-digit code → **Verify**.
3. **Onboarding** (if first time: no name) → “What should we call you?” → Enter name → **Get Started**.
4. **App** → Identity: `uid`, `phone` (from sign-in), `name` (onboarding). Photo empty until set in **Profile**.
5. **Returning user** → Same phone + OTP; if we already have name (cache/Firestore) we skip onboarding → **Groups**.

---

## Where it’s implemented

| Concern | Where |
|--------|--------|
| Name after auth | `main.dart`: `setAuthFromFirebaseUserSync(..., user.displayName)` (set by our onboarding/Profile). |
| Prefer saved photo | `cycle_repository.dart`: `setAuthFromFirebaseUserSync` uses cached/our photo first, then `photoURL` from Firebase if any. |
| Source of truth | Firestore `users/{uid}`; `_writeCurrentUserProfile`, `_loadCurrentUserProfileFromFirestore`. |
| Onboarding | Shown when `repo.currentUserName.isEmpty`; after “Get Started”, `setGlobalProfile` + `updateDisplayName`. |
