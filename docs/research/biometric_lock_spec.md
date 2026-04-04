# Biometric lock (app lock)

**Tier:** Free forever. Privacy/security baseline — never paywalled.  
**Status:** Not implemented.

---

## Do we need it?

**Yes.** Any app that shows who owes whom and payment/UPI details is in the same security bucket as banking and expense apps. Users expect a way to lock the app so someone who grabs their phone can't open it and see balances or settlement info. Treat it as a **trust baseline**, not a premium feature.

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

---

## Behaviour to match

1. **User setting:** "Lock app with biometrics" (or "App lock") in Profile or Settings. Store preference locally (e.g. `SharedPreferences`). 
2. **When to lock:** 
   - **On app resume:** After timeout (30–120s).
   - **On cold start:** Require auth before GroupsList.
3. **Lock screen:** Full-screen overlay gate.

---

## Research: what we need (full checklist)

### 1. Dependencies
Add `local_auth: ^3.0.0`.

### 2. Android
- **MainActivity**: Extend `FlutterFragmentActivity`.
- **AndroidManifest**: Add `USE_BIOMETRIC` permission.
- **Styles**: Use `Theme.AppCompat` for biometric dialog reliability.

### 3. iOS
- **Info.plist**: Add `NSFaceIDUsageDescription`.

### 4. Dart / app code
- **AppLockService**: SharedPreferences + ChangeNotifier for state.
- **Lifecycle Observer**: Detect pause/resume for auto-lock.
- **Custom UI**: Secure lock screen widget.

---

*Ref: docs/features/BIOMETRIC_LOCK.md (Original)*
