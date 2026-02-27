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

## Summary

| Question | Answer |
|----------|--------|
| **Do we need it?** | Yes — same security expectations as other money/expense apps; free tier. |
| **How do apps do it?** | `local_auth` (Flutter), lock on resume and/or cold start, optional timeout. |
| **Where to gate?** | After splash / on resume; full-screen overlay until authenticated. |
| **Paywall?** | No. Biometric lock is free forever (see MONETIZATION_EXECUTION.md). |
