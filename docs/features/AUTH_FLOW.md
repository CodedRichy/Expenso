# Auth flow: phone vs Google

App identity (name, photo, phone, UPI) always comes from **our app** (onboarding, Profile, Firestore). We never trust provider display names for in-app use; we only use provider data as a fallback when the user hasn’t set something yet.

## Principle: app details matter more

- **Name:** From onboarding (“What should we call you?”). For Google sign-in we do **not** use the Google display name; we always show onboarding so the user sets the name we use everywhere.
- **Photo:** If the user already set a profile photo (in Profile or from a previous session), we keep it. We only use Google’s photo when they have not set one.
- **Phone:** From phone auth (E.164) or left empty for Google-only users. Used for invites and matching.
- **Firestore** is the source of truth for profile (name, photo, UPI, currency); we write there and load from there so app details win after the first sync.

---

## Flow: person uses **phone**

1. **Login screen** → Enter phone number → **Continue**.
2. **OTP** → Receive SMS (or use test number + fixed code) → Enter 6-digit code → **Verify**.
3. **Onboarding** (if first time: no name yet) → “What should we call you?” → Enter name → **Get Started**.
4. **App** → Identity is: `uid` (Firebase), `phone` (from sign-in), `name` (from onboarding). Photo is empty until they set one in **Profile**.
5. **Returning user** → Same phone + OTP; if we already have name (from cache/Firestore) we skip onboarding and go to **Groups**.

---

## Flow: person uses **Google**

1. **Login screen** → **Sign in with Google** (or use phone flow instead).
2. **Google** → Account picker → user selects account.
3. **Onboarding** (always for Google) → We do **not** use Google’s display name. “What should we call you?” → User enters the name we use in groups and expense logs → **Get Started**.
4. **App** → Identity is: `uid` (Firebase), `phone` (empty unless they add later), `name` (from onboarding). Photo: if they had a saved profile photo we use that; otherwise we use Google’s photo until they change it in **Profile**.
5. **Returning user** → Sign in with Google again; we load profile from Firestore/cache (our name, our photo if set). Onboarding is skipped because we already have a name.

---

## Where it’s implemented

| Concern | Where |
|--------|--------|
| Don’t use Google name | `main.dart`: `isGoogle ? null : user.displayName` so onboarding always runs for Google. |
| Prefer saved photo over Google | `cycle_repository.dart`: `setAuthFromFirebaseUserSync` uses cached/our photo first, then falls back to provider `photoURL`. |
| Name/photo source of truth | Firestore `users/{uid}`; written by `_writeCurrentUserProfile`, loaded by `_loadCurrentUserProfileFromFirestore`. |
| Onboarding name screen | Shown when `repo.currentUserName.isEmpty`; after “Get Started”, `setGlobalProfile` + `updateDisplayName` set app name. |
