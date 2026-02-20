# List of issues

## Fixed (this session)

| Issue | Fix |
|-------|-----|
| UID→phone resolution dropped participants when building `Expense` from Firestore (only used `_userCache`) | `_expenseFromFirestore` now uses `_membersById[uid]?.phone` first, then `_userCache`, so participants are not dropped when cache is missing. |
| Repo `calculateBalances` defaulted missing payer to current user; group detail (engine) did not | `calculateBalances` only adds expense amount to net when `paidByPhone` is non-empty and in `phones`; matches engine. |
| Parser had no explicit pattern for "I had dinner with &lt;name&gt; &lt;amount&gt;" | Added rule and generic few-shot examples (e.g. "I had dinner with B 200", "lunch with C 450") so model learns pattern and uses runtime member list for names. |
| Member list has no real names (only phones) | When building the list sent to the parser, if a member’s display name is empty or looks like a phone number, we now use the device contact name for that phone (when contacts permission granted and a contact exists). Parser gets more real names. |
| Name resolution used group members only | After trying group member display names, we now fall back to device contacts: if the typed name matches a contact’s display name (exact or partial), and that contact’s phone belongs to a group member, we resolve to that member. "Alice" can resolve via contact when that contact is in the group. |

---

## Open / to investigate

| Issue | Notes |
|-------|------|
| Balance / settlement logic wrong in some cases | User reported problems; expected vs actual to be filled in `SETTLEMENT_LOGIC_NOTES.md`. Logic (even among all, "Spent by you" vs "Your status", running nets) is implemented; if app still shows wrong numbers, likely cause is **who is in the split** (parser or stored data). |
| Parser sometimes assumes wrong participants | e.g. returns `participants: []` for "with alice" so app treats as everyone; or wrong name. Prompt, examples, and COMMON MISTAKES improved; monitor and add more rules/examples if it recurs. |

---

## Known limitations / environment

| Area | Issue |
|------|--------|
| Build | Java 8 source/target obsolete; Razorpay deprecated API. |
| Device (Nothing AIN065) | Invalid resource ID 0x0 (NothingExperience); NtQueueManager logs; userfaultfd timeout; Choreographer "40 frames skipped" (possible startup jank). |
| GMS / Firebase | DEVELOPER_ERROR (SHA-1 / package config); App Check placeholder; Firestore bloom filter fallback; null X-Firebase-Locale. |
| Session | Lost connection to device can end `flutter run` with exit code 1. |

---

## Reference docs

- **Settlement:** `SETTLEMENT_WHERE_AND_WHY.md`, `SETTLEMENT_LOGIC_NOTES.md`
- **Parser / who is involved:** `PARSER_AND_WHO_IS_INVOLVED.md`
- **Terminal errors:** `TERMINAL_ERRORS_LOG.md`
