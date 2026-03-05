const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const { getUserEncryptionKey, getGroupEncryptionKey } = require('./encryption');
const {
  formatDate,
  computeNetBalances,
  applySettledAttempts,
  validateZeroSum,
  validateRazorpayAmount,
} = require('./logic');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

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
    const validation = validateRazorpayAmount(amountPaise);
    if (!validation.ok) {
      throw new HttpsError('invalid-argument', validation.reason);
    }

    const amount = Number(amountPaise);
    const razorpay = new Razorpay({ key_id: keyId, key_secret: keySecret });
    const order = await razorpay.orders.create({
      amount,
      currency: 'INR',
      receipt: receipt || `expenso_${request.auth.uid}_${Date.now()}`,
    });
    return { orderId: order.id, keyId };
  }
);

const settleAndRestart = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const groupId = request.data.groupId;
    if (!groupId) {
      throw new HttpsError('invalid-argument', 'groupId is required.');
    }

    return await db.runTransaction(async (transaction) => {
      const groupRef = db.collection('groups').doc(groupId);
      const groupSnap = await transaction.get(groupRef);
      if (!groupSnap.exists) {
        throw new HttpsError('not-found', 'Group not found.');
      }

      const groupData = groupSnap.data();
      if (groupData.creatorId !== request.auth.uid) {
        throw new HttpsError('permission-denied', 'Only the group creator can settle.');
      }
      if (groupData.cycleStatus !== 'settling') {
        throw new HttpsError('failed-precondition', 'Group is not in settling status.');
      }

      const cycleId = groupData.activeCycleId;

      // Load all expenses for current cycle
      const expensesSnap = await transaction.get(
        db.collection('groups').doc(groupId).collection('expenses')
      );

      // Due to End-to-End Encryption, the Server cannot read expense amounts/splits.
      // Math validation is performed client-side securely prior to initiating settlement.

      // Load all payment attempts for cycle to clear them
      const attemptsQuery = db
        .collection('groups')
        .doc(groupId)
        .collection('payment_attempts')
        .where('cycleId', '==', cycleId);
      const attemptsSnap = await transaction.get(attemptsQuery);

      const now = new Date();
      const endStr = formatDate(now);
      let startStr = endStr;
      if (cycleId.startsWith('c_')) {
        const parsed = parseInt(cycleId.substring(2));
        if (!isNaN(parsed)) startStr = formatDate(new Date(parsed));
      }

      const newCycleId = `c_${now.getTime()}`;

      const settledCycleRef = db
        .collection('groups')
        .doc(groupId)
        .collection('settled_cycles')
        .doc(cycleId);
      transaction.set(settledCycleRef, { startDate: startStr, endDate: endStr });

      // Archive expenses
      expensesSnap.docs.forEach(doc => {
        const settledExpRef = settledCycleRef.collection('expenses').doc(doc.id);
        transaction.set(settledExpRef, doc.data());
        transaction.delete(doc.ref);
      });

      // Clear payment attempts
      attemptsSnap.docs.forEach(doc => {
        transaction.delete(doc.ref);
      });

      // Rotate cycle
      transaction.update(groupRef, {
        activeCycleId: newCycleId,
        cycleStatus: 'active',
      });

      return { success: true, newCycleId };
    });
  }
);

module.exports = {
  createRazorpayOrder,
  settleAndRestart,
  getUserEncryptionKey,
  getGroupEncryptionKey,
};
