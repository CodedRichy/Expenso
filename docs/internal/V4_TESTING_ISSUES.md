# V4 Testing Issues

Issues and feedback gathered during V4 testing. Use this for triage and fixes.

**Scope:** Expenso is a **global** app, not India-only. Fixes and features should be locale-aware where relevant (e.g. number formats, payment methods).

---

## 1. App feels laggy

**Reported by:** Another tester (not primary)  
**Area:** Performance / UX  
**Summary:** App feels "a teensy laggy" during use.  
**Status:** Open  
**Notes:** Needs profiling to identify hot paths (list scrolling, balance calc, Firestore listeners, etc.).

---

## 2. UPI payment: app list not shown; QR-only is impractical

**Area:** Settlement / payment flow (UPI in supported regions)  
**Summary:**
- When paying (in UPI flow), the **list of UPI apps did not display**; only the QR showed.
- QR-only is poor UX: user has to screenshot QR → open payment app → scan, which is a hassle.
- **Desired behavior:** Work with status messages from the payment app (intent/response). On failure, retry. In India, flow similar to Zomato/Swiggy (UPI intent → app opens → success/failure callback → retry if failed).

**Status:** Open  
**Notes:** App is global; UPI is one payment option where supported. Likely need UPI intent with `startActivityForResult`/equivalent and handle success/failure; fallback to QR when no app supports intent. Document current UPI implementation and then adjust.

---

## 3. Balance wrong after second expense (2 users)

**Area:** Balances / settlement math  
**Scenario:**
- **Users:** A and B.
- A adds "tea 40" → split correct: +20 for A, 20 for B (or equivalent "for me" / "for him").
- B pays → "You Owe" becomes 0 for both ✓
- B adds "food 400" → expected: +200 for B, -200 for A. **Actual:** showed **-180 for A** (wrong).

**Status:** Open  
**Notes:** Suggests either (a) settlement/cycle close affecting next balance calc, (b) wrong attribution of "food 400" (e.g. who paid, who is "me"), or (c) rounding/off-by-one in balance aggregation. Need to trace: expense creation, cycle state, and `SettlementEngine` / balance display for this sequence.

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
