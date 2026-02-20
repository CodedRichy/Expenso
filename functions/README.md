# Expenso Cloud Functions

## createRazorpayOrder (callable)

Creates a Razorpay order for in-app settlement. Called from the Flutter app with `amountPaise` (≥ 100) and optional `receipt`. Returns `orderId` and `keyId` for Razorpay Checkout.

### 1. Install dependencies

From the **project root** (parent of `functions/`):

```bash
cd functions
npm install
cd ..
```

### 2. Set your Razorpay keys

**Option A – .env file (recommended)**  
In the `functions/` folder, create a file named `.env` (or `.env.<your-firebase-project-id>`). Add:

```
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
RAZORPAY_KEY_SECRET=your_secret_here
```

Use your **Test** Key ID and **Test** Key Secret from [Razorpay Dashboard → API Keys](https://dashboard.razorpay.com/app/keys). Do not commit this file (root `.gitignore` already ignores `.env` and `.env.*`).

**Option B – Prompt on deploy**  
If you don’t create a `.env` file, the Firebase CLI will prompt you for `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` the first time you deploy, and save them to a file under `functions/`.

### 3. Deploy

From the **project root**:

```bash
firebase deploy --only functions
```

If you haven’t already, run `firebase use <your-project-id>` so the correct Firebase project is selected.
