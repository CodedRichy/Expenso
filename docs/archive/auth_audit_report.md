# Authentication Flow Audit Report

This report traces the authentication lifecycle of Expenso from launch to logout, identifying redirects, state inconsistencies, and edge cases.

## Step-by-Step Flow

### 1. App Launch & Session Restore
- **Process**: `main.dart` initializes Supabase -> `RootScreen` renders.
- **Restoration**: `CycleRepository` loads the last-known profile from local cache (`SharedPreferences`) for instant UI. `RootScreen` then confirms the Supabase session via `StreamBuilder(initialData: currentUser)`.
- **Sync**: If a session exists, `repo.setAuthUserSync` and `repo.continueAuth()` are triggered to sync the local repository with the remote `users` table.

### 2. Login (Google / Email / Phone)
- **Process**: `RootScreen` redirects to `AuthScreen` if no session is found.
- **Google**: Native SDK authentication followed by `signInWithIdToken`. 
- **Email**: `signInWithPassword` or `signUp`. Sign-up triggers a verification email.
- **Phone**: OTP-based authentication (legacy logic).

### 3. Onboarding
- **Trigger**: `RootScreen` checks `repo.currentUserName.isEmpty`.
- **Action**: Redirects to `OnboardingNameScreen`. completions writes to both Supabase Auth Metadata and the `users` table.

### 4. Logout
- **Process**: `AuthService.signOut()` clears the Supabase session. `RootScreen` detects the change and calls `repo.clearAuth()` to purge local cache and memory.

---

## Identified Issues & Severity

### 1. Blocking: Missing Redirect for Email Auth
- **Issue**: `AuthService` uses `expenso://login-callback` for sign-up and password reset. However, `main.dart`'s `_handleLink` only handles `invite/` paths.
- **Impact**: Users cannot verify their email or reset passwords via the link; the app opens but remains on the login screen without completing the action.
- **Severity**: **Blocking**

### 2. Non-blocking: Redundant State & Writes
- **Issue**: Both `AuthRepository` and `CycleRepository` maintain identical user state. When `RootScreen` build fires, `repo.continueAuth()` is triggered repeatedly in a `PostFrameCallback`, leading to redundant `.upsert()` calls to the `users` table.
- **Impact**: Minor performance drift and unnecessary API calls.
- **Severity**: **Non-blocking**

### 3. Non-blocking: Identity Logic Disconnect
- **Issue**: `RootScreen` skips onboarding if metadata `display_name` is present. However, RLS policies likely depend on a record existing in the `users` table. If the database write fails but metadata succeeds, the user enters the app but may find all group data "missing" due to RLS failures.
- **Impact**: "Empty app" syndrome for new users if the initial DB write fails.
- **Severity**: **Non-blocking**

---

## Session Persistence & Edge Cases

### Session Persistence
- **Performance**: High. Local cache ensures the user's name is visible before the Supabase session is even checked.
- **Security**: Good. Local cache is cleared immediately on sign-out detection.

### Edge Case Analysis
- **First Login (Google)**: Metadata `full_name` is used as a fallback. If missing, onboarding is triggered.
- **First Login (Email)**: `signUp` requires name upfront; metadata contains it. Onboarding is usually skipped.
- **No Profile in DB**: If an Auth user exists but no `users` record exists (migration error), `continueAuth` attempts to create one. If this fails, the user is effectively "locked out" of their data by RLS but remains "logged in" to the app shell.
