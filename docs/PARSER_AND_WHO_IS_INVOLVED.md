# Parser and "who is involved" — problem and current behavior

## What you want

For input like **"i had dinner with alice 200"**:

1. **Parser** identifies: I am the payer, description = dinner, amount = 200, **participants = [Alice]** (so split is between me and Alice only — 2 people, ₹100 each).
2. **App** resolves "alice" to the **group member** whose display name (or contact name) is Alice, gets that member’s UID/phone, and writes the expense with that person in the split.
3. **Summary** for that user (Alice) updates correctly: her net balance and "Your status" reflect the new expense.

So: correct **who paid** (me), correct **who is involved** (me + Alice only), and correct **identity** (alice → actual member so the right person’s summary changes).

---

## Can the parser identify "i had dinner with alice 200"?

**Designed to:** Yes. The system prompt says:

- "with X", "with X and Y" → participants = [X] or [X, Y] (only the others; app adds current user).
- "dinner 300 with B" → participants: ["B"], even.
- Member list is injected at runtime; model must use exact spellings from that list and can map typos/nicknames (e.g. "alice" → "Alice" if "Alice" is in the list).

So for "i had dinner with alice 200" the intended output is: amount 200, description Dinner, splitType even, **participants: ["Alice"]** (assuming "Alice" is in the member list), no payer (current user pays).

**In practice:** The model can still sometimes return wrong participants (e.g. `[]` so the app treats it as "everyone", or the wrong name). So **at times it’s wrong when assuming who’s involved** — e.g. it assumes everyone when it should be me + Alice, or vice versa.

---

## Can the app resolve "alice" to a contact/member and get user id?

**How it works today:**

- Resolution is **only against group members**, not the device contact list.
- The app gets **group member names** from `getMemberDisplayName(m.phone)` for each member:
  - **Full members:** name from Firestore `users/{uid}.displayName` (what they set in profile/onboarding).
  - **Pending members:** name from the group’s `pendingMembers` (the name we stored when inviting, e.g. from the contact picker).
- So "alice" is matched to a **group member** whose display name (or stored invite name) equals or partially matches "alice" (case-insensitive, plus substring logic). When there’s a single partial match it’s marked as a guess (user should verify).
- When we find that member we have their `phone` (and UID via repo). The expense is then saved with that person in the **splits** map, so their summary (net balance, status) **does** get updated.

**So:**

- **If** there is a group member whose name in the app is "Alice" (or matches "alice") → we can resolve and update that user’s summary. We do **not** look up "a contact named Alice" on the device; we only use the **group member list** (Firestore displayName + pending invite names).
- **If** the group member has no display name (only phone number shown) → we send something like "+91 XXXXX XXXXX" in the member list to the parser, and we match "alice" against that in the confirmation step. So "alice" won’t match and you get "Select Member" until the user picks the right person. So we’re **not** using "contact with the name alice" from the phone — we’re using "group member whose name we know in the app."

---

## Where it goes wrong (why "at times it’s wrong")

1. **Parser assumes wrong participants**
   - Returns `participants: []` for "with alice" → app treats as split among **everyone**.
   - Or returns the wrong name / wrong number of people → wrong split and wrong summaries.

2. **Member list sent to the parser has no real names**
   - If most members have no display name (only phone), the list is "You, +91 …, +91 …". Then the parser can’t map "alice" to an entry and may return `[]` or leave the name as "alice", and resolution in the app may fail (no match against phone numbers).

3. **Payer vs involved**
   - For "i had dinner with alice 200" the payer is **me** and the people involved are **me + Alice**. The prompt is clear that "with X" means participants = [X] and the app adds me, so total = 2. If the parser instead returns `[]`, the app assumes everyone is involved — that’s the "assuming whose involved" mistake.

---

## Summary

- **Is the parser able to identify "i had dinner with alice 200"?**  
  Yes, by design: payer = me, participants = [Alice], amount 200, description dinner. In practice it sometimes gets participants wrong (e.g. everyone instead of me + Alice).

- **Is the app able to understand "a contact with the name alice" and take that user id and update that user’s summary?**  
  It doesn’t use device contacts. It uses **group members**. If a group member has the name "Alice" in the app (Firestore displayName or invite name), we resolve "alice" to that member, get their UID/phone, write the expense with them in the split, and **their summary does update**. If they’re only shown as a phone number, resolution can fail until the user selects the member manually.

- **Why "at times wrong as assuming whose involved"?**  
  Because the parser sometimes returns wrong participants (e.g. `[]` for "with alice"), so the app assumes the wrong set of people (e.g. everyone) and the split and summaries don’t match your intent (me + Alice only).

Next steps that would help: (1) add a few-shot example for "i had dinner with alice 200" / "dinner with alice 200" in the parser prompt so the model is more consistent; (2) optionally improve name resolution (e.g. prefer names from contacts for numbers we have in the group). I can do (1) in the code next if you want.
