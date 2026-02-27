# V4 Testing Issues

Issues and feedback gathered during V4 testing. Use this for triage and fixes.

**Scope:** Expenso is a **global** app, not India-only. Fixes and features should be locale-aware where relevant (e.g. number formats, payment methods).

---

## 1. App feels laggy

**Reported by:** Another tester (not primary)  
**Area:** Performance / UX  
**Summary:** App feels "a teensy laggy" during use.  
**Status:** Addressed  
**Notes:** Two optimizations applied: (1) **Scoped group refresh**: `_refreshGroupAmounts([String? groupId])` — when an expense stream updates for one group, only that group’s amount/status is recomputed instead of iterating all groups. (2) **Coalesced UI updates**: Firestore stream callbacks (`_onExpensesSnapshot`, `_onSystemMessagesSnapshot`, `_onPaymentAttemptsSnapshot`, `_onGroupsSnapshot`, `_loadUsersForMembers`) call `_requestNotify()` instead of `notifyListeners()`. Pending notifications are flushed once per event-loop turn via a microtask, so multiple rapid stream events (e.g. expense + system message + payment attempt) cause one rebuild instead of several. User-initiated actions still call `notifyListeners()` directly for immediate feedback. If lag persists, next steps: profile with Flutter DevTools (CPU frame times, rebuild counts), consider `RepaintBoundary` on heavy cards, or per-group `ValueNotifier` to reduce rebuild scope.

---

## 2. UPI payment: app list not shown; QR-only is impractical

**Area:** Settlement / payment flow (UPI in supported regions)  
**Summary:**
- When paying (in UPI flow), the **list of UPI apps did not display**; only the QR showed.
- **Desired behavior:** Zomato/Swiggy-style: show app list → pick app → intent opens app → complete payment → return with success/failure → retry if failed. No QR in flow.

**Status:** Fixed  
**Changes:** (1) **Always open payment sheet** — removed pre-fetch and early return when no UPI apps; tapping "Pay via UPI" always opens the bottom sheet so the app list is shown when available. (2) **Removed QR from UPI flow** — no "Show QR" button or QR code on the card; primary path is app list → intent → status (success/failure) → retry. (3) **No-apps state** — when no UPI apps are found, sheet shows message to install an app plus "I've paid" and "Cancel". (4) Status messages and retry already handled by waiting overlay (success/failure/pending + "Try Again" / "Retry Payment").

---

## 3. Balance wrong after second expense (2 users)

**Area:** Balances / settlement math  
**Scenario:**
- **Users:** A and B.
- A adds "tea 40" → split correct: +20 for A, 20 for B (or equivalent "for me" / "for him").
- B pays → "You Owe" becomes 0 for both ✓
- B adds "food 400" → expected: +200 for B, -200 for A. **Actual:** showed **-180 for A** (wrong).

**Status:** Fixed  
**Root cause:** Balances were computed from **all expenses in the cycle** only. After B paid A ₹20, that payment was "confirmed" but the **tea 40 expense stayed in the cycle**. When B added "food 400", net was recomputed from tea 40 + food 400 → A: 20−200 = −180, B: +180. The confirmed payment (B→A 20) was only applied when it matched a **current** payment route; after adding food 400 the only route was A→B 180, so the B→A 20 adjustment was never applied.  
**Fix:** `getNetBalancesAfterSettlementsMinor` now computes raw net from expenses then **applies every fully confirmed payment attempt** (from += amount, to −= amount), regardless of current routes. `calculateBalances`, `getRemainingBalance`, `getSettlementInstructions`, `getSettlementTransfersForCurrentUser`, and settlement confirmation routes all use this "net after settlements," so remaining balances and payment instructions stay correct after new expenses are added.

---

## 4. Parser: number words and user direction (3 users)

**Area:** Parser / Magic Bar  
**Scenario:**
- **Users:** A, B, C.
- A types: **"user b owes me 4 lakh"** (example from testing; "lakh" = 100,000 in Indian number system).
- **Parser issues:**
  1. Amount interpreted as **4** instead of **400000** (number word "lakh" not expanded).
  2. **Users/direction wrong** — who owes whom was incorrect.

**Status:** Open  
**Notes:** App is global. Parser should support locale-aware number words where useful (e.g. lakh/crore, million/billion) and correctly resolve "user B owes me" (B is debtor, A is creditor). Add to parser prompt/constraints and stress tests; avoid hardcoding a single region.

---

## 5. Add expense: WHO'S INVOLVED overflow (201 px)

**Area:** Add expense screen / layout  
**Summary:** With keyboard open, the "WHO'S INVOLVED" section (e.g. "Select All" and member list) overflows by **201 pixels** — yellow/black strip "BOTTOM OVERFLOWED BY 201 PIXELS" in debug.  
**Status:** Open  
**Notes:** Content is too tall for available space when keyboard is visible. Use scrollable layout (e.g. `SingleChildScrollView`) or resize/inset for keyboard so the section fits.

---

## 6. Create group: Poor contrast on Settlement Rhythm / Settlement Day

**Area:** Create group (or group settings) / accessibility  
**Summary:** Options for "Settlement Rhythm" (Monthly, Trip-based) and "Settlement Day" (e.g. Sunday) have **very low contrast** on the dark background — light grey labels that are hard to read.  
**Status:** Open  
**Notes:** Accessibility issue. Increase contrast (e.g. lighter text or different background) so labels meet readability guidelines.

---

## 7. Settlement: Conflicting state — incoming payment + "You're all settled"

**Area:** Settlement screen / state logic  
**Summary:** Screen shows **both**:
- "Incoming payments" — "1 payment awaiting your confirmation" (e.g. Ihsir, ₹335 UPI) with a "Confirm" button, and
- "You're all settled! You have no payments to make this cycle."

If a payment is awaiting confirmation, the user is not fully settled. The two states are mutually exclusive.  
**Status:** Open  
**Notes:** Bug in state management or UI conditions. Incoming-pending and all-settled should not render together; gate "You're all settled" on there being no pending incoming (and no outgoing) payments.

---

## 8. Profile: Payment Settings / UPI ID overflow (60 px)

**Area:** Profile / Payment Settings / layout  
**Summary:** With keyboard open, the bottom of the screen (UPI ID input and Save button) overflows by **60 pixels** — "BOTTOM OVERFLOWED BY 60 PIXELS" in debug.  
**Status:** Open  
**Notes:** Same class of issue as #5: layout doesn't account for keyboard. Make the form scrollable or adjust insets when keyboard is visible.

---

## 9. Settlement success: "You're all settled!" content not centered

**Area:** Settlement success screen / layout  
**Summary:** On the "You're all settled!" success screen (green checkmark, message, "Back to Group"), the content is **not centered** on the screen.  
**Status:** Open  
**Notes:** Center the checkmark, title, subtitle, and CTA vertically/horizontally for a proper success-state layout.

---

## More (to be added)

*Additional items will be appended below as reported.*
