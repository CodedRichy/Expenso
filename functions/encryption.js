const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();

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
  deriveKey,
  getUserEncryptionKey,
  getGroupEncryptionKey,
};
