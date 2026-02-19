# Expenso Cloud Functions

## createRazorpayOrder (callable)

Creates a Razorpay order for in-app settlement. Called from the Flutter app with `amountPaise` (≥ 100) and optional `receipt`. Returns `orderId` and `keyId` for Razorpay Checkout.

### Setup

1. Install dependencies: `npm install`
2. Set Razorpay keys (Firebase CLI):
   - `firebase functions:config:set razorpay.key_id="YOUR_KEY_ID" razorpay.key_secret="YOUR_KEY_SECRET"`
   - Or use environment in Firebase Console → Functions → createRazorpayOrder → Environment variables: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`
3. For local config (optional): in `index.js` you can read from `functions.config().razorpay?.key_id` if you set config; the code currently uses `process.env.RAZORPAY_KEY_ID` and `process.env.RAZORPAY_KEY_SECRET` (set in Firebase Console or `.env` for emulator).

### Deploy

From the project root (parent of `functions/`):

```bash
firebase deploy --only functions
```

Ensure `firebase.json` includes `"functions": "functions"` and the project is set in `.firebaserc`.
