const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineString } = require('firebase-functions/params');
const Razorpay = require('razorpay');

const razorpayKeyId = defineString('RAZORPAY_KEY_ID', { description: 'Razorpay API Key ID (test or live)' });
const razorpayKeySecret = defineString('RAZORPAY_KEY_SECRET', { description: 'Razorpay API Key Secret' });

const createRazorpayOrder = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const keyId = razorpayKeyId.value();
    const keySecret = razorpayKeySecret.value();
    if (!keyId || !keySecret) {
      throw new HttpsError('failed-precondition', 'Razorpay not configured.');
    }
    const { amountPaise, receipt } = request.data || {};
    const amount = amountPaise != null ? Number(amountPaise) : NaN;
    if (!Number.isInteger(amount) || amount < 100) {
      throw new HttpsError('invalid-argument', 'amountPaise must be an integer >= 100.');
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

module.exports = { createRazorpayOrder };
