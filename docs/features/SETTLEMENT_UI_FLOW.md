# Settlement & Close-Cycle UI Flow

Single source of truth for Group Detail settlement actions (Pay / Settle, View settlement, Close cycle).

**Current implementation:** Two buttons — **Pay / Settle** (or **View settlement**) for everyone; **Close cycle** / **Start New Cycle** for creator only. See **Current implementation** at the end of this doc.

---

## Cycle states (quick ref)

| State    | Meaning |
|----------|--------|
| **Active**  | Cycle is open; expenses are being added. |
| **Settling** | Settlement started; people are paying / confirming. Cycle is “closing”. |
| **Settled** | Cycle is closed; waiting for creator to start a new cycle. |

---

## Flow: what happens when you tap the button

### When cycle is **ACTIVE**

Button label: **"Settle now"**

| You have dues? | You are creator? | What happens on tap |
|----------------|------------------|----------------------|
| **Yes**        | —                | → **Settlement Confirmation** screen (integrated UPI: Pay via UPI, QR, Mark as paid, Paid via cash). |
| **No**         | **Yes**          | → **"Settle & Restart"** dialog. Confirm → cycle is closed and a new cycle starts (this is the “close cycle” action). |
| **No**         | **No**           | → Snackbar: *"You have no payments to make. The group creator can close the cycle."* |

- **Integrated UPI** = only when **you have dues**. Same “Settle now” button opens the screen with UPI/cash.
- **Close cycle** = only when **you have no dues** and **you’re the creator**. Same “Settle now” button opens the “Settle & Restart” dialog; confirming there closes the cycle.

### When cycle is **SETTLING** (passive)

Button label: **"Start New Cycle"** (creator) or **"Waiting for creator to restart"** (others)

| You are creator? | What happens on tap |
|------------------|----------------------|
| **Yes**          | → **"Start new cycle?"** dialog. Confirm → cycle archived, new cycle started. |
| **No**           | → Snackbar: *"Only the group creator can start a new cycle."* |

---

## Summary

- **One button** on Group Detail drives both “go pay (UPI)” and “close cycle”:
  - **Have dues** → “Settle now” → **Settlement Confirmation** (UPI/cash).
  - **No dues + creator** → “Settle now” → **Settle & Restart** dialog → **close cycle** on confirm.
- There is **no** separate “Close cycle” or “Pay via UPI” button; the same CTA branches on whether you have dues and whether you’re the creator.

---

## Recommended UX (how it should be)

Two **separate, visible actions** so users don’t have to guess what one button will do.

### When cycle is ACTIVE

| Action | Who sees it | What it does |
|--------|----------------|--------------|
| **Pay / Settle** (or **View settlement**) | Everyone (or at least anyone with group dues) | Opens **Settlement Confirmation** screen: see who owes what, Pay via UPI, Mark as paid, Paid via cash. So “integrated UPI” is always reachable. |
| **Close cycle** (or **Settle & Restart**) | **Creator only** | Opens dialog: “Settle & Restart” / “Start new cycle?”. Confirm → archive cycle and start new one. |

- **Pay / Settle**: one clear entry to the payment/UPI screen. Optionally show even when you have no dues as “View settlement” (status, confirm received, etc.).
- **Close cycle**: only for creator; label makes it obvious this ends the cycle.

### When cycle is SETTLING (passive)

- Same idea: **View settlement** (optional) + **Close cycle** / **Start New Cycle** (creator only).

### Result

- No single button that sometimes means “pay” and sometimes “close cycle”.
- Integrated UPI is always one tap away (Pay / Settle or View settlement).
- Closing the cycle is a separate, explicit creator action.

---

## Current implementation (matches recommended UX)

- **First button** (everyone): **“Pay / Settle”** when you have dues, **“View settlement”** when you don’t (or when cycle is settling). Always opens Settlement Confirmation (UPI/cash, status).
- **Second button** (creator only): **“Close cycle”** when active → Settle & Restart dialog. **“Start New Cycle”** when settling → Start new cycle dialog. Confirm in either dialog closes the cycle and starts a new one.

---

## Example walkthrough (summary card and receiver confirmation)

Use this example to trace the flow. **Group "Trial 10":** two members — **Rishi** (paid for expenses) and **Ash** (owes).

| Step | Who | What |
|------|-----|------|
| 1 | Both | Two expenses: "Tea with Rishi ₹600", "Juice with Rishi ₹69". Cycle total ₹669. Rishi paid both; split implies Ash owes Rishi ₹335 (half). |
| 2 | **Ash** | Opens Group Detail. Summary card shows **Cycle total ₹669**, **You paid ₹0**, **You owe ₹335**. Taps "Pay / Settle" → Settlement Confirmation. |
| 3 | **Ash** | Pays via UPI or taps "Mark as paid". Repo: `markPaymentConfirmedByPayer()` → status `confirmed_by_payer`. |
| 4 | **Ash / Rishi** | **Summary card does not change yet.** Remaining balance uses only **receiver-confirmed** payments. So Ash still sees **You owe ₹335**; Rishi still sees **You're owed ₹335** until Rishi confirms. |
| 5 | **Rishi** | Opens Settlement Confirmation, sees "Incoming" / payment from Ash ₹335. Taps **"Confirm received"**. Repo: `markPaymentConfirmedByReceiver()` → status `confirmed_by_receiver`. |
| 6 | Both | Payment is now **fully confirmed**. `getRemainingBalance()` counts it; summary card updates: Ash **Your status All clear**, Rishi **Your status All clear**. "All payments marked!" and **Start New Cycle** (creator) become available when all routes are receiver-confirmed. |

**Takeaway:** The summary card and "All payments marked" update only **after the receiver** confirms (or cash received). Payer "Mark as paid" alone does not change the card.
