'use strict';

/**
 * Lightweight in-memory rate limiter for Cloud Functions.
 *
 * Limits each authenticated user to a configurable number of calls
 * per time window. Uses a sliding window counter stored in-process.
 *
 * Limitations:
 * - In-memory only: resets on cold start / new instance.
 * - Per-instance: each Cloud Function instance has its own counter.
 *   This is acceptable for a small-scale app; for high-traffic services,
 *   use Redis or Firestore-based rate limiting.
 *
 * Usage:
 *   const limiter = createRateLimiter({ maxCalls: 20, windowMs: 60_000 });
 *   // Inside a Cloud Function:
 *   limiter.check(request.auth.uid); // throws HttpsError if over limit
 */

const { HttpsError } = require('firebase-functions/v2/https');

/**
 * Creates a rate limiter instance.
 *
 * @param {object} options
 * @param {number} options.maxCalls  Maximum calls allowed per window.
 * @param {number} options.windowMs  Window duration in milliseconds.
 * @returns {{ check: (uid: string) => void }}
 */
function createRateLimiter({ maxCalls = 30, windowMs = 60_000 } = {}) {
  // Map<uid, { count, windowStart }>
  const windows = new Map();

  // Periodically clean up expired entries to prevent memory leaks.
  // Run every 5 minutes.
  setInterval(() => {
    const now = Date.now();
    for (const [uid, entry] of windows.entries()) {
      if (now - entry.windowStart > windowMs * 2) {
        windows.delete(uid);
      }
    }
  }, 5 * 60_000).unref(); // .unref() so the timer doesn't keep the process alive

  return {
    /**
     * Checks if the user is within the rate limit.
     * Throws HttpsError('resource-exhausted') if over limit.
     *
     * @param {string} uid  The authenticated user's UID.
     */
    check(uid) {
      if (!uid) return; // unauthenticated calls are handled elsewhere

      const now = Date.now();
      let entry = windows.get(uid);

      if (!entry || now - entry.windowStart > windowMs) {
        // New window
        entry = { count: 1, windowStart: now };
        windows.set(uid, entry);
        return;
      }

      entry.count++;
      if (entry.count > maxCalls) {
        throw new HttpsError(
          'resource-exhausted',
          `Rate limit exceeded. Try again in ${Math.ceil((entry.windowStart + windowMs - now) / 1000)} seconds.`
        );
      }
    },
  };
}

// Pre-configured limiters for different function categories.
// These are shared across all invocations within the same instance.

/** Standard API calls: 30 per minute per user */
const standardLimiter = createRateLimiter({ maxCalls: 30, windowMs: 60_000 });

/** AI/expensive calls (Groq parser): 10 per minute per user */
const aiLimiter = createRateLimiter({ maxCalls: 10, windowMs: 60_000 });

/** Admin calls: 60 per minute per admin */
const adminLimiter = createRateLimiter({ maxCalls: 60, windowMs: 60_000 });

module.exports = {
  createRateLimiter,
  standardLimiter,
  aiLimiter,
  adminLimiter,
};
