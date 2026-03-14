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

// --- ADMIN ANALYTICS ---
const adminGetAnalytics = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    // Check if user is admin
    const userDoc = await db.collection('users').doc(request.auth.uid).get();
    if (!userDoc.exists || !userDoc.data().isCreator) {
      throw new HttpsError('permission-denied', 'Admin access required.');
    }

    const { timeRange = '30d' } = request.data || {};
    
    // Calculate date range
    const now = new Date();
    let startDate;
    switch (timeRange) {
      case '7d':
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case '90d':
        startDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
        break;
      case '1y':
        startDate = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
        break;
      default: // 30d
        startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    }

    try {
      // Get user analytics
      const usersSnapshot = await db.collection('users').get();
      const users = usersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      const now = new Date();
      const dau = users.filter(u => u.lastSeenAt && 
        u.lastSeenAt.toDate() > new Date(now.getTime() - 24 * 60 * 60 * 1000)).length;
      const mau = users.filter(u => u.lastSeenAt && 
        u.lastSeenAt.toDate() > new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)).length;
      
      // Get real expense analytics
      const expensesSnapshot = await db
        .collectionGroup('expenses')
        .where('createdAt', '>=', startDate)
        .get();
      
      const expenses = expensesSnapshot.docs.map(doc => doc.data());
      const totalVolume = expenses.reduce((sum, e) => sum + (e.amountMinor || 0), 0);
      const avgExpense = expenses.length > 0 ? totalVolume / expenses.length / 100 : 0;
      
      // Calculate real settlement rate
      const settledExpenses = expenses.filter(e => e.settlementStatus === 'settled').length;
      const settlementRate = expenses.length > 0 ? Math.round((settledExpenses / expenses.length) * 100) : 0;
      
      // Get real group analytics
      const groupsSnapshot = await db.collection('groups').get();
      const groups = groupsSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      const groupSizes = groups.map(g => g.members ? g.members.length : 0);
      const avgGroupSize = groupSizes.length > 0 ? 
        Math.round(groupSizes.reduce((a, b) => a + b, 0) / groupSizes.length) : 0;
      const largeGroups = groupSizes.filter(size => size > 10).length;
      
      // Calculate retention metrics
      const retention1Day = calculateRetention(users, 1);
      const retention7Day = calculateRetention(users, 7);
      const retention30Day = calculateRetention(users, 30);

      return {
        users: {
          total: users.length,
          dau,
          mau,
          newThisPeriod: users.filter(u => u.createdAt && u.createdAt.toDate() >= startDate).length,
          retention: {
            day1: retention1Day,
            day7: retention7Day,
            day30: retention30Day
          }
        },
        expenses: {
          total: expenses.length,
          volume: totalVolume,
          average: avgExpense,
          settlementRate
        },
        groups: {
          total: groups.length,
          avgSize: Math.round(avgGroupSize),
          largeGroups,
          newThisPeriod: groups.filter(g => g.createdAt && g.createdAt.toDate() >= startDate).length
        }
      };
    } catch (error) {
      console.error('Analytics error:', error);
      throw new HttpsError('internal', 'Failed to fetch analytics');
    }
  }
);

// Helper function to calculate retention
function calculateRetention(users, days) {
  const cutoffDate = new Date(Date.now() - (days * 24 * 60 * 60 * 1000));
  const eligibleUsers = users.filter(u => u.createdAt && u.createdAt.toDate() < cutoffDate);
  
  if (eligibleUsers.length === 0) return 0;
  
  const retainedUsers = eligibleUsers.filter(u => 
    u.lastSeenAt && u.lastSeenAt.toDate() > cutoffDate
  ).length;
  
  return Math.round((retainedUsers / eligibleUsers.length) * 100);
}

// --- ADMIN ADVANCED ANALYTICS ---
const adminGetAdvancedAnalytics = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    // Check if user is admin (using CREATOR constant for consistency)
    if (request.auth.uid !== '605oNyF1miUumLGMgEnaGGD0Lyh2') {
      throw new HttpsError('permission-denied', 'Admin access required.');
    }

    const { timeRange = '30d' } = request.data || {};
    
    try {
      const result = {
        sessions: { total: 0, avgDuration: 0, dailyActivity: {}, peakUsage: '12:00' },
        financial: { categoryBreakdown: {}, avgSettlementTime: 0, settlementMethods: {} },
        geographic: {},
        performance: { avgResponseTime: 0, errorRate: 0, uptime: 99.9 },
        business: { total: 0, premium: 0, active: 0, newThisMonth: 0, churned: 0 }
      };

      // Get session analytics (with error handling)
      try {
        const sessionSnapshot = await db.collection('userSessions')
          .where('createdAt', '>=', getTimeRangeStart(timeRange))
          .get();
        
        const sessions = sessionSnapshot.docs.map(doc => doc.data());
        
        // Calculate session metrics
        const sessionDurations = sessions.map(s => s.duration || 0);
        const avgSessionDuration = sessionDurations.length > 0 ? 
          sessionDurations.reduce((a, b) => a + b, 0) / sessionDurations.length : 0;
          
        // Get user activity patterns
        const userActivity = {};
        sessions.forEach(s => {
          const date = s.createdAt.toDate().toDateString();
          userActivity[date] = (userActivity[date] || 0) + 1;
        });
        
        result.sessions = {
          total: sessions.length,
          avgDuration: avgSessionDuration,
          dailyActivity: userActivity,
          peakUsage: findPeakUsageTimes(sessions)
        };
      } catch (sessionError) {
        console.warn('Session analytics failed:', sessionError.message);
      }
      
      // Get financial analytics (with error handling)
      try {
        const expensesSnapshot = await db
          .collectionGroup('expenses')
          .where('createdAt', '>=', getTimeRangeStart(timeRange))
          .get();
        
        const expenses = expensesSnapshot.docs.map(doc => doc.data());
        
        // Calculate category analytics
        const categoryStats = {};
        expenses.forEach(e => {
          const category = e.category || 'uncategorized';
          categoryStats[category] = (categoryStats[category] || 0) + (e.amountMinor || 0);
        });
        
        // Get settlement analytics
        let settlements = [];
        try {
          const settlementsSnapshot = await db
            .collectionGroup('settlements')
            .where('createdAt', '>=', getTimeRangeStart(timeRange))
            .get();
          settlements = settlementsSnapshot.docs.map(doc => doc.data());
        } catch (settlementError) {
          console.warn('Settlement analytics failed:', settlementError.message);
        }
        
        const avgSettlementTime = calculateAvgSettlementTime(expenses, settlements);
        
        result.financial = {
          categoryBreakdown: categoryStats,
          avgSettlementTime,
          settlementMethods: analyzeSettlementMethods(settlements)
        };
      } catch (financialError) {
        console.warn('Financial analytics failed:', financialError.message);
      }
      
      // Get geographic data (with error handling)
      try {
        const geoSnapshot = await db.collection('users')
          .where('lastLocation', '!=', null)
          .get();
        
        const geoData = {};
        geoSnapshot.docs.forEach(doc => {
          const user = doc.data();
          if (user.lastLocation) {
            const country = user.lastLocation.country || 'unknown';
            geoData[country] = (geoData[country] || 0) + 1;
          }
        });
        
        result.geographic = geoData;
      } catch (geoError) {
        console.warn('Geographic analytics failed:', geoError.message);
      }
      
      // Get performance metrics (with error handling)
      try {
        const performanceSnapshot = await db.collection('apiLogs')
          .where('timestamp', '>=', getTimeRangeStart(timeRange))
          .orderBy('timestamp', 'desc')
          .limit(1000)
          .get();
        
        const logs = performanceSnapshot.docs.map(doc => doc.data());
        const avgResponseTime = logs.length > 0 ? 
          logs.reduce((sum, log) => sum + (log.responseTime || 0), 0) / logs.length : 0;
        const errorRate = logs.length > 0 ? 
          (logs.filter(log => log.status >= 400).length / logs.length) * 100 : 0;
        
        result.performance = {
          avgResponseTime,
          errorRate,
          uptime: calculateUptime(logs)
        };
      } catch (performanceError) {
        console.warn('Performance analytics failed:', performanceError.message);
      }
      
      // Get business intelligence (with error handling)
      try {
        const usersSnapshot = await db.collection('users').get();
        const allUsers = usersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        
        const userSegments = {
          total: allUsers.length,
          premium: allUsers.filter(u => u.isPremium).length,
          active: allUsers.filter(u => u.lastSeenAt && 
            (Date.now() - u.lastSeenAt.toDate().getTime()) < 7 * 24 * 60 * 60 * 1000).length,
          newThisMonth: allUsers.filter(u => u.createdAt && 
            u.createdAt.toDate() >= getTimeRangeStart('30d')).length,
          churned: calculateChurnedUsers(allUsers, timeRange)
        };

        result.business = userSegments;
      } catch (businessError) {
        console.warn('Business analytics failed:', businessError.message);
      }

      return result;
    } catch (error) {
      console.error('Advanced analytics error:', error);
      // Return a minimal result instead of throwing an error
      return {
        sessions: { total: 0, avgDuration: 0, dailyActivity: {}, peakUsage: '12:00' },
        financial: { categoryBreakdown: {}, avgSettlementTime: 0, settlementMethods: {} },
        geographic: {},
        performance: { avgResponseTime: 0, errorRate: 0, uptime: 99.9 },
        business: { total: 0, premium: 0, active: 0, newThisMonth: 0, churned: 0 },
        error: 'Some analytics data unavailable'
      };
    }
  }
);

// --- ADMIN USER BEHAVIOR ANALYTICS ---
const adminGetUserBehavior = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const userDoc = await db.collection('users').doc(request.auth.uid).get();
    if (!userDoc.exists || !userDoc.data().isCreator) {
      throw new HttpsError('permission-denied', 'Admin access required.');
    }

    const { userId, timeRange = '30d' } = request.data || {};
    
    try {
      if (!userId) {
        throw new HttpsError('invalid-argument', 'User ID is required');
      }

      // Get user's detailed activity
      const userExpenses = await db
        .collectionGroup('expenses')
        .where('paidBy', '==', userId)
        .where('createdAt', '>=', getTimeRangeStart(timeRange))
        .orderBy('createdAt', 'desc')
        .get();
      
      const userSettlements = await db
        .collectionGroup('settlements')
        .where('fromMemberId', '==', userId)
        .where('createdAt', '>=', getTimeRangeStart(timeRange))
        .get();
      
      const userSessions = await db.collection('userSessions')
        .where('userId', '==', userId)
        .where('createdAt', '>=', getTimeRangeStart(timeRange))
        .orderBy('createdAt', 'desc')
        .get();
      
      const userGroups = await db.collection('groups')
        .where('members', 'array-contains', userId)
        .get();
      
      // Calculate user-specific metrics
      const expenses = userExpenses.docs.map(doc => doc.data());
      const settlements = userSettlements.docs.map(doc => doc.data());
      const sessions = userSessions.docs.map(doc => doc.data());
      
      return {
        expenses: {
          total: expenses.length,
          totalAmount: expenses.reduce((sum, e) => sum + (e.amountMinor || 0), 0),
          categories: analyzeExpenseCategories(expenses),
          frequency: calculateExpenseFrequency(expenses)
        },
        settlements: {
          total: settlements.length,
          totalAmount: settlements.reduce((sum, s) => sum + (s.amountMinor || 0), 0),
          avgTime: calculateAvgSettlementTime(expenses, settlements)
        },
        engagement: {
          sessionCount: sessions.length,
          avgSessionDuration: sessions.length > 0 ? 
            sessions.reduce((sum, s) => sum + (s.duration || 0), 0) / sessions.length : 0,
          screenTime: analyzeScreenTime(sessions),
          groupsActive: userGroups.docs.length
        },
        patterns: {
          spendingPatterns: analyzeSpendingPatterns(expenses),
          activityPatterns: analyzeActivityPatterns(sessions)
        }
      };
    } catch (error) {
      console.error('User behavior error:', error);
      throw new HttpsError('internal', 'Failed to fetch user behavior');
    }
  }
);

// Helper functions
function getTimeRangeStart(timeRange) {
  const now = new Date();
  switch (timeRange) {
    case '7d':
      return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    case '90d':
      return new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
    case '1y':
      return new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
    default: // 30d
      return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  }
}

function calculateAvgSettlementTime(expenses, settlements) {
  let totalTime = 0;
  let count = 0;
  
  settlements.forEach(settlement => {
    const expense = expenses.find(e => e.id === settlement.expenseId);
    if (expense && expense.createdAt && settlement.createdAt) {
      totalTime += settlement.createdAt.toDate() - expense.createdAt.toDate();
      count++;
    }
  });
  
  return count > 0 ? totalTime / count : 0;
}

function findPeakUsageTimes(sessions) {
  const hourCounts = {};
  sessions.forEach(s => {
    const hour = s.createdAt.toDate().getHours();
    hourCounts[hour] = (hourCounts[hour] || 0) + 1;
  });
  
  return Object.keys(hourCounts).reduce((a, b) => 
    hourCounts[a] > hourCounts[b] ? a : b, '12');
}

function calculateChurnedUsers(users, timeRange) {
  const cutoffDate = getTimeRangeStart(timeRange);
  return users.filter(u => 
    u.lastSeenAt && u.lastSeenAt.toDate() < cutoffDate
  ).length;
}

function analyzeSettlementMethods(settlements) {
  const methods = {};
  settlements.forEach(s => {
    const method = s.method || 'unknown';
    methods[method] = (methods[method] || 0) + 1;
  });
  return methods;
}

function analyzeExpenseCategories(expenses) {
  const categories = {};
  expenses.forEach(e => {
    const category = e.category || 'uncategorized';
    categories[category] = (categories[category] || 0) + (e.amountMinor || 0);
  });
  return categories;
}

function calculateExpenseFrequency(expenses) {
  if (expenses.length === 0) return 0;
  const days = new Set(expenses.map(e => e.createdAt.toDate().toDateString())).size;
  return expenses.length / days;
}

function analyzeScreenTime(sessions) {
  const screenTime = {};
  sessions.forEach(s => {
    if (s.screens) {
      Object.keys(s.screens).forEach(screen => {
        screenTime[screen] = (screenTime[screen] || 0) + (s.screens[screen] || 0);
      });
    }
  });
  return screenTime;
}

function analyzeSpendingPatterns(expenses) {
  const dayOfWeek = {};
  expenses.forEach(e => {
    const day = e.createdAt.toDate().getDay();
    dayOfWeek[day] = (dayOfWeek[day] || 0) + (e.amountMinor || 0);
  });
  return dayOfWeek;
}

function analyzeActivityPatterns(sessions) {
  const patterns = {
    morning: 0, afternoon: 0, evening: 0, night: 0
  };
  
  sessions.forEach(s => {
    const hour = s.createdAt.toDate().getHours();
    if (hour >= 6 && hour < 12) patterns.morning++;
    else if (hour >= 12 && hour < 18) patterns.afternoon++;
    else if (hour >= 18 && hour < 22) patterns.evening++;
    else patterns.night++;
  });
  
  return patterns;
}

function calculateUptime(logs) {
  if (logs.length === 0) return 99.9;
  const errors = logs.filter(log => log.status >= 500).length;
  return Math.max(99.9, 100 - (errors / logs.length * 100));
}

// --- ADMIN ACTIVITY LOG ---
const adminGetActivityLog = onCall(
  { region: 'asia-south1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    // Check if user is admin
    const userDoc = await db.collection('users').doc(request.auth.uid).get();
    if (!userDoc.exists || !userDoc.data().isCreator) {
      throw new HttpsError('permission-denied', 'Admin access required.');
    }

    const { limit = 50 } = request.data || {};
    
    try {
      const activities = [];
      
      // Get recent user registrations
      const recentUsers = await db.collection('users')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();
      
      recentUsers.docs.forEach(doc => {
        const user = doc.data();
        activities.push({
          type: 'user_join',
          title: 'New user joined',
          description: `${user.displayName || user.phoneNumber} registered`,
          timestamp: user.createdAt,
          userId: doc.id
        });
      });
      
      // Get recent group creations
      const recentGroups = await db.collection('groups')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get();
      
      recentGroups.docs.forEach(doc => {
        const group = doc.data();
        activities.push({
          type: 'group_create',
          title: 'New group created',
          description: `${group.groupName} by ${group.createdBy}`,
          timestamp: group.createdAt,
          groupId: doc.id
        });
      });
      
      // Sort by timestamp and limit
      activities.sort((a, b) => b.timestamp.toDate() - a.timestamp.toDate());
      return activities.slice(0, limit);
    } catch (error) {
      console.error('Activity log error:', error);
      throw new HttpsError('internal', 'Failed to fetch activity log');
    }
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
