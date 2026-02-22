# Data encryption — step-by-step setup

## 1. Set the master key in Firebase

You need to give your Cloud Functions the secret key so they can derive user/group keys. **Do not put this key in code or commit it.**

### Option A: Google Cloud Console (for production)

Firebase Functions (v2) run as Google Cloud Functions. Set the key in the same project:

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. **Select the same project** as your Firebase app (top bar: click the project name → pick your Expenso project).
3. In the left menu go to **Cloud Run** (or search “Cloud Run” in the top search).
4. You’ll see one or more services (e.g. each callable can be a service). Click the **service name** that backs your functions (often something like `getuserencryptionkey` or a shared service name).
5. At the top click **Edit & deploy new revision**.
6. Open the **Variables & secrets** tab.
7. Under **Environment variables** click **Add variable**:
   - **Name:** `DATA_ENCRYPTION_MASTER_KEY`
   - **Value:** `9f3c7a1d8b4e2f0c6a5d91e7b2c8f403a6e94d5b0f1c2873e9a4b6d2c5f8e01`
8. Click **Deploy** (bottom of the page). Wait for the new revision to be live.

**If you don’t see Cloud Run:** Go to **Cloud Functions** (left menu) → click your function (e.g. `getUserEncryptionKey`) → **Edit** → **Runtime, build, connections and security** → **Runtime environment variables** → Add `DATA_ENCRYPTION_MASTER_KEY` and the value → **Next** → **Deploy**.

**Note:** You must add the same env var to **every** Cloud Run service / function that uses it (e.g. the one for `getUserEncryptionKey` and the one for `getGroupEncryptionKey`), or deploy once with the var so all functions in that service get it. With Firebase’s default deploy, all callables often share one service, so adding the variable once may be enough.

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
