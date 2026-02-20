const { onCall, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');
const Razorpay = require('razorpay');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

function deriveKey(prefix, id) {
  const master = process.env.DATA_ENCRYPTION_MASTER_KEY;
  if (!master) return null;
  return crypto.createHmac('sha256', master, prefix + ':' + id).digest('base64');
}

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

const getUserEncryptionKey = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');
    const key = deriveKey('user', request.auth.uid);
    if (!key) throw new HttpsError('failed-precondition', 'Data encryption not configured.');
    return { key };
  }
);

const getGroupEncryptionKey = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');
    const groupId = request.data?.groupId;
    if (typeof groupId !== 'string' || !groupId.trim()) {
      throw new HttpsError('invalid-argument', 'groupId is required.');
    }
    const groupSnap = await admin.firestore().doc(`groups/${groupId.trim()}`).get();
    if (!groupSnap.exists) throw new HttpsError('not-found', 'Group not found.');
    const members = groupSnap.data()?.members ?? [];
    if (!members.includes(request.auth.uid)) {
      throw new HttpsError('permission-denied', 'Not a group member.');
    }
    const key = deriveKey('group', groupId.trim());
    if (!key) throw new HttpsError('failed-precondition', 'Data encryption not configured.');
    return { key };
  }
);

module.exports = {
  createRazorpayOrder,
  getUserEncryptionKey,
  getGroupEncryptionKey,
};
