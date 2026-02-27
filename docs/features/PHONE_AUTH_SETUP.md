# Firebase Phone Auth (OTP) Setup

If the app does not send an OTP when you tap "Continue" on the phone screen, Firebase Phone Authentication is not fully configured. Use this checklist.

## 1. Enable Phone sign-in in Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/) and select your project.
2. Go to **Build** → **Authentication** → **Sign-in method**.
3. Click **Phone** and turn **Enable** on, then Save.

## 2. Add your app’s SHA-1 and SHA-256 (Android)

Firebase uses these to validate your app. Without them, phone verification often fails and no SMS is sent.

1. In Firebase Console: **Project settings** (gear) → **Your apps**.
2. Select your **Android** app (package name e.g. `com.example.expenso`).
3. Under **SHA certificate fingerprints**, add:
   - **Debug:** run in project root:
     ```bash
     cd android && ./gradlew signingReport
     ```
     Copy the **SHA-1** and **SHA-256** from the `debug` variant and add them in the Firebase Console.
   - **Release:** use the keystore you use for release builds and run the same `signingReport` (or use the key you configured), then add that SHA-1 and SHA-256.
4. Download the updated **google-services.json** and replace `android/app/google-services.json`, then rebuild.

## 3. Confirm Firebase is initialized in the app

- If you see "Firebase initialized." in the debug console on startup, the app is using your Firebase project.
- If you see "Firebase not configured", run:
  ```bash
  dart run flutterfire configure
  ```
  and ensure `lib/firebase_options.dart` and `android/app/google-services.json` are present.

## 4. (Optional) Test phone number

To test without sending real SMS:

1. In Firebase Console: **Authentication** → **Sign-in method** → **Phone** → **Phone numbers for testing**.
2. Add a number (e.g. +91 79022 03218) and a 6-digit code (e.g. 123456).
3. The app already shows a hint for the test number in `PhoneAuthService` (see `phone_auth_service.dart`).

## Quick checks

| Check | Where |
|-------|--------|
| Phone provider enabled | Firebase Console → Authentication → Sign-in method → Phone = On |
| Android SHA-1/SHA-256 | Firebase Console → Project settings → Your apps → Android → Add fingerprint |
| App uses correct project | `android/app/google-services.json` has your project’s `project_id` |
| Firebase init in app | Debug log on launch: "Firebase initialized." |

After adding SHA fingerprints and updating `google-services.json`, do a **full rebuild** (e.g. `flutter clean && flutter run`).
