# Parser outcome contract

Anything else corrupts balances. The parser must output exactly one of three outcomes.

## Three outcomes

| Outcome | Action | Meaning |
|--------|--------|--------|
| **Confident parse** | Write to ledger | Full, valid expense; no flags. Safe to persist. |
| **Constrained parse** | Write partial / flagged entry | Intent clear but something missing or ambiguous. Record what is known; set flags so the app can mark pending, defer distribution, or surface for later correction. |
| **Reject** | Needs clarification (no questions) | Do not write. Impossible to infer safely, or missing required data (e.g. no amount). Do **not** ask the user a question; just reject. |

## Stress test — one-shot expected behavior

### 1. Paid ₹2800 for dinner — some of us ordered more, you know how it was.
- **Outcome:** Reject  
- **Reason:** No participants, no rule. Impossible to infer safely.

### 2. Alex booked the tickets and I sent my part already.
- **Outcome:** Constrained parse  
- **Action:** Record settlement Rishi → Alex (amount unknown). Mark amount as unresolved.  
- **Reason:** Intent clear, value missing.

### 3. Paid ₹1500 for snacks. Sam showed up late, Jordan barely ate.
- **Outcome:** Constrained parse  
- **Action:** Record expense ₹1500 by Rishi. Include all group members. Flag: participant weights ambiguous.  
- **Reason:** Humans expect later correction.

### 4. I covered the cab back since my phone was dead.
- **Outcome:** Reject  
- **Reason:** No amount, no participants.

### 5. Prasi paid for lunch yesterday — I'll fix it later.
- **Outcome:** Constrained parse  
- **Action:** Record expense by Prasi. Participants = full group (default). Mark as pending settlement.  
- **Reason:** Time reference irrelevant; intent is debt acknowledgement.

### 6. Paid ₹4000 for the stay. We'll settle once everyone's back.
- **Outcome:** Constrained parse  
- **Action:** Record advance expense ₹4000 by Rishi. Participants = unknown. Do not distribute yet.  
- **Reason:** Advance, not an expense yet.

### 7. Jordan paid for petrol again. Same people as last time.
- **Outcome:** Constrained parse (history-dependent)  
- **Action:** Clone last petrol expense participants. New payer = Jordan. Same distribution.  
- **Reason:** Safe only because history exists.

### 8. I paid ₹900 extra because my order was separate.
- **Outcome:** Constrained parse  
- **Action:** Add self-only expense ₹900 by Rishi. No redistribution.  
- **Reason:** "Separate" implies self-consumption.

### 9. Alex owes me from before — just adjust it here.
- **Outcome:** Reject  
- **Reason:** No amount = illegal ledger mutation.

### 10. Paid ₹2200 for food. This should even things out mostly.
- **Outcome:** Constrained parse  
- **Action:** Record normal expense ₹2200. Full group. Add note: user intent = balance smoothing.  
- **Reason:** Don't interpret emotion as math.

## Constraint flags (for constrained parse)

When `parseConfidence` is `"constrained"`, include one or more of:

- `amountUnresolved` — amount missing or to be filled later
- `participantsUnknown` — use full group or do not distribute yet
- `participantWeightsAmbiguous` — who shares is unclear; flag for later correction
- `pendingSettlement` — debt acknowledged; settle later
- `advanceNotDistributed` — advance; do not distribute yet
- `cloneFromLast` — copy participants from last matching expense (history-dependent)
- `selfOnly` — no redistribution; self-consumption
- `balanceSmoothingNote` — user intent is balance smoothing; record as normal expense

## Reject rule

When rejecting: set `parseConfidence: "reject"` and `needsClarification: true`. Do **not** set `clarificationQuestion` (no questions). The app will refuse to write and may show a generic "Unable to parse" or "Need more details" without prompting the user with a specific question.
