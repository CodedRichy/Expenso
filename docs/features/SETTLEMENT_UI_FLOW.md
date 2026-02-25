# Settlement & Close-Cycle UI Flow

Single source of truth for what the main button on Group Detail does and when you see UPI vs close-cycle.

---

## The one main button

On **Group Detail**, when the cycle is not settled, you see **one primary button**. Its label and behavior depend on **cycle state** and **your role**.

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
