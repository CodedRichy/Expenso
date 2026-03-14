const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

function deriveKey(prefix, id) {
  const raw = process.env.DATA_ENCRYPTION_MASTER_KEY;
  if (!raw) return null;
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

// --- Admin Decryption Helpers ---

function decryptData(base64Key, encryptedString) {
  if (!encryptedString || typeof encryptedString !== 'string' || !encryptedString.startsWith('e:')) {
    return encryptedString;
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
    console.error('Decryption failed:', e);
    return encryptedString;
  }
}

const CREATOR = '605oNyF1miUumLGMgEnaGGD0Lyh2';

const adminFetchUsers = onCall(
  { region: 'asia-south1', secrets: ['DATA_ENCRYPTION_MASTER_KEY'] },
  async (request) => {
    if (!request.auth || request.auth.uid !== CREATOR) {
      throw new HttpsError('permission-denied', 'Admin access required.');
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
    if (!request.auth || request.auth.uid !== CREATOR) {
      throw new HttpsError('permission-denied', 'Admin access required.');
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

module.exports = {
  deriveKey,
  getUserEncryptionKey,
  getGroupEncryptionKey,
  adminFetchUsers,
  adminFetchGroups,
};
