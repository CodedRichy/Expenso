# Where settlement is tracked and why it can be inconsistent

## Where the app keeps track

**1. Persistence (source of truth)**  
- **Firestore** `groups/{groupId}/expenses` — each expense has `amount`, `payerId` (UID), `splits` (map UID → share).  
- There is no separate "participant list" stored; "who is in the split" is implied by the keys of `splits`. So the app keeps track by **what gets written** when you add an expense (Magic Bar or manual form). If the write uses all three UIDs in `splits`, the split is among three; if it uses two, the split is between two.

**2. In-memory after read**  
- **CycleRepository** loads expenses via `_onExpensesSnapshot` and turns each Firestore doc into an `Expense` in **`_expensesByCycleId`**.  
- That conversion is **`_expenseFromFirestore`**: it builds `participantPhones` and `splitAmountsByPhone` **only from the `splits` map**. For each UID in `splits` it resolves UID → phone (current user’s phone for self, else `_userCache[uid]` / `_membersById`). If the phone is missing (e.g. cache not ready or lookup fails), that UID is **skipped** and not added to `participantPhones`. So an expense that was stored as "even among 3" can be **read back as "among 1 or 2"** if resolution fails for some members.  
- So "where it keeps track" for balances is: **Firestore** (what’s in `splits`) and then **in-memory** `cycle.expenses` with `participantPhones` / `splitAmountsByPhone` as derived from those splits. If derivation drops people, balances are wrong.

**3. Who uses that data**  
- **Group detail (Balances + Decision Clarity):** uses **SettlementEngine** with `cycle.expenses` and `getMembersForGroup(groupId)`. So it uses the in-memory expenses (with possibly wrong participantPhones if resolution dropped someone).  
- **Settlement confirmation / "Settle now" / Razorpay:** use **CycleRepository** `getSettlementInstructions` and `getSettlementTransfersForCurrentUser`, which use **`calculateBalances(groupId)`** on the same in-memory expenses. So same data, but **calculateBalances** had a different bug: when `expense.paidByPhone` was empty it defaulted to **currentUserPhone**, so that expense’s amount was attributed to the current user. The engine does not do that (it only adds to net when payer is non-empty). So **two code paths** (engine vs repo) could show different numbers for the same group when payer resolution failed.

---

## Why it’s not consistent across groups / not "keeping track" the way you expect

1. **Participant list when reading**  
   If UID → phone fails for any member in an expense’s `splits`, that member is omitted from `participantPhones`. Then "even among 3" is computed as "even among 2" (or 1), so shares and nets are wrong. That can vary by group (e.g. different load order, or one group has members not yet in `_userCache` / `_membersById`).

2. **Payer attribution in repo**  
   When `paidByPhone` was empty (e.g. payer UID not resolved to phone), the repo treated the payer as the current user. So "Spent by you" and settlement instructions could be wrong for that expense, and differ from what the engine would show (engine doesn’t add that amount to anyone).

3. **Two implementations of the same math**  
   SettlementEngine (group detail) and CycleRepository.calculateBalances (settlement dialog / Razorpay) both implement "payer +amount, participants −share". So when data is correct, they agree. When data is wrong (missing participants or wrong payer), they can disagree because of the payer default above.

4. **What gets written (Magic Bar / form)**  
   For "even among everyone", the app only keeps track correctly if the **add** path writes **all** members into `splits`. That happens when `participantPhones` is empty (then code uses `allPhones`) or when the parser/form sends everyone. If the parser sends e.g. only the current user for "paid 300 for dinner", then only one person is in `splits` and the split is wrong from the start.

---

## Summary

- **Where it keeps track:** Firestore `splits` (and `payerId`) per expense; then in-memory `Expense.participantPhones` / `splitAmountsByPhone` derived in **`_expenseFromFirestore`**.  
- **Why it’s not seen / not consistent:** (a) UID→phone resolution can drop participants when building `participantPhones`; (b) repo used to default missing payer to current user; (c) two code paths (engine vs repo) so bugs can show up in one place and not the other.  
- **Fixes applied:** (1) Resolve UID→phone using `_membersById` first, then `_userCache`, so we don’t drop participants when cache is missing. (2) In `calculateBalances`, do not default payer to current user when `paidByPhone` is empty; only add to net when we have a valid payer (match engine).
