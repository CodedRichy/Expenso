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

## How we ask preference

**Where:** Profile screen. Add a **Security** section — same visual pattern as the existing "Payment Settings" card (section title + list of items). Place it between Payment Settings and Privacy policy. Alternatively, use a dedicated **Security** screen (Profile → Security) with multiple settings; both patterns are used by banking and finance apps (e.g. RBS/HSBC: Profile → Security; Monzo: Privacy & Security with App Lock).

**Industry pattern:** Use **list tiles** (one tile per setting), not a single crowded row. Each setting is its own tappable or toggleable item with clear label and optional subtitle.

**What to show:**

1. **Section title:** "Security" with a lock or shield icon.

2. **App lock** — One **list tile**:  
   - Leading: lock or fingerprint icon  
   - Title: "App lock"  
   - Subtitle (optional): "Unlock with fingerprint or Face ID"  
   - Trailing: **Switch**  
   Tapping the tile or the switch toggles the preference. When turning ON, validate biometrics first (see below).

3. **Lock after** (only when App lock is ON) — A **second list tile**:  
   - Title: "Lock after"  
   - Trailing: current value ("Immediately", "30 seconds", "1 minute", "2 minutes") + chevron  
   Tapping opens a bottom sheet, dialog, or navigates to a small picker screen to choose when the app locks (e.g. when app goes to background vs after 30 s / 1 min / 2 min). Persist the chosen value (0, 30, 60, 120 seconds).

**When user turns App lock ON:**
- Call `getAvailableBiometrics()`. If the list is empty, **don’t** turn the switch on; show a dialog: *"No fingerprint or face enrolled. Add one in your device Settings to use app lock."* with a single "OK" button.
- If biometrics are available, optionally run `authenticate(localizedReason: 'Confirm fingerprint or face to enable app lock')` once. If the user cancels or it fails, leave the switch off. If it succeeds, persist the preference and set the switch on.

**When user turns App lock OFF:** No auth needed. Persist `enabled = false` and update the switch.

**Persistence:** Same pattern as `ThemeService`: a small **AppLockService** (singleton, `ChangeNotifier`) that reads/writes `SharedPreferences` (`app_lock_enabled`, `app_lock_after_seconds`). Expose `enabled`, `lockAfterSeconds`, `setEnabled(bool)`, `setLockAfterSeconds(int)`. Load in `main()` or on first access so the lock screen and Profile share the same state.

**Capability on load:** When building the Security section, call `getAvailableBiometrics()`. If empty, show the App lock tile disabled with subtitle *"Not available — add fingerprint or face in device Settings."* or hide the tile.

**Summary:** Security section with **list tiles** (one for App lock + Switch, one for Lock after when enabled). Validate biometrics before enabling; persist via SharedPreferences; optional second tile for "Lock after" with a picker.

---

## Summary

| Question | Answer |
|----------|--------|
| **Do we need it?** | Yes — same security expectations as other money/expense apps; free tier. |
| **How do apps do it?** | `local_auth` (Flutter), lock on resume and/or cold start, optional timeout. |
| **Where to gate?** | After splash / on resume; full-screen overlay until authenticated. |
| **Paywall?** | No. Biometric lock is free forever (see MONETIZATION_EXECUTION.md). |
