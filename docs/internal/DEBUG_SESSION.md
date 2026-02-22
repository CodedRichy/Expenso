# Debug session log

Record of bugs identified from terminal/runtime and fixes applied. **Done before** = already identified in a prior pass; **New** = first time in this session.

---

## 1. setState() / markNeedsBuild() during build — **Done before** (terminal analysis) → **Fixed**

**Evidence (from terminal):**
```
setState() or markNeedsBuild() called during build.
ListenableBuilder ... StreamBuilder<User?>
CycleRepository.setAuthFromFirebaseUser (cycle_repository.dart:65/70)
MyApp.build.<anonymous closure> (main.dart:100:18)
StreamBuilder.build
```

**Cause:** `StreamBuilder.build` in `main.dart` called `CycleRepository.setAuthFromFirebaseUser()`, which called `notifyListeners()` synchronously. That triggered `ListenableBuilder` to mark dirty while the framework was still building.

**Fix (code):**
- **cycle_repository.dart:** Split into `setAuthFromFirebaseUserSync(uid, phone, displayName)` (in-memory only, no `notifyListeners`) and `continueAuthFromFirebaseUser()` (Firestore write, load profile, start listeners, then `notifyListeners`).
- **main.dart:** When `user != null`, call `setAuthFromFirebaseUserSync(...)` during build, then `WidgetsBinding.instance.addPostFrameCallback((_) => repo.continueAuthFromFirebaseUser())` so notification happens after the frame.
- **main.dart (follow-up):** When `user == null`, `clearAuth()` was also called during build and calls `notifyListeners()`. Deferred: `WidgetsBinding.instance.addPostFrameCallback((_) => repo.clearAuth())` so no notification during build.

**Status:** Fixed in code. Instrumentation removed after verification.

---

## 2. Firestore permission-denied — **Done before** (terminal analysis) → **Config (no code fix)**

**Evidence (from terminal):**
- `users/605oNyF1miUumLGMgEnaGGD0Lyh2` read/write: PERMISSION_DENIED
- `groups/...` and `groups/.../expenses` listen: PERMISSION_DENIED
- `CycleRepository._loadCurrentUserProfileFromFirestore` and `_writeCurrentUserProfile` failed

**Cause:** Firestore Security Rules (or auth context) blocking these operations.

**Fix:** Use the repo’s `firestore.rules` and deploy it.
- **Option A (Firebase Console):** Open [Firebase Console](https://console.firebase.google.com) → your project → Firestore → Rules. Replace the rules with the contents of `firestore.rules`, then **Publish**.
- **Option B (CLI):** If you use Firebase CLI, run `firebase deploy --only firestore` from the project root (ensure `firebase.json` has `"firestore": { "rules": "firestore.rules" }`).

Rules in the file: users (own doc); groups (members only); `groups/{id}/expenses` and settled_cycles (group members only).

**Status:** `firestore.rules` added; deploy via Console or CLI.

**Follow-up (stream errors):** When rules still deny, Firestore snapshot streams throw `permission-denied` and crashed the app (unhandled exception). **Fix:** `cycle_repository.dart` — added `onError` to `groupsStream` and `expensesStream` subscriptions so errors are logged and (for groups) loading state is cleared; no more unhandled exceptions.

---

## 3. RenderFlex overflow on group detail (keyboard open) — **New** → **Fixed**

**Evidence:** `A RenderFlex overflowed by 6.0 pixels on the bottom` at `group_detail.dart:280` (Column for EXPENSE LOG). Occurs when keyboard is open and remaining height is small.

**Fix:** Replaced the `Column` (header + `Expanded`/`ListView.builder`) with a `CustomScrollView` using `SliverPadding`, `SliverToBoxAdapter` for the "EXPENSE LOG" header, and `SliverList` for the expense items. Content scrolls when space is tight instead of overflowing.

**Status:** Fixed in code.

---

## 4. Firebase Storage object-not-found (404) on avatar upload — **Done before** (terminal analysis) → **Config / path**

**Evidence (from terminal):**
- `ProfileService.uploadAvatar failed: [firebase_storage/object-not-found] No object exists at the desired reference.`
- StorageException 404 on upload/getDownloadURL path

**Cause:** Either Storage security rules deny write/read at `users/{userId}/avatar.jpg`, or the bucket/path configuration is wrong. Code path is `users/$uid/avatar.jpg` (correct).

**Fix:**
- In Firebase Console → Storage → Rules: allow authenticated users to write and read under `users/{userId}/**` (e.g. `match /users/{userId}/{allPaths=**} { allow read, write: if request.auth != null && request.auth.uid == userId; }`).
- Ensure the default bucket is the one the app uses.

**Code change:** Added `dart:typed_data` import in `profile_service.dart` for `Uint8List` (used by `uploadAvatarBytes`). No change to upload path or flow.

**Status:** Documented. Storage rules must be updated in Console; code path is already correct.

---

## 5. Other terminal messages (not app bugs) — **Done before**

- **Nothing phone:** `Invalid resource ID 0x0`, `NothingExperience.getAppName` — device/vendor SDK.
- **GoogleApiManager / FlagRegistrar:** `DEVELOPER_ERROR`, "Unknown calling package name" — often debug build / SHA-1 / package name in Firebase/Play.
- **App Check:** "No AppCheckProvider installed" — warning unless App Check is required.
- **ManagedChannelImpl / GraphicBufferAllocator:** Network/GPU when app backgrounded or on device — environment, not app logic.

**Status:** No fix applied; informational only.

---

## Summary

| # | Issue | Done before? | Fix type | Status |
|---|--------|--------------|----------|--------|
| 1 | setState during build | Yes | Code (defer notify) | Fixed |
| 2 | Firestore permission-denied | Yes | Config (rules) | Documented |
| 3 | Storage object-not-found | Yes | Config (rules) + import | Documented + import added |
| 4 | Device/Google/App Check noise | Yes | None | Noted |
