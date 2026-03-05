/**
 * Business logic extracted from Cloud Function handlers.
 * These are pure (or near-pure) functions that can be tested without
 * Firebase emulators or mocks of the entire admin SDK.
 *
 * Rules:
 *  - No firebase-admin imports here.
 *  - No onCall / HttpsError usage here.
 *  - Input and output are plain JS objects.
 */

'use strict';

/**
 * Date formatting used for cycle start/end labels.
 * @param {Date} date
 * @returns {string}  e.g. "Mar 05, 2026"
 */
function formatDate(date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const m = months[date.getMonth()];
    const d = String(date.getDate()).padStart(2, '0');
    const y = date.getFullYear();
    return `${m} ${d}, ${y}`;
}

/**
 * Computes net balance per member from a list of expense objects.
 * Mirrors the read path in settleAndRestart exactly so tests share the same logic.
 *
 * @param {Array<object>} expenses  Raw Firestore expense data objects.
 * @returns {Record<string, number>} memberId → minor-unit balance (positive = credit).
 */
function computeNetBalances(expenses) {
    const netBalances = {};
    for (const exp of expenses) {
        if (exp.amount <= 0 || !exp.paidById || exp.paidById.startsWith('p_')) continue;
        const splits = exp.splitAmountsByIdMinor || {};
        if (Object.keys(splits).length === 0) continue;

        let sum = 0;
        for (const amt of Object.values(splits)) sum += amt;
        if (Math.abs(sum - (exp.amountMinor || 0)) > 1) continue;

        netBalances[exp.paidById] = (netBalances[exp.paidById] || 0) + exp.amountMinor;
        for (const [memberId, amt] of Object.entries(splits)) {
            if (memberId.startsWith('p_')) continue;
            netBalances[memberId] = (netBalances[memberId] || 0) - amt;
        }
    }
    return netBalances;
}

/**
 * Applies settled payment attempts to net balances (mutates in place).
 * Returns the count of pending/disputed attempts.
 *
 * @param {Record<string, number>} netBalances  Mutated in place.
 * @param {Array<object>} attempts  Raw PaymentAttempt objects.
 * @returns {number} pendingCount
 */
function applySettledAttempts(netBalances, attempts) {
    let totalPending = 0;
    for (const attempt of attempts) {
        const isSettled =
            attempt.confirmedByReceiver === true ||
            attempt.status === 'confirmed_by_receiver' ||
            attempt.status === 'cash_confirmed';
        const isDisputed = attempt.disputed === true || attempt.status === 'disputed';

        if (!isSettled || isDisputed) {
            totalPending++;
        } else {
            const fromId = attempt.fromMemberId;
            const toId = attempt.toMemberId;
            const amt = attempt.amountMinor || 0;
            netBalances[fromId] = (netBalances[fromId] || 0) + amt;
            netBalances[toId] = (netBalances[toId] || 0) - amt;
        }
    }
    return totalPending;
}

/**
 * Validates that all net balances are exactly zero.
 *
 * @param {Record<string, number>} netBalances
 * @returns {{ ok: true } | { ok: false, memberId: string, balance: number }}
 */
function validateZeroSum(netBalances) {
    for (const [memberId, balance] of Object.entries(netBalances)) {
        if (balance !== 0) {
            return { ok: false, memberId, balance };
        }
    }
    return { ok: true };
}

/**
 * Validates Razorpay order input.
 * @param {*} amountPaise
 * @returns {{ ok: true } | { ok: false, reason: string }}
 */
function validateRazorpayAmount(amountPaise) {
    const amount = amountPaise != null ? Number(amountPaise) : NaN;
    if (!Number.isInteger(amount) || amount < 100) {
        return { ok: false, reason: 'amountPaise must be an integer >= 100.' };
    }
    const MAX_PAISE = 10_00_000;
    if (amount > MAX_PAISE) {
        return { ok: false, reason: 'amountPaise exceeds maximum allowed.' };
    }
    return { ok: true };
}

module.exports = {
    formatDate,
    computeNetBalances,
    applySettledAttempts,
    validateZeroSum,
    validateRazorpayAmount,
};
