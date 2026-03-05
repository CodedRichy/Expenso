'use strict';

/**
 * Unit tests for functions/logic.js
 *
 * Run with: npm test  (uses node --test; Node 20+)
 * No Firebase emulator or mocks needed — logic.js is pure.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
    formatDate,
    computeNetBalances,
    applySettledAttempts,
    validateZeroSum,
    validateRazorpayAmount,
} = require('../logic');

// ---------------------------------------------------------------------------
// formatDate
// ---------------------------------------------------------------------------

test('formatDate formats a known date correctly', () => {
    // 2026-03-05T00:00:00 UTC
    const d = new Date('2026-03-05T00:00:00Z');
    const result = formatDate(d);
    assert.ok(result.includes('Mar'), `Expected "Mar" in "${result}"`);
    assert.ok(result.includes('05'), `Expected "05" in "${result}"`);
    assert.ok(result.includes('2026'), `Expected "2026" in "${result}"`);
});

test('formatDate pads single-digit day with leading zero', () => {
    const d = new Date('2026-01-03T00:00:00Z');
    const result = formatDate(d);
    assert.ok(result.includes('03'), `Expected "03" in "${result}"`);
});

// ---------------------------------------------------------------------------
// computeNetBalances — happy path
// ---------------------------------------------------------------------------

test('computeNetBalances: single expense, even split between two members', () => {
    const expenses = [
        {
            amount: 1000,
            amountMinor: 100000,
            paidById: 'alice',
            splitAmountsByIdMinor: { alice: 50000, bob: 50000 },
        },
    ];
    const net = computeNetBalances(expenses);
    // alice paid 100000 and owes 50000 → net +50000
    // bob owes 50000 → net -50000
    assert.equal(net['alice'], 50000);
    assert.equal(net['bob'], -50000);
});

test('computeNetBalances: balances sum to zero', () => {
    const expenses = [
        {
            amount: 600,
            amountMinor: 60000,
            paidById: 'alice',
            splitAmountsByIdMinor: { alice: 20000, bob: 20000, carol: 20000 },
        },
    ];
    const net = computeNetBalances(expenses);
    const total = Object.values(net).reduce((s, v) => s + v, 0);
    assert.equal(total, 0);
});

test('computeNetBalances: multiple expenses accumulate correctly', () => {
    const expenses = [
        {
            amount: 300, amountMinor: 30000, paidById: 'alice',
            splitAmountsByIdMinor: { alice: 15000, bob: 15000 },
        },
        {
            amount: 200, amountMinor: 20000, paidById: 'bob',
            splitAmountsByIdMinor: { alice: 10000, bob: 10000 },
        },
    ];
    const net = computeNetBalances(expenses);
    // alice: paid 30000, owes 15000 + 10000 = 25000 → net +5000
    // bob:   paid 20000, owes 15000 + 10000 = 25000 → net -5000
    assert.equal(net['alice'], 5000);
    assert.equal(net['bob'], -5000);
});

// ---------------------------------------------------------------------------
// computeNetBalances — edge / guard cases
// ---------------------------------------------------------------------------

test('computeNetBalances: skips expense with non-positive amount', () => {
    const expenses = [
        { amount: 0, amountMinor: 0, paidById: 'alice', splitAmountsByIdMinor: { alice: 0, bob: 0 } },
        { amount: -100, amountMinor: -10000, paidById: 'bob', splitAmountsByIdMinor: { alice: -5000, bob: -5000 } },
    ];
    const net = computeNetBalances(expenses);
    assert.deepEqual(net, {});
});

test('computeNetBalances: skips expense with pending-member payer (p_ prefix)', () => {
    const expenses = [
        {
            amount: 500, amountMinor: 50000, paidById: 'p_09876543210',
            splitAmountsByIdMinor: { alice: 25000, bob: 25000 },
        },
    ];
    const net = computeNetBalances(expenses);
    assert.deepEqual(net, {});
});

test('computeNetBalances: skips expense with empty splits', () => {
    const expenses = [
        { amount: 500, amountMinor: 50000, paidById: 'alice', splitAmountsByIdMinor: {} },
    ];
    const net = computeNetBalances(expenses);
    assert.deepEqual(net, {});
});

test('computeNetBalances: skips expense when splits sum mismatches amountMinor by > 1', () => {
    const expenses = [
        {
            amount: 500, amountMinor: 50000, paidById: 'alice',
            // sum = 49990 — mismatch of 10 > 1
            splitAmountsByIdMinor: { alice: 24990, bob: 25000 },
        },
    ];
    const net = computeNetBalances(expenses);
    assert.deepEqual(net, {});
});

test('computeNetBalances: skips splits for pending members (p_ prefix in splits)', () => {
    const expenses = [
        {
            amount: 300, amountMinor: 30000, paidById: 'alice',
            splitAmountsByIdMinor: { alice: 15000, 'p_09999': 15000 },
        },
    ];
    const net = computeNetBalances(expenses);
    // alice's payer credit is still applied; p_ is skipped from debits
    // alice: paid 30000, owes 15000 → net +15000
    // p_ member: skipped
    assert.equal(net['alice'], 15000);
    assert.equal(net['p_09999'], undefined);
});

// ---------------------------------------------------------------------------
// applySettledAttempts
// ---------------------------------------------------------------------------

test('applySettledAttempts: confirmed_by_receiver adjusts balances and returns 0 pending', () => {
    // alice owes bob 20000; she paid and bob confirmed
    const netBalances = { alice: -20000, bob: 20000 };
    const attempts = [
        { fromMemberId: 'alice', toMemberId: 'bob', amountMinor: 20000, status: 'confirmed_by_receiver' },
    ];
    const pending = applySettledAttempts(netBalances, attempts);
    assert.equal(pending, 0);
    assert.equal(netBalances['alice'], 0);
    assert.equal(netBalances['bob'], 0);
});

test('applySettledAttempts: cash_confirmed counts as settled', () => {
    const netBalances = { alice: -10000, bob: 10000 };
    const attempts = [
        { fromMemberId: 'alice', toMemberId: 'bob', amountMinor: 10000, status: 'cash_confirmed' },
    ];
    const pending = applySettledAttempts(netBalances, attempts);
    assert.equal(pending, 0);
    assert.equal(netBalances['alice'], 0);
    assert.equal(netBalances['bob'], 0);
});

test('applySettledAttempts: confirmedByReceiver boolean flag counts as settled', () => {
    const netBalances = { alice: -5000, bob: 5000 };
    const attempts = [
        { fromMemberId: 'alice', toMemberId: 'bob', amountMinor: 5000, confirmedByReceiver: true, status: 'confirmed_by_payer' },
    ];
    const pending = applySettledAttempts(netBalances, attempts);
    assert.equal(pending, 0);
});

test('applySettledAttempts: initiated (not settled) increments pending', () => {
    const netBalances = { alice: -20000, bob: 20000 };
    const attempts = [
        { fromMemberId: 'alice', toMemberId: 'bob', amountMinor: 20000, status: 'initiated' },
    ];
    const pending = applySettledAttempts(netBalances, attempts);
    assert.equal(pending, 1);
    // balances unchanged
    assert.equal(netBalances['alice'], -20000);
    assert.equal(netBalances['bob'], 20000);
});

test('applySettledAttempts: disputed attempt increments pending even if confirmedByReceiver', () => {
    const netBalances = { alice: -20000, bob: 20000 };
    const attempts = [
        { fromMemberId: 'alice', toMemberId: 'bob', amountMinor: 20000, status: 'confirmed_by_receiver', disputed: true },
    ];
    const pending = applySettledAttempts(netBalances, attempts);
    assert.equal(pending, 1);
});

test('applySettledAttempts: mixed settled and pending returns correct count', () => {
    const netBalances = { alice: -20000, bob: 20000, carol: -15000, dave: 15000 };
    const attempts = [
        { fromMemberId: 'alice', toMemberId: 'bob', amountMinor: 20000, status: 'confirmed_by_receiver' },
        { fromMemberId: 'carol', toMemberId: 'dave', amountMinor: 15000, status: 'confirmed_by_payer' }, // not settled
    ];
    const pending = applySettledAttempts(netBalances, attempts);
    assert.equal(pending, 1);
    assert.equal(netBalances['alice'], 0);
    assert.equal(netBalances['bob'], 0);
    assert.equal(netBalances['carol'], -15000); // unchanged
});

// ---------------------------------------------------------------------------
// validateZeroSum
// ---------------------------------------------------------------------------

test('validateZeroSum: all-zero balances returns ok', () => {
    const result = validateZeroSum({ alice: 0, bob: 0, carol: 0 });
    assert.deepEqual(result, { ok: true });
});

test('validateZeroSum: empty balances returns ok', () => {
    const result = validateZeroSum({});
    assert.deepEqual(result, { ok: true });
});

test('validateZeroSum: non-zero balance returns failure with memberId and balance', () => {
    const result = validateZeroSum({ alice: 0, bob: 500 });
    assert.equal(result.ok, false);
    assert.equal(result.memberId, 'bob');
    assert.equal(result.balance, 500);
});

test('validateZeroSum: negative non-zero balance returns failure', () => {
    const result = validateZeroSum({ alice: -300, bob: 300 });
    assert.equal(result.ok, false);
    // either alice or bob could be first, but alice has non-zero
    assert.ok(result.memberId === 'alice' || result.memberId === 'bob');
});

// ---------------------------------------------------------------------------
// validateRazorpayAmount
// ---------------------------------------------------------------------------

test('validateRazorpayAmount: valid minimum amount (100 paise)', () => {
    const result = validateRazorpayAmount(100);
    assert.deepEqual(result, { ok: true });
});

test('validateRazorpayAmount: valid mid-range amount', () => {
    const result = validateRazorpayAmount(50000);
    assert.deepEqual(result, { ok: true });
});

test('validateRazorpayAmount: exactly maximum amount (1000000 paise = ₹10,000)', () => {
    const result = validateRazorpayAmount(1000000);
    assert.deepEqual(result, { ok: true });
});

test('validateRazorpayAmount: null → invalid', () => {
    const result = validateRazorpayAmount(null);
    assert.equal(result.ok, false);
});

test('validateRazorpayAmount: undefined → invalid', () => {
    const result = validateRazorpayAmount(undefined);
    assert.equal(result.ok, false);
});

test('validateRazorpayAmount: below minimum (99) → invalid', () => {
    const result = validateRazorpayAmount(99);
    assert.equal(result.ok, false);
    assert.ok(result.reason.includes('100'));
});

test('validateRazorpayAmount: float rejected as non-integer', () => {
    const result = validateRazorpayAmount(500.5);
    assert.equal(result.ok, false);
});

test('validateRazorpayAmount: string that looks like number → invalid', () => {
    // Number("500") = 500 which is valid, but "500abc" NaN → invalid
    const result = validateRazorpayAmount('500abc');
    assert.equal(result.ok, false);
});

test('validateRazorpayAmount: exceeds maximum → invalid', () => {
    const result = validateRazorpayAmount(1000001); // MAX_PAISE is 1_000_000
    assert.equal(result.ok, false);
    assert.ok(result.reason.includes('maximum'));
});

// ---------------------------------------------------------------------------
// Integration: full settle flow simulation
// ---------------------------------------------------------------------------

test('Full settle flow: zero-expense group → empty balances → ok', () => {
    const net = computeNetBalances([]);
    const pending = applySettledAttempts(net, []);
    assert.equal(pending, 0);
    assert.deepEqual(validateZeroSum(net), { ok: true });
});

test('Full settle flow: one payer, one debtor, payment confirmed → all clear', () => {
    // alice paid 600 for dinner; bob owes 300
    const expenses = [
        {
            amount: 600, amountMinor: 60000, paidById: 'alice',
            splitAmountsByIdMinor: { alice: 30000, bob: 30000 },
        },
    ];
    const net = computeNetBalances(expenses);
    // alice: +30000, bob: -30000

    const attempts = [
        { fromMemberId: 'bob', toMemberId: 'alice', amountMinor: 30000, status: 'confirmed_by_receiver' },
    ];
    const pending = applySettledAttempts(net, attempts);
    assert.equal(pending, 0);

    const check = validateZeroSum(net);
    assert.deepEqual(check, { ok: true });
});

test('Full settle flow: unconfirmed payment blocks settle', () => {
    const expenses = [
        {
            amount: 600, amountMinor: 60000, paidById: 'alice',
            splitAmountsByIdMinor: { alice: 30000, bob: 30000 },
        },
    ];
    const net = computeNetBalances(expenses);
    const attempts = [
        { fromMemberId: 'bob', toMemberId: 'alice', amountMinor: 30000, status: 'confirmed_by_payer' },
    ];
    const pending = applySettledAttempts(net, attempts);
    assert.equal(pending, 1, 'Should block when receiver has not confirmed');
});

test('Full settle flow: partial payment leaves non-zero balance even when confirmed', () => {
    const expenses = [
        {
            amount: 600, amountMinor: 60000, paidById: 'alice',
            splitAmountsByIdMinor: { alice: 30000, bob: 30000 },
        },
    ];
    const net = computeNetBalances(expenses);
    // bob only paid 20000 of 30000 owed
    const attempts = [
        { fromMemberId: 'bob', toMemberId: 'alice', amountMinor: 20000, status: 'confirmed_by_receiver' },
    ];
    const pending = applySettledAttempts(net, attempts);
    assert.equal(pending, 0);
    const check = validateZeroSum(net);
    assert.equal(check.ok, false, 'Partial payment should leave non-zero balance');
});
