const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const { getUserEncryptionKey, getGroupEncryptionKey } = require('./encryption');

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

function formatDate(date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const m = months[date.getMonth()];
  const d = String(date.getDate()).padStart(2, '0');
  const y = date.getFullYear();
  return `${m} ${d}, ${y}`;
}

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

      const netBalances = {};
      expensesSnap.docs.forEach(doc => {
        const exp = doc.data();
        if (exp.amount <= 0 || !exp.paidById || exp.paidById.startsWith('p_')) return;
        const splits = exp.splitAmountsByIdMinor || {};
        if (Object.keys(splits).length === 0) return;

        let sum = 0;
        for (const amt of Object.values(splits)) sum += amt;
        if (Math.abs(sum - (exp.amountMinor || 0)) > 1) return;

        netBalances[exp.paidById] = (netBalances[exp.paidById] || 0) + exp.amountMinor;
        for (const [memberId, amt] of Object.entries(splits)) {
          if (memberId.startsWith('p_')) continue;
          netBalances[memberId] = (netBalances[memberId] || 0) - amt;
        }
      });

      let totalPending = 0;

      // Load all payment attempts for cycle
      const attemptsQuery = db.collection('groups').doc(groupId).collection('payment_attempts').where('cycleId', '==', cycleId);
      const attemptsSnap = await transaction.get(attemptsQuery);

      const attempts = [];
      attemptsSnap.forEach(doc => attempts.push({ id: doc.id, ...doc.data() }));

      attempts.forEach(attempt => {
        const isSettled = attempt.confirmedByReceiver === true || attempt.status === 'confirmed_by_receiver' || attempt.status === 'cash_confirmed';
        const isDisputed = attempt.disputed === true || attempt.status === 'disputed';

        if (!isSettled || isDisputed) {
          totalPending++;
        } else {
          // Apply payment: fromMemberId paid, toMemberId received.
          const fromId = attempt.fromMemberId;
          const toId = attempt.toMemberId;
          const amt = attempt.amountMinor || 0;
          netBalances[fromId] = (netBalances[fromId] || 0) + amt; // Payer balance increases
          netBalances[toId] = (netBalances[toId] || 0) - amt;    // Receiver balance decreases
        }
      });

      if (totalPending > 0) {
        throw new HttpsError('failed-precondition', 'There are unpaid or disputed payment attempts.');
      }

      // Verify all net balances are exactly 0
      for (const [memberId, balance] of Object.entries(netBalances)) {
        if (balance !== 0) {
          throw new HttpsError('failed-precondition', `Settlement math mismatch. Member ${memberId} has unsettled balance of ${balance}.`);
        }
      }

      const now = new Date();
      const endStr = formatDate(now);
      let startStr = endStr;
      if (cycleId.startsWith('c_')) {
        const parsed = parseInt(cycleId.substring(2));
        if (!isNaN(parsed)) startStr = formatDate(new Date(parsed));
      }

      const newCycleId = `c_${now.getTime()}`;

      const settledCycleRef = db.collection('groups').doc(groupId).collection('settled_cycles').doc(cycleId);
      transaction.set(settledCycleRef, {
        startDate: startStr,
        endDate: endStr
      });

      // Archive expenses
      expensesSnap.docs.forEach(doc => {
        const expData = doc.data();
        const settledExpRef = settledCycleRef.collection('expenses').doc(doc.id);
        transaction.set(settledExpRef, expData);
        transaction.delete(doc.ref);
      });

      // Clear payment attempts
      attemptsSnap.docs.forEach(doc => {
        transaction.delete(doc.ref);
      });

      // Rotate cycleId and set cycleStatus back to 'active'
      transaction.update(groupRef, {
        activeCycleId: newCycleId,
        cycleStatus: 'active'
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
