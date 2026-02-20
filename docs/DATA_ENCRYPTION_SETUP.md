# Data encryption — step-by-step setup

## 1. Set the master key in Firebase

You need to give your Cloud Functions the secret key so they can derive user/group keys. **Do not put this key in code or commit it.**

### Option A: Firebase Console (for production)

1. Open [Firebase Console](https://console.firebase.google.com/) and select your Expenso project.
2. Go to **Build** → **Functions**.
3. Click the **Environment variables** or **Secrets** tab (depends on your Firebase version).
4. Add a new variable/secret:
   - **Name:** `DATA_ENCRYPTION_MASTER_KEY`
   - **Value:** `9f3c7a1d8b4e2f0c6a5d91e7b2c8f403a6e94d5b0f1c2873e9a4b6d2c5f8e01`
5. Save.  
   **Note:** If you use **Secrets**, create the secret first, then in Functions config reference it. Newer projects often use **Environment variables** in the Functions dashboard.

### Option B: Local only (emulator)

1. Open `functions/.env` (create it if it doesn’t exist).
2. Add this line (no quotes around the value):
   ```
   DATA_ENCRYPTION_MASTER_KEY=9f3c7a1d8b4e2f0c6a5d91e7b2c8f403a6e94d5b0f1c2873e9a4b6d2c5f8e01
   ```
3. Save. `functions/.env` is in `.gitignore` — do not commit it.

---

## 2. Deploy Cloud Functions

1. Open a terminal in the project root.
2. Install dependencies (if you haven’t):
   ```bash
   cd functions
   npm install
   cd ..
   ```
3. Deploy only Functions:
   ```bash
   firebase deploy --only functions
   ```
4. Wait until you see “Deploy complete.”  
   If you set the key in the **Console**, it’s already in the project. If you used **only** `functions/.env`, that file is for the **emulator**; production needs the key set in the Console (or via CI secrets).

---

## 3. Run the app and sign in

1. From the project root:
   ```bash
   flutter run
   ```
2. Sign in with phone auth (or your usual method).
3. The app will call `getUserEncryptionKey` and, when you open groups, `getGroupEncryptionKey`. New and updated data will be encrypted in Firestore.

---

## 4. Check that encryption is on (optional)

1. In Firebase Console go to **Build** → **Firestore Database**.
2. Open a group’s **expenses** (or a **users** doc) after adding/editing something from the app.
3. You should see fields like `description`, `amount`, `displayName` etc. as long strings starting with `e:` (base64 ciphertext). If they’re still plain text, the key wasn’t set or the function wasn’t deployed correctly.

---

## Summary

| Step | Action |
|------|--------|
| 1 | Set `DATA_ENCRYPTION_MASTER_KEY` in Firebase (Console env/secrets or `functions/.env` for emulator). |
| 2 | Run `firebase deploy --only functions`. |
| 3 | Run the app, sign in, use groups/expenses as usual. |
| 4 | (Optional) In Firestore, confirm sensitive fields are stored as `e:...` ciphertext. |

If key fetch fails (e.g. missing env), the app still works but writes **plain text**. Check Firebase Functions logs for errors.
