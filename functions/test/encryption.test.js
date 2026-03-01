const test = require('node:test');
const assert = require('node:assert/strict');

const encryption = require('../encryption');

test('deriveKey returns null when DATA_ENCRYPTION_MASTER_KEY is unset', () => {
  const original = process.env.DATA_ENCRYPTION_MASTER_KEY;
  delete process.env.DATA_ENCRYPTION_MASTER_KEY;

  const key = encryption.deriveKey('user', 'u_123');
  assert.equal(key, null);

  if (original !== undefined) {
    process.env.DATA_ENCRYPTION_MASTER_KEY = original;
  }
});

test('deriveKey is deterministic for same prefix/id/master key', () => {
  const original = process.env.DATA_ENCRYPTION_MASTER_KEY;
  process.env.DATA_ENCRYPTION_MASTER_KEY = 'test_master_key';

  const first = encryption.deriveKey('group', 'g_123');
  const second = encryption.deriveKey('group', 'g_123');

  assert.ok(first);
  assert.equal(first, second);

  if (original !== undefined) {
    process.env.DATA_ENCRYPTION_MASTER_KEY = original;
  } else {
    delete process.env.DATA_ENCRYPTION_MASTER_KEY;
  }
});

test('deriveKey changes when prefix changes', () => {
  const original = process.env.DATA_ENCRYPTION_MASTER_KEY;
  process.env.DATA_ENCRYPTION_MASTER_KEY = 'test_master_key';

  const userKey = encryption.deriveKey('user', 'same_id');
  const groupKey = encryption.deriveKey('group', 'same_id');

  assert.notEqual(userKey, groupKey);

  if (original !== undefined) {
    process.env.DATA_ENCRYPTION_MASTER_KEY = original;
  } else {
    delete process.env.DATA_ENCRYPTION_MASTER_KEY;
  }
});
