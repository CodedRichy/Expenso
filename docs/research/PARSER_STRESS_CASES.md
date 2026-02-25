# Parser stress cases (evaluation & training)

Use these inputs to test the CLI parser and to curate training/fine-tuning data. **Do not** put all of them into the live prompt—that would blow token usage and hit rate limits. Keep the prompt lean; use this list for evaluation and for expanding `parser_training_data.jsonl` (with correct target JSON) when you fine-tune.

## Rate limits

- Groq (and similar APIs) limit tokens per minute. A long system prompt + many in-prompt examples can push a single request over the limit (e.g. 11–12K).
- **CLI:** Recent log examples are capped (default 5) to keep prompt size bounded. If you see rate-limit errors, reduce that cap or temporarily disable log-driven examples.

## Running stress cases via CLI

Pass the stress inputs to the CLI in batch so each line is one API call, with throttling between requests (avoids blowing the rate limit):

```bash
dart tool/parser_cli.dart --stress
```

Uses `tool/parser_stress_inputs.txt` by default (one input per line). To use another file:

```bash
dart tool/parser_cli.dart --stress path/to/inputs.txt
```

Each run is throttled (e.g. 4s between requests), logged to `tool/parser_runs.log`, and the outcome (CONFIDENT / CONSTRAINED / REJECT or ERROR) is printed per line.

---

## Amount ambiguity / missing

- Paid for dinner yesterday.
- Alex paid for snacks.
- I covered the cab.
- Jordan paid for fuel again.
- Paid some amount for food.

**Expected:** Constrained with `amountUnresolved` or reject when amount cannot be inferred.

---

## Participants unclear / implied

- Paid ₹2400 for dinner — you know who was there.
- Lunch ₹1200, same people as last time.
- Paid ₹800 for snacks, usual gang.
- Dinner ₹3000, minus leftovers.
- Paid ₹600 for coffee, not everyone joined.

**Expected:** Constrained; `participantsUnknown` or `participantsInferredFromHistory`; `splitType: unresolved` when participants unknown.

---

## History-dependent references

- Same as usual, ₹1500 for food.
- Jordan paid like last time.
- Split it like the trip.
- Groceries ₹2000, same distribution as before.
- Paid ₹1000, adjust it like yesterday.

**Expected:** Constrained; `participantsInferredFromHistory` or similar; never confident.

---

## Settlement vs expense confusion

- Paid ₹750 to clear what I owed.
- Jordan settled his part ₹600.
- I sent Alex ₹500 already.
- Paid ₹1200, this evens things out.
- Paid ₹900 to balance things.

**Expected:** Settlement-only → constrained + `settlementNotExpense` or reject (no expense). Expense + “evens out” → constrained + note; do not treat as settlement.

---

## Future intent (must reject)

- I'll take care of my share next time.
- Alex will pay me later.
- We'll settle this tomorrow.
- I owe Sam, will pay soon.
- Next dinner's on me.

**Expected:** Reject; `rejectReason: futureIntentNotRecordable` or equivalent. No ledger entry.

---

## Multi-intent in one sentence

- Sam paid for lunch, I booked the cab.
- Paid ₹2000 for food and ₹500 for parking.
- Alex covered tickets, I paid for snacks.
- Jordan paid hotel, I paid fuel.
- I paid dinner, Alex paid drinks.

**Expected:** Constrained; `constraintFlags: ["multiIntent"]`; single object (primary or first) — do not collapse into one amount.

---

## Partial repayments / mixed settlement

- Alex paid ₹1500, I already sent ₹500.
- Paid ₹1000, Jordan still owes me.
- Sam paid ₹2000, I covered half later.
- Paid ₹1800, Prasi paid me back in cash.
- Jordan owes me from before, include it here.

**Expected:** Expense recorded; settlements / “paid back” handled separately (`settlementsRecordedSeparately`) or constrained; no amount for “owes me from before” → reject or constrained.

---

## Exclusions / narrative noise

- Paid ₹2200 for food, exclude yesterday stuff.
- Dinner ₹3000, not counting Sam's order.
- Paid ₹1600, Jordan barely ate.
- Lunch ₹900, Alex joined late.
- Snacks ₹700, Prasi didn't have any.

**Expected:** Exclusions → `exclude` + `excluded` or notes; narrative (“barely ate”, “joined late”) → notes or participant-weights ambiguous; constrained when unclear.

---

## Self-only / free / edge intent

- Paid ₹500 for coffee, this one's on me.
- I paid ₹400 extra for my order.
- Paid ₹600 just for myself.
- Covered my own ticket ₹1200.
- Paid ₹350 for my stuff.

**Expected:** Constrained; `selfOnly` or equivalent; no redistribution.

---

## Explicit but tricky math

- Dinner ₹2000 — I had 1200, Alex 500, Sam 300.
- Trip ₹3000 — Rishi 2 nights, Jordan 1 night.
- Rent ₹5000 — me 60%, Prasi 40%.
- Snacks ₹900 — Jordan 300, rest split.
- Food ₹2500 — exclude Alex and Sam.

**Expected:** Exact/shares/percentage split with correct `exactAmounts` / `sharesAmounts` / `percentageAmounts`; “rest split” may be constrained; exclude → `excluded` list.
