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

## More (to be added)

*Additional items will be appended below as reported.*
