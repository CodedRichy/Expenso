# Firebase Phone Auth (OTP) Setup

If the app does not send an OTP when you tap "Continue" on the phone screen, Firebase Phone Authentication is not fully configured. Use this checklist.

## 1. Enable sign-in methods in Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/) and select your project.
2. Go to **Build** → **Authentication** → **Sign-in method**.
3. **Phone (primary):** Click **Phone**, turn **Enable** on, then Save.
4. **Google (optional):** Click **Google**, turn **Enable** on, set a project support email, then Save. The app shows "Sign in with Google" on the phone auth screen; no extra config needed for Android beyond the same SHA-1/SHA-256 as for Phone.

## 2. Add your app’s SHA-1 and SHA-256 (Android)

Firebase uses these to validate your app. Without them, phone verification often fails and no SMS is sent.

1. In Firebase Console: **Project settings** (gear) → **Your apps**.
2. Select your **Android** app (package name e.g. `com.example.expenso`).
3. Under **SHA certificate fingerprints**, add:
   - **Debug:** either:
     - **Gradle:** run `./gradlew signingReport` from the `android` folder (on Windows PowerShell use `.\gradlew.bat signingReport`). Copy the **SHA-1** and **SHA-256** from the `debug` variant.
     - **If Gradle fails** with "IllegalArgumentException: 25" (Java 25 not supported by Kotlin DSL), either use **Java 17** (set `JAVA_HOME` to JDK 17 and re-run), or use **keytool** (no Gradle, works with any Java):
       - **Windows (PowerShell):**  
         `keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android`
       - **macOS/Linux:**  
         `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`  
       In the output, copy the **SHA1** and **SHA256** values into Firebase Console.
   - **Release:** use the keystore you use for release builds: run `signingReport` (with Java 17 if needed) or the same `keytool -list -v -keystore <path> -alias <alias>` with your release keystore, then add those SHA-1 and SHA-256.
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
| Phone / Google enabled | Firebase Console → Authentication → Sign-in method → Phone and/or Google = On |
| Android SHA-1/SHA-256 | Firebase Console → Project settings → Your apps → Android → Add fingerprint |
| App uses correct project | `android/app/google-services.json` has your project’s `project_id` |
| Firebase init in app | Debug log on launch: "Firebase initialized." |

After adding SHA fingerprints and updating `google-services.json`, do a **full rebuild** (e.g. `flutter clean && flutter run`).

## Troubleshooting: "Invalid app info in play_integrity_token"

If you still see *"This app is not authorized to use Firebase Authentication... [Invalid app info in play_integrity_token]"* after adding SHA-1/SHA-256 and replacing `google-services.json`:

1. **Enable Play Integrity API** (same Google Cloud project as Firebase):
   - Open [Google Cloud Console](https://console.cloud.google.com/) and select the project linked to Firebase (e.g. **expenso-e138a** — check Firebase Project settings → General → Your project). The project number in `google-services.json` must match (e.g. **211875033656**).
   - Go to **APIs & Services** → **Library**, search for **Play Integrity API**, open it and click **Enable**.
2. **Play Console / project mismatch:** If the log shows `cloudProjectNumber=551503664846` (or any number different from your Firebase project number **211875033656**), the integrity token is for a different project. In [Google Play Console](https://play.google.com/console/) → your app → **Release** → **App integrity** → **Play Integrity API**, ensure the linked Cloud project is the same as Firebase (expenso-e138a). If the app is not on Play Console yet, this can still happen on emulators; use a **real device** (see below).
3. **Clean install:** Uninstall the app from the device/emulator, then run `flutter clean` and `flutter run` so the build that runs is signed with the keystore whose SHAs you added.
4. **Real device:** If you are testing on an **emulator**, try a **physical device** with a SIM; Play Integrity can be stricter on emulators and often causes "Invalid app info in play_integrity_token" there.
5. **Test number:** Use Firebase's test phone numbers (Authentication → Sign-in method → Phone → Phone numbers for testing) to avoid SMS and confirm whether the error is about app verification or the SMS path.
