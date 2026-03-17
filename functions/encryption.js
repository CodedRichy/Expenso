const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

function deriveKey(prefix, id) {
  const raw = process.env.DATA_ENCRYPTION_MASTER_KEY;
  if (!raw) {
    console.error('DATA_ENCRYPTION_MASTER_KEY is not set');
    return null;
  }
  let master;
  if (/^[0-9a-fA-F]{63,64}$/.test(raw)) {
    const hex = raw.length === 63 ? '0' + raw : raw;
    master = Buffer.from(hex, 'hex');
  } else {
    master = Buffer.from(raw, 'utf8');
  }
  return crypto
    .createHmac('sha256', master)
    .update(prefix + ':' + id)
    .digest('base64');
}

const getUserEncryptionKey = onCall(
  { region: 'asia-south1', secrets: ['DATA_ENCRYPTION_MASTER_KEY'] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');
    const key = deriveKey('user', request.auth.uid);
    if (!key) throw new HttpsError('failed-precondition', 'Data encryption not configured.');
    return { key };
  }
);

const getGroupEncryptionKey = onCall(
  { region: 'asia-south1', secrets: ['DATA_ENCRYPTION_MASTER_KEY'] },
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

// --- Admin Encryption/Decryption Helpers ---

function decryptData(base64Key, encryptedString) {
  if (!encryptedString || typeof encryptedString !== 'string' || !encryptedString.startsWith('e:')) {
    return encryptedString;
  }
  
  // If key is null, we can't decrypt
  if (!base64Key) {
    return '[Decryption Key Missing]';
  }
  
  try {
    const key = Buffer.from(base64Key, 'base64');
    const buffer = Buffer.from(encryptedString.substring(2), 'base64');
    if (buffer.length < 28) return encryptedString; // 12 (nonce) + 16 (tag)

    const nonce = buffer.slice(0, 12);
    const authTag = buffer.slice(buffer.length - 16);
    const ciphertext = buffer.slice(12, buffer.length - 16);

    const decipher = crypto.createDecipheriv('aes-256-gcm', key, nonce);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(ciphertext, 'binary', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (e) {
    console.error('Decryption failed:', e.message);
    return '[Decryption Failed]';
  }
}

/**
 * Encrypts plaintext using AES-256-GCM, producing the same 'e:' prefixed format
 * as the Flutter client's DataEncryptionService.
 * Format: 'e:' + base64(nonce[12] + ciphertext + authTag[16])
 */
function encryptData(base64Key, plaintext) {
  if (!plaintext || typeof plaintext !== 'string') return plaintext;
  if (!base64Key) {
    console.error('encryptData: key is null, returning plaintext');
    return plaintext;
  }

  try {
    const key = Buffer.from(base64Key, 'base64');
    const nonce = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();
    const combined = Buffer.concat([nonce, encrypted, authTag]);
    return 'e:' + combined.toString('base64');
  } catch (e) {
    console.error('Encryption failed:', e.message);
    return plaintext;
  }
}

const CREATOR = '605oNyF1miUumLGMgEnaGGD0Lyh2';

/**
 * Centralised admin check. Uses Firebase Custom Claims (preferred) with
 * fallback to hardcoded CREATOR UID for backward compatibility.
 *
 * Migration path:
 * 1. Deploy this code
 * 2. Call setAdminClaim({ uid: CREATOR }) to grant the custom claim
 * 3. Once confirmed, remove the CREATOR fallback in a future deploy
 */
function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  // Primary: Firebase Custom Claims
  if (request.auth.token && request.auth.token.admin === true) return;
  // Fallback: hardcoded CREATOR UID (remove after migration)
  if (request.auth.uid === CREATOR) return;
  throw new HttpsError('permission-denied', 'Admin access required.');
}

const adminFetchUsers = onCall(
  { region: 'asia-south1', secrets: ['DATA_ENCRYPTION_MASTER_KEY'] },
  async (request) => {
    requireAdmin(request);

    // Check if encryption key is available
    const raw = process.env.DATA_ENCRYPTION_MASTER_KEY;
    if (!raw) {
      console.error('DATA_ENCRYPTION_MASTER_KEY environment variable is not set');
      // Return users without decryption rather than failing completely
      const usersSnap = await admin.firestore().collection('users').get();
      const users = usersSnap.docs.map(doc => ({
        ...doc.data(),
        uid: doc.id,
        displayName: '[Encryption Key Missing]',
        phoneNumber: '[Encryption Key Missing]',
        photoURL: null,
        upiId: '[Encryption Key Missing]'
      }));
      return { users, warning: 'Encryption key missing - data cannot be decrypted' };
    }

    const [usersSnap, tokensSnap, groupsSnap] = await Promise.all([
      admin.firestore().collection('users').get(),
      admin.firestore().collectionGroup('fcmTokens').get(),
      admin.firestore().collection('groups').get()
    ]);

    const tokenMap = {};
    tokensSnap.docs.forEach(d => {
      const uid = d.ref.parent.parent.id;
      if (!tokenMap[uid]) tokenMap[uid] = { ios: false, android: false };
      const p = d.data().platform;
      if (p === 'ios') tokenMap[uid].ios = true;
      if (p === 'android') tokenMap[uid].android = true;
    });

    const groupDocs = groupsSnap.docs.map(d => ({ uid: d.id, members: d.data().members || [] }));

    const users = usersSnap.docs.map(doc => {
      const data = doc.data();
      const uid = doc.id;
      const key = deriveKey('user', uid);
      
      const decrypted = { ...data, uid };
      ['displayName', 'phoneNumber', 'photoURL', 'upiId'].forEach(field => {
        if (data[field]) decrypted[field] = decryptData(key, data[field]);
      });

      // Add device stats
      decrypted._ios = tokenMap[uid]?.ios || false;
      decrypted._android = tokenMap[uid]?.android || false;

      // Add group count
      decrypted._groupsCount = groupDocs.filter(g => g.members.includes(uid)).length;

      return decrypted;
    });

    return { users };
  }
);

const adminFetchGroups = onCall(
  { region: 'asia-south1', secrets: ['DATA_ENCRYPTION_MASTER_KEY'] },
  async (request) => {
    requireAdmin(request);

    // Check if encryption key is available
    const raw = process.env.DATA_ENCRYPTION_MASTER_KEY;
    if (!raw) {
      console.error('DATA_ENCRYPTION_MASTER_KEY environment variable is not set');
      // Return groups without decryption rather than failing completely
      const snap = await admin.firestore().collection('groups').get();
      const groups = snap.docs.map(doc => ({
        ...doc.data(),
        gid: doc.id,
        groupName: '[Encryption Key Missing]'
      }));
      return { groups, warning: 'Encryption key missing - data cannot be decrypted' };
    }

    const snap = await admin.firestore().collection('groups').get();
    const groups = snap.docs.map(doc => {
      const data = doc.data();
      const gid = doc.id;
      const key = deriveKey('group', gid);
      
      const decrypted = { ...data, gid };
      ['groupName'].forEach(field => {
        if (data[field]) decrypted[field] = decryptData(key, data[field]);
      });
      return decrypted;
    });

    return { groups };
  }
);

// ── Admin User Update ──
const adminUpdateUser = onCall(
  { region: 'asia-south1', secrets: ['DATA_ENCRYPTION_MASTER_KEY'] },
  async (request) => {
    requireAdmin(request);
    const { uid, displayName, isBeta, isCreator } = request.data || {};
    if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');

    const updates = {};
    if (isBeta !== undefined) updates.isBeta = isBeta;
    if (isCreator !== undefined) updates.isCreator = isCreator;

    // Admin sends plaintext displayName — encrypt it before writing to Firestore
    // so E2E encryption is preserved for the user's data.
    if (displayName !== undefined) {
      const key = deriveKey('user', uid);
      if (key) {
        updates.displayName = encryptData(key, displayName);
      } else {
        throw new HttpsError(
          'failed-precondition',
          'Cannot update displayName: encryption key unavailable.'
        );
      }
    }

    await admin.firestore().collection('users').doc(uid).update(updates);
    return { success: true };
  }
);

// ── Admin Ban/Unban User ──
const adminBanUser = onCall(
  { region: 'asia-south1' },
  async (request) => {
    requireAdmin(request);
    const { uid, banned } = request.data || {};
    if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');

    // Set disabled state in Firebase Auth
    await admin.auth().updateUser(uid, { disabled: !!banned });
    // Also flag in Firestore for app to check
    await admin.firestore().collection('users').doc(uid).update({ isBanned: !!banned });

    return { success: true };
  }
);

// ── Admin Delete User ──
const adminDeleteUser = onCall(
  { region: 'asia-south1' },
  async (request) => {
    requireAdmin(request);
    const { uid } = request.data || {};
    if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');
    if (uid === CREATOR) throw new HttpsError('failed-precondition', 'Cannot delete the creator account.');

    // Remove from Firebase Auth
    try { await admin.auth().deleteUser(uid); } catch (e) { console.warn('Auth delete failed:', e.message); }

    // Remove Firestore user doc and subcollections (fcmTokens)
    const userRef = admin.firestore().collection('users').doc(uid);
    const tokensSnap = await userRef.collection('fcmTokens').get();
    const batch = admin.firestore().batch();
    tokensSnap.docs.forEach(d => batch.delete(d.ref));
    batch.delete(userRef);
    await batch.commit();

    return { success: true };
  }
);

// ── Admin Delete Group ──
const adminDeleteGroup = onCall(
  { region: 'asia-south1' },
  async (request) => {
    requireAdmin(request);
    const { groupId } = request.data || {};
    if (!groupId) throw new HttpsError('invalid-argument', 'groupId is required.');

    const groupRef = admin.firestore().collection('groups').doc(groupId);

    // Delete all known subcollections
    const subcollections = [
      'expenses', 'payment_attempts', 'settlement_events',
      'system_messages', 'expense_revisions', 'deleted_expenses'
    ];
    const writer = admin.firestore().bulkWriter();
    for (const sub of subcollections) {
      const snap = await groupRef.collection(sub).get();
      snap.docs.forEach(d => writer.delete(d.ref));
    }
    // Also delete settled_cycles and their expenses
    const cyclesSnap = await groupRef.collection('settled_cycles').get();
    for (const cycleDoc of cyclesSnap.docs) {
      const expSnap = await cycleDoc.ref.collection('expenses').get();
      expSnap.docs.forEach(d => writer.delete(d.ref));
      writer.delete(cycleDoc.ref);
    }
    writer.delete(groupRef);
    await writer.close();

    return { success: true };
  }
);

// ── Set Admin Custom Claim ──
// Call once to migrate from hardcoded UID to Custom Claims.
// Only the current CREATOR can grant or revoke admin.
const setAdminClaim = onCall(
  { region: 'asia-south1' },
  async (request) => {
    // Bootstrap: only the hardcoded CREATOR can set admin claims
    if (!request.auth || request.auth.uid !== CREATOR) {
      throw new HttpsError('permission-denied', 'Only the app creator can set admin claims.');
    }
    const { uid, isAdmin } = request.data || {};
    if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');

    await admin.auth().setCustomUserClaims(uid, { admin: !!isAdmin });
    return { success: true, uid, admin: !!isAdmin };
  }
);

module.exports = {
  deriveKey,
  encryptData,
  requireAdmin,
  getUserEncryptionKey,
  getGroupEncryptionKey,
  adminFetchUsers,
  adminFetchGroups,
  adminUpdateUser,
  adminBanUser,
  adminDeleteUser,
  adminDeleteGroup,
  setAdminClaim,
};
