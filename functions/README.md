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

### 2. Set your Razorpay keys (after first deploy)

The function reads `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` from **environment variables**. Set them in **Google Cloud Console**:

1. Open [Google Cloud Console](https://console.cloud.google.com) and select project **expenso-e138a**.
2. Go to **Cloud Functions** → select **createRazorpayOrder**.
3. Click the function → **Edit** (or **Edit new revision**) → **Variables & Secrets** (or **Environment variables**).
4. Add:
   - `RAZORPAY_KEY_ID` = your Razorpay Key ID (e.g. `rzp_test_...`)
   - `RAZORPAY_KEY_SECRET` = your Razorpay Key Secret

Save / deploy the revision. Keys are from [Razorpay Dashboard → API Keys](https://dashboard.razorpay.com/app/keys).

### 3. Deploy

From the **project root**:

```bash
firebase deploy --only functions
```

If you haven’t already, run `firebase use <your-project-id>` so the correct Firebase project is selected.
