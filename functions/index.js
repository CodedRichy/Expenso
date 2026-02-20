const { onCall, HttpsError } = require('firebase-functions/v2/https');
const Razorpay = require('razorpay');
const { getUserEncryptionKey, getGroupEncryptionKey } = require('./encryption');

const createRazorpayOrder = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keyId || !keySecret) {
      throw new HttpsError('failed-precondition', 'Razorpay not configured.');
    }
    const { amountPaise, receipt } = request.data || {};
    const amount = amountPaise != null ? Number(amountPaise) : NaN;
    if (!Number.isInteger(amount) || amount < 100) {
      throw new HttpsError('invalid-argument', 'amountPaise must be an integer >= 100.');
    }
    const MAX_PAISE = 10_00_000;
    if (amount > MAX_PAISE) {
      throw new HttpsError('invalid-argument', 'amountPaise exceeds maximum allowed.');
    }
    const razorpay = new Razorpay({ key_id: keyId, key_secret: keySecret });
    const order = await razorpay.orders.create({
      amount,
      currency: 'INR',
      receipt: receipt || `expenso_${request.auth.uid}_${Date.now()}`,
    });
    return { orderId: order.id, keyId };
  }
);

module.exports = {
  createRazorpayOrder,
  getUserEncryptionKey,
  getGroupEncryptionKey,
};
