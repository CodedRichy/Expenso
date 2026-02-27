# Biometric lock (app lock)

**Tier:** Free forever. Privacy/security baseline — never paywalled.  
**Status:** Not implemented.

---

## Do we need it?

**Yes.** Any app that shows who owes whom and payment/UPI details is in the same security bucket as banking and expense apps. Users expect a way to lock the app so someone who grabs their phone can't open it and see balances or settlement info. Treat it as a **trust baseline**, not a premium feature.

**How others do it:**
- **Splitwise:** 4-digit passcode lock (local, activates after ~120s out of app). Users have asked for Face ID / fingerprint; not standard there yet.
- **Banking / wallet apps:** Almost all offer biometric or passcode lock, often with "lock when app goes to background" and "lock on launch".
- **Expenso:** We've committed to biometric lock as **free** so we don't gate a basic privacy expectation behind Plus.

---

## How to implement

### Stack

Use the official Flutter plugin **`local_auth`** (published by flutter.dev):

- **Android:** SDK 24+. Fingerprint, face, or device PIN/pattern as fallback.
- **iOS:** 13.0+. Face ID or Touch ID, with device passcode fallback.
- **API:** `LocalAuthentication` — check capabilities, then `authenticate(localizedReason: '…')` when you need to unlock.

Add to `pubspec.yaml`:

```yaml
dependencies:
  local_auth: ^3.0.0
```

**Android:** Declare `USE_BIOMETRIC` / `USE_FINGERPRINT` in `AndroidManifest.xml` (see [local_auth_android README](https://pub.dev/packages/local_auth_android)).  
**iOS:** Set `NSFaceIDUsageDescription` in `Info.plist` (e.g. "Unlock Expenso to view your groups and balances").

### Behaviour to match

1. **User setting:** "Lock app with biometrics" (or "App lock") in Profile or Settings. Store preference locally (e.g. `SharedPreferences`). If no biometrics enrolled, offer passcode-only or hide the option and show "Enable fingerprint/Face in system settings".
2. **When to lock:** Either or both:
   - **On app resume:** After app has been in background for N seconds (e.g. 30–120s), show lock screen on next open.
   - **On cold start:** Require auth before showing GroupsList (after splash).
3. **Lock screen:** Full-screen overlay that blocks access to app content until `auth.authenticate(localizedReason: 'Unlock Expenso')` succeeds. Optionally "Use passcode" if `biometricOnly: false` and device supports it.
4. **Capability check:** Call `canCheckBiometrics` and/or `getAvailableBiometrics()` on init or when opening settings. If empty, don't show "Biometric lock" or show "Not available on this device".
5. **Errors:** Handle `LocalAuthException` (e.g. `noBiometricHardware`, `biometricLockout`, `temporaryLockout`) — show a short message or fallback to passcode if allowed.

### Where it fits in the app

- **Profile (or Settings):** Toggle "App lock" → if on, set flag and optionally choose "Lock after X seconds in background".
- **App lifecycle:** On resume from background, if lock enabled and timeout elapsed, present lock overlay before any sensitive UI. After successful auth, clear overlay and continue.
- **Cold start:** After splash, if user is logged in and lock is on, show lock screen first; on success navigate to `/` (GroupsList).

No server round-trip: everything is local (preference + OS biometric/passcode). No need to sync "lock enabled" across devices unless you later add multi-device settings.

---

## How we ask preference (Settings screen)

**Which screen:** Expenso currently has no separate "Settings" screen; **Profile** is the settings surface (avatar, display name, Payment Settings, Privacy policy, Log out). Add the App lock preference there. Optionally, later, you could introduce a dedicated **Settings** screen (e.g. Profile → Settings) and move Security + theme there; for now, **Profile = settings**, so the Security section lives on the Profile screen.

**On the Settings (Profile) screen, add a Security section** — same card style as "Payment Settings" (gradient card, section title, then list of items). Place it **between** the Payment Settings card and the Privacy policy tile.

**Industry pattern:** Use **list tiles** (one tile per setting). Each setting is its own row with clear label and optional subtitle.

**What appears on the screen:**

1. **Section:** A card with header "Security" (lock or shield icon + title), then inside the card:

2. **App lock** — One **list tile**:  
   - Leading: lock or fingerprint icon  
   - Title: "App lock"  
   - Subtitle (optional): "Unlock with fingerprint or Face ID"  
   - Trailing: **Switch**  
   Tapping the tile or the switch toggles the preference. When turning ON, validate biometrics first (see below).

3. **Lock after** (only when App lock is ON) — A **second list tile** in the same Security card:  
   - Title: "Lock after"  
   - Trailing: current value ("Immediately", "30 seconds", "1 minute", "2 minutes") + chevron  
   Tapping opens a bottom sheet, dialog, or a small picker screen to choose when the app locks. Persist the value (0, 30, 60, 120 seconds).

**When user turns App lock ON:**  
- Call `getAvailableBiometrics()`. If the list is empty, **don’t** turn the switch on; show a dialog: *"No fingerprint or face enrolled. Add one in your device Settings to use app lock."*  
- If biometrics are available, optionally run `authenticate(localizedReason: 'Confirm fingerprint or face to enable app lock')` once. If the user cancels or it fails, leave the switch off. If it succeeds, persist and set the switch on.

**When user turns App lock OFF:** No auth needed. Persist `enabled = false` and update the switch.

**Persistence:** `AppLockService` (SharedPreferences: `app_lock_enabled`, `app_lock_after_seconds`). Load in `main()` so the lock screen and Settings (Profile) share the same state.

**Capability on load:** When building the Security section on the Settings (Profile) screen, call `getAvailableBiometrics()`. If empty, show the App lock tile disabled with subtitle *"Not available — add fingerprint or face in device Settings."* or hide the tile.

**Summary:** On the **Settings (Profile) screen**, add a Security card with two list tiles: App lock (Switch) and Lock after (picker when enabled). Validate biometrics before enabling; persist via SharedPreferences.

---

## Research: what we need (full checklist)

### 1. Dependencies

| Item | Detail |
|------|--------|
| **pubspec.yaml** | Add `local_auth: ^3.0.0` (or latest compatible). Android/iOS implementations are endorsed and pulled in automatically. |

### 2. Android

| Item | Detail | Current state |
|------|--------|----------------|
| **MainActivity** | `local_auth` requires **FlutterFragmentActivity** (not `FlutterActivity`) for the biometric dialog. | **Change needed:** `MainActivity.kt` currently extends `FlutterActivity` → change to `FlutterFragmentActivity` and update import to `io.flutter.embedding.android.FlutterFragmentActivity`. |
| **AndroidManifest.xml** | Add permission: `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`. | **Missing:** Not present today. |
| **LaunchTheme** | Parent must be a **Theme.AppCompat** theme (e.g. `Theme.AppCompat.DayNight`) to prevent crashes on Android 8 and below with the biometric dialog. | **Change needed:** `styles.xml` uses `Theme.Light.NoTitleBar` → switch to `Theme.AppCompat.DayNight` (or keep a custom windowBackground if needed). Same for `values-night/styles.xml` if it exists. |

### 3. iOS

| Item | Detail | Current state |
|------|--------|----------------|
| **Info.plist** | Add **NSFaceIDUsageDescription** (required for Face ID). Example: *"Unlock Expenso to view your groups and balances."* | **Missing:** Not present. |

### 4. Dart / app code

| Item | Detail |
|------|--------|
| **AppLockService** | New singleton `ChangeNotifier`. Keys: `app_lock_enabled` (bool), `app_lock_after_seconds` (int: 0 = immediate, 30, 60, 120). Load in `main()` alongside `ThemeService.instance.load()`. |
| **Lifecycle** | Use **WidgetsBindingObserver** (e.g. on the root widget or a dedicated wrapper). On `AppLifecycleState.paused` → record timestamp. On `AppLifecycleState.resumed` → if lock enabled and (now - timestamp) >= lockAfterSeconds, show lock overlay. Register in `initState`, unregister in `dispose`. |
| **Cold start** | After splash, before showing home: if user is logged in and `AppLockService.instance.enabled`, show lock screen; on success, proceed to `/`. |
| **Lock screen** | Full-screen route or overlay. Single action: call `LocalAuthentication().authenticate(localizedReason: 'Unlock Expenso')`. On success → pop overlay or navigate to app. On cancel/failure → stay on lock screen; optionally show message for lockout. |
| **Profile Security section** | New Security card with list tiles (App lock Switch, Lock after picker). Read `AppLockService`; before turning Switch on, call `getAvailableBiometrics()` and optionally `authenticate()`. |
| **Error handling** | Catch `LocalAuthException`. Handle: `noBiometricHardware`, `noBiometricsEnrolled`, `noCredentialsSet` (show "Add biometrics in device Settings"); `userCanceled` (no message); `temporaryLockout` / `biometricLockout` (show "Try again in a few minutes"); others → generic "Authentication failed". |

### 5. Edge cases

| Case | Handling |
|------|----------|
| No biometrics enrolled | Don’t enable; show dialog or disabled tile with "Add fingerprint or face in device Settings". |
| User enables lock then removes all biometrics | Next time we call `authenticate()` it will fail; show error and optionally auto-disable lock or offer "Use device PIN" if we allow fallback. |
| App killed while in background | On next cold start, show lock screen if enabled (no "lock after" delay on cold start — always lock). |
| Lock screen shown, user presses Back (Android) | Either consume Back and stay on lock, or treat as cancel and stay on lock. |
| Multiple rapid resume/pause | Use a single "last paused at" timestamp; on resume, compare with lockAfterSeconds. |
| Tablet / no biometric hardware | `getAvailableBiometrics()` empty or `canCheckBiometrics` false → show "Not available" and don’t offer the option (or offer passcode-only if we add it later). |

### 6. Files to add or touch

| File | Action |
|------|--------|
| `pubspec.yaml` | Add `local_auth`. |
| `android/.../MainActivity.kt` | Extend `FlutterFragmentActivity`. |
| `android/.../AndroidManifest.xml` | Add `USE_BIOMETRIC`. |
| `android/.../res/values/styles.xml` | LaunchTheme parent → `Theme.AppCompat.DayNight`. |
| `android/.../res/values-night/styles.xml` | Same if present. |
| `ios/Runner/Info.plist` | Add `NSFaceIDUsageDescription`. |
| `lib/services/app_lock_service.dart` | **New** — SharedPreferences + ChangeNotifier. |
| `lib/screens/app_lock_screen.dart` (or overlay) | **New** — full-screen auth gate. |
| `lib/main.dart` | Load `AppLockService.instance.load()`; after splash, gate on lock + auth before home. |
| Root widget or splash | Add `WidgetsBindingObserver` to record pause time and trigger lock on resume. |
| `lib/screens/profile.dart` | Add Security section (App lock + Lock after tiles) on the Settings (Profile) screen. |

---

## Summary

| Question | Answer |
|----------|--------|
| **Do we need it?** | Yes — same security expectations as other money/expense apps; free tier. |
| **How do apps do it?** | `local_auth` (Flutter), lock on resume and/or cold start, optional timeout. |
| **Where to gate?** | After splash / on resume; full-screen overlay until authenticated. |
| **Paywall?** | No. Biometric lock is free forever (see MONETIZATION_EXECUTION.md). |
