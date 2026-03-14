const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const {
  getUserEncryptionKey,
  getGroupEncryptionKey,
  adminFetchUsers,
  adminFetchGroups,
  adminUpdateUser,
  adminBanUser,
  adminDeleteUser,
  adminDeleteGroup
} = require('./encryption');
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

    const result = await db.runTransaction(async (transaction) => {
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

      // Rotate cycle
      transaction.update(groupRef, {
        activeCycleId: newCycleId,
        cycleStatus: 'active',
      });

      return { 
        newCycleId, 
        startStr, 
        endStr, 
        cycleId, 
        expensesDocs: expensesSnap.docs.map(d => ({ id: d.id, ref: d.ref, data: d.data() })), 
        attemptsDocs: attemptsSnap.docs.map(d => ({ ref: d.ref })) 
      };
    });

    // Execute the bulky operations outside the 500-op transaction limit using bulkWriter
    const bulkWriter = db.bulkWriter();
    const settledCycleRef = db.collection('groups').doc(groupId).collection('settled_cycles').doc(result.cycleId);
    
    // Archive expenses
    result.expensesDocs.forEach(doc => {
      const settledExpRef = settledCycleRef.collection('expenses').doc(doc.id);
      bulkWriter.set(settledExpRef, doc.data);
      bulkWriter.delete(doc.ref);
    });

    // Clear payment attempts
    result.attemptsDocs.forEach(doc => {
      bulkWriter.delete(doc.ref);
    });

    await bulkWriter.close();

    return { success: true, newCycleId: result.newCycleId };
  }
);

// --- BACKGROUND JOBS ---
const dailyCleanupJob = onSchedule('every day 00:00', async (event) => {
  console.log('Running daily cleanup tasks...');
  const oneWeekAgo = new Date();
  oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
  
  // Cleanup old failed payment attempts
  const attemptsSnap = await db.collectionGroup('payment_attempts')
    .where('timestamp', '<', oneWeekAgo)
    .where('status', '==', 'failed')
    .get();
  
  const writer = db.bulkWriter();
  let count = 0;
  attemptsSnap.forEach(doc => {
    writer.delete(doc.ref);
    count++;
  });
  
  if (count > 0) {
    await writer.close();
    console.log(`Cleaned up ${count} old failed payment attempts.`);
  }
});

// --- REST API BACKEND SURFACE ---
const api = onRequest(
  { region: 'asia-south1' },
  async (req, res) => {
    // A simple public API extension for health/status
    if (req.method === 'GET' && req.path === '/health') {
      return res.status(200).json({ status: 'ok', api_version: '1.0' });
    }
    
    // Group lookup endpoint
    if (req.method === 'GET' && req.path.startsWith('/group/')) {
      const groupId = req.path.split('/')[2];
      const groupSnap = await db.collection('groups').doc(groupId).get();
      if (!groupSnap.exists) {
        return res.status(404).json({ error: 'Not found' });
      }
      return res.status(200).json({ id: groupId, name: groupSnap.data().name });
    }

    return res.status(404).json({ error: 'Not implemented' });
  }
);

// --- FCM NOTIFICATIONS ---
const notifyOnNewExpense = onDocumentCreated(
  'groups/{groupId}/expenses/{expenseId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const expense = snap.data();
    const groupId = event.params.groupId;
    const authorId = expense.paidBy;

    // Fetch group members
    const groupSnap = await db.collection('groups').doc(groupId).get();
    if (!groupSnap.exists) return;
    
    const group = groupSnap.data();
    const members = group.members || [];
    
    // Find tokens for all members except author
    const membersToNotify = members.filter(id => id !== authorId);
    if (membersToNotify.length === 0) return;

    const tokens = [];
    // Firestore getAll has a limit of 100 docs per call
    const chunkSize = 100;
    for (let i = 0; i < membersToNotify.length; i += chunkSize) {
      const chunk = membersToNotify.slice(i, i + chunkSize);
      const refs = chunk.map(id => db.collection('users').doc(id));
      const snaps = await db.getAll(...refs);

      for (const userSnap of snaps) {
        if (userSnap.exists) {
          const userData = userSnap.data();
          if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
            tokens.push(...userData.fcmTokens);
          }
        }
      }
    }
    
    if (tokens.length === 0) return;

    // Send multicast message
    const message = {
      notification: {
        title: `New Expense in ${group.name}`,
        body: 'A new expense has been added to your group.',
      },
      data: {
        groupId: groupId,
        type: 'new_expense',
      },
      tokens: tokens,
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Successfully sent ${response.successCount} messages`);
    } catch (error) {
      console.error('Error sending messages:', error);
    }
  }
);

// --- SECURE GROQ API PROXY ---
const callGroqParser = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'GROQ_API_KEY not configured.');
    }
    
    const { messages } = request.data || {};
    if (!messages || !Array.isArray(messages)) {
      throw new HttpsError('invalid-argument', 'messages must be an array.');
    }

    try {
      const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: 'meta-llama/llama-4-scout-17b-16e-instruct',
          messages: messages,
          temperature: 0,
          max_tokens: 256
        })
      });

      if (response.status === 429) {
        throw new HttpsError('resource-exhausted', 'Rate limit exceeded.');
      }
      
      if (!response.ok) {
        throw new HttpsError('internal', `Groq API Error: ${response.status}`);
      }
      
      const data = await response.json();
      return data;
    } catch (e) {
      console.error('Groq Proxy Error:', e);
      throw new HttpsError('internal', e.message || 'Error parsing expense with AI');
    }
  }
);

module.exports = {
  createRazorpayOrder,
  settleAndRestart,
  getUserEncryptionKey,
  getGroupEncryptionKey,
  adminFetchUsers,
  adminFetchGroups,
  adminUpdateUser,
  adminBanUser,
  adminDeleteUser,
  adminDeleteGroup,
  dailyCleanupJob,
  api,
  notifyOnNewExpense,
  callGroqParser,
};
