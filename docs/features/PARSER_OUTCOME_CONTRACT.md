# Parser outcome contract

Anything else corrupts balances. The parser must output exactly one of three outcomes. Parsed intents flow through a ledger-safe state machine; see `docs/STABILIZATION.md` (§4.1–4.2).

**Tests:** For parser tests you can use the **CLI parser** (`tool/parser_cli.dart`): run with an input string to get real outcomes (e.g. `dart tool/parser_cli.dart "Dinner 500"` or batch `--stress`). Unit tests can assert on `ParsedExpenseResult.fromJson` with JSON produced by the CLI or with hand-crafted contract JSON.

## Three outcomes (strict)

### CONFIDENT — ledger-write-safe

Mark **confident** only if **all** of the following are true:

- Amount is known and > 0
- Exactly one primary intent (no composite)
- Payer is known (explicit or default = speaker)
- Participants are explicit OR safely defaultable (e.g. full group)
- No temporal references (“last time”, “later”, “yesterday”)
- No settlement language (“owe”, “adjust”, “paid back”, “even out”)

**Action:** Write to ledger. Safe to persist and apply to balances.

### CONSTRAINED — ledger-write-allowed but frozen

Use when intent is clear but accounting is incomplete. Trigger if **any** one of these is true:

- Participants inferred from history (“same as usual”)
- Distribution deferred (“we’ll divide later”)
- Mixed expense + settlement language
- Multiple expenses detected in one input
- Amount known but role unclear
- Advance / placeholder expense

**Action:** Record partial/flagged entry. Stored, visible, not applied until validated or completed (frozen state).

### REJECT — hard stop, no ledger mutation

Reject if **any** of these is true:

- Amount missing AND cannot be inferred
- Only future intent (“I’ll pay next time”)
- Emotional / narrative-only input
- Settlement without amount
- Expense vs settlement indistinguishable

**Action:** Do not write. Store as note only, not money. Do **not** ask the user a question.

### Golden rule

**If confidence is wrong, the ledger is wrong.** Never “upgrade” confidence silently (e.g. from constrained to confident without user or explicit rule).

## Strict intent taxonomy

Think in **intent primitives**, not just “expense”. Only one primary intent per ledger event.

| Intent | Description | Required | Optional | Notes |
|--------|-------------|----------|----------|--------|
| **EXPENSE** | Money spent for shared or personal consumption | amount, payer | participants, distribution | Current Magic Bar primary output. |
| **SETTLEMENT** | Money transferred to settle an existing balance | from, to, amount | — | No categories, no participants. |
| **ADVANCE** | Money paid before final allocation | amount, payer | — | Deferred: participants, distribution. |
| **ADJUSTMENT** | Ledger correction without real-world payment | amount, reason | — | Refunds, corrections, rounding. |
| **NOTE** | Non-financial intent | — | — | “I’ll fix it later”, “next time’s on me”, “same as before”. Must **never** touch balances. |

### Composite input rule

One user input may contain **multiple intents** (e.g. “Sam paid for the hotel, I booked the cab”). When that happens:

- Split them into separate intents.
- Each intent gets its own confidence (confident / constrained / reject).
- Failure of one intent does not imply failure of all (e.g. one constrained, one reject).

The parser must support emitting multiple intents (e.g. `intents` array or primary + others) so the app can create one ledger event per intent.

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
- `distributionDeferred` — divide/settle later (semantically clearer than pendingSettlement)
- `pendingSettlement` — debt acknowledged; settle later (prefer distributionDeferred when “we’ll divide later”)
- `advanceNotDistributed` — advance; do not distribute yet
- `cloneFromLast` — copy participants from last matching expense (history-dependent)
- `participantsInferredFromHistory` — “same as usual” / history-based; never mark as confident
- `selfOnly` — no redistribution; self-consumption
- `balanceSmoothingNote` — user intent is balance smoothing; record as normal expense
- `multiIntent` — one sentence describes two or more distinct expenses; emit multiple intents
- `settlementNotExpense` — message describes repaying a debt (settlement), not a new expense; do not create expense
- `settlementsRecordedSeparately` — expense + “already paid back”; settlements are separate ledger events

## Reject reasons

When rejecting: set `parseConfidence: "reject"` and `needsClarification: true`. Do **not** set `clarificationQuestion` (no questions). Reject when:

- No amount and a ledger mutation or debt is implied
- No participants and no rule to infer
- **Future intent** (“I’ll take care of mine next time”) — reject with reason: `futureIntentNotRecordable`; never allow future intent into accounting
- Message is purely a settlement (repaying debt) with no expense to record

## Rules (from feedback)

1. **Never assign a split strategy if participants are unknown.** If participants unknown → `splitType: "unresolved"`. Do not use `participants: []` + `splitType: even` when participants are unknown (logically inconsistent). Either `splitType: unresolved` or codify “default participants = full group” and use that explicitly.

2. **One sentence ≠ one expense.** If the message describes two or more distinct expenses (different payers, different items), emit multiple intents. Example: “Sam paid for the hotel, I booked the cab” → two intents: Hotel (payer Sam, amount unknown), Cab (payer Rishi, amount unknown). Schema must support multiple intents (e.g. `intents` array or primary + other).

3. **Never mark history-based inference as confident.** “Same as usual people” / “usual people” → constrained, `constraintFlags: ["participantsInferredFromHistory"]`. When payer is current user and they said “I paid”, set payer explicitly (e.g. current user name).

4. **Expenses and settlements are separate ledger events.** If the message describes an expense and “already paid back in cash”, output the expense; do not mix in settlements. Flag `settlementsRecordedSeparately` or list settlement intents separately. Expenses + settlements are separate.

5. **Settlement vs expense.** If the message is about repaying a debt (“to clear what I owed”) with no new shared expense, do NOT create an expense. Use constrained + `settlementNotExpense` or reject. A settlement is not an expense.

6. **Non-actionable metadata → notes.** Phrases like “exclude yesterday’s leftovers” are metadata. Store in `notes` (e.g. `["Excludes leftovers from previous day"]`), not as a blocker. Keep constrained if needed.

7. **No amount → never confident.** If amount is missing or 0, never output `parseConfidence: "confident"`. Use constrained + `amountUnresolved` or reject.

8. **Future intent → reject.** “I’ll take care of mine next time” / promises about the future are not recordable. Reject with `futureIntentNotRecordable`. Never allow future intent into accounting.

9. **Exact splits MUST equal the total.** If `splitType` is `"exact"`, the sum of all values in `exactAmounts` MUST perfectly equal the `amount`. If the sum has a "GAP" (e.g. partial amounts are given, but the remainder is not allocated), the system will defensively intercept it as a Validation Error.

10. **The Remainder Rule.** When a user specifies a specific cost for themselves or someone else out of a larger total, the parser MUST distribute the remaining balance equally among all participants, then add that base share to the individual's specific cost, ensuring the total matches exactly. If the parser hallucinates math formulas (e.g., "2600/4") instead of evaluating them, the validation guard will fail it.
