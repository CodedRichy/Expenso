# V4 Testing Issues

Issues and feedback gathered during V4 testing. Use this for triage and fixes.

**Scope:** Expenso is a **global** app, not India-only. Fixes and features should be locale-aware where relevant (e.g. number formats, payment methods).

---

## 1. App feels laggy

**Reported by:** Another tester (not primary)  
**Area:** Performance / UX  
**Summary:** App feels "a teensy laggy" during use.  
**Status:** Addressed  
**Notes:** Two optimizations applied: (1) **Scoped group refresh**: `_refreshGroupAmounts([String? groupId])` — when an expense stream updates for one group, only that group’s amount/status is recomputed instead of iterating all groups. (2) **Coalesced UI updates**: Firestore stream callbacks (`_onExpensesSnapshot`, `_onSystemMessagesSnapshot`, `_onPaymentAttemptsSnapshot`, `_onGroupsSnapshot`, `_loadUsersForMembers`) call `_requestNotify()` instead of `notifyListeners()`. Pending notifications are flushed once per event-loop turn via a microtask, so multiple rapid stream events (e.g. expense + system message + payment attempt) cause one rebuild instead of several. User-initiated actions still call `notifyListeners()` directly for immediate feedback. If lag persists, next steps: profile with Flutter DevTools (CPU frame times, rebuild counts), consider `RepaintBoundary` on heavy cards, or per-group `ValueNotifier` to reduce rebuild scope.

---

## 2. UPI payment: app list not shown; QR-only is impractical

**Area:** Settlement / payment flow (UPI in supported regions)  
**Summary:**
- When paying (in UPI flow), the **list of UPI apps did not display**; only the QR showed.
- **Desired behavior:** Zomato/Swiggy-style: show app list → pick app → intent opens app → complete payment → return with success/failure → retry if failed. No QR in flow.

**Status:** Fixed  
**Changes:** (1) **Always open payment sheet** — removed pre-fetch and early return when no UPI apps; tapping "Pay via UPI" always opens the bottom sheet so the app list is shown when available. (2) **Removed QR from UPI flow** — no "Show QR" button or QR code on the card; primary path is app list → intent → status (success/failure) → retry. (3) **No-apps state** — when no UPI apps are found, sheet shows message to install an app plus "I've paid" and "Cancel". (4) Status messages and retry already handled by waiting overlay (success/failure/pending + "Try Again" / "Retry Payment").

---

## 3. Balance wrong after second expense (2 users)

**Area:** Balances / settlement math  
**Scenario:**
- **Users:** A and B.
- A adds "tea 40" → split correct: +20 for A, 20 for B (or equivalent "for me" / "for him").
- B pays → "You Owe" becomes 0 for both ✓
- B adds "food 400" → expected: +200 for B, -200 for A. **Actual:** showed **-180 for A** (wrong).

**Status:** Fixed  
**Root cause:** Balances were computed from **all expenses in the cycle** only. After B paid A ₹20, that payment was "confirmed" but the **tea 40 expense stayed in the cycle**. When B added "food 400", net was recomputed from tea 40 + food 400 → A: 20−200 = −180, B: +180. The confirmed payment (B→A 20) was only applied when it matched a **current** payment route; after adding food 400 the only route was A→B 180, so the B→A 20 adjustment was never applied.  
**Fix:** `getNetBalancesAfterSettlementsMinor` now computes raw net from expenses then **applies every fully confirmed payment attempt** (from += amount, to −= amount), regardless of current routes. `calculateBalances`, `getRemainingBalance`, `getSettlementInstructions`, `getSettlementTransfersForCurrentUser`, and settlement confirmation routes all use this "net after settlements," so remaining balances and payment instructions stay correct after new expenses are added.

---

## 4. Parser: number words and user direction (3 users)

**Area:** Parser / Magic Bar  
**Scenario:**
- **Users:** A, B, C.
- A types: **"user b owes me 4 lakh"** (example from testing; "lakh" = 100,000 in Indian number system).
- **Parser issues:**
  1. Amount interpreted as **4** instead of **400000** (number word "lakh" not expanded).
  2. **Users/direction wrong** — who owes whom was incorrect.

**Status:** Fixed  
**Notes:** (1) **Number words:** Parser prompt instructs the model to expand lakh (100000), crore (10000000), million (1000000), billion (1000000000) and output the numeric amount. Code: `expandNumberWordsInText()` normalizes user input before the API call and in fallback amount extraction, so "4 lakh" → 400000 even when the API fails or is unavailable. (2) **Debt direction:** Prompt section "OWES ME / I OWE" and examples: "user B owes me 4 lakh" → amount 400000, payer = current user, participants = [B], splitType exact, exactAmounts { currentUser: 0, B: 400000 }; "I owe B 500" → payer B, participants = [current user], exactAmounts { B: 0, currentUser: 500 }. App remains global; number words are locale-aware (Indian + international).

---

## 5. Add expense: WHO'S INVOLVED overflow (201 px)

**Area:** Add expense screen / layout  
**Summary:** With keyboard open, the "WHO'S INVOLVED" section (e.g. "Select All" and member list) overflows by **201 pixels** — yellow/black strip "BOTTOM OVERFLOWED BY 201 PIXELS" in debug.  
**Status:** Fixed  
**Notes:** Main form wrapped in `Expanded` + `SingleChildScrollView` so WHO'S INVOLVED fits when the keyboard is open; overflow eliminated.

---

## 6. Create group: Poor contrast on Settlement Rhythm / Settlement Day

**Area:** Create group (or group settings) / accessibility  
**Summary:** Options for "Settlement Rhythm" (Monthly, Trip-based) and "Settlement Day" (e.g. Sunday) have **very low contrast** on the dark background — light grey labels that are hard to read.  
**Status:** Fixed  
**Notes:** Settlement Rhythm / Day labels and dropdown use `Theme.of(context).colorScheme.onSurface` for readable contrast on dark background.

---

## 7. Settlement: Conflicting state — incoming payment + "You're all settled"

**Area:** Settlement screen / state logic  
**Summary:** Screen shows **both**:
- "Incoming payments" — "1 payment awaiting your confirmation" (e.g. Ihsir, ₹335 UPI) with a "Confirm" button, and
- "You're all settled! You have no payments to make this cycle."

If a payment is awaiting confirmation, the user is not fully settled. The two states are mutually exclusive.  
**Status:** Fixed  
**Notes:** "You're all settled!" only when there are no UPI dues and no pending confirmations. When there are pending incoming payments, the screen shows "Confirm the payment(s) above" and the UPI section uses pending count; the two states are mutually exclusive.

---

## 8. Profile: Payment Settings / UPI ID overflow (60 px)

**Area:** Profile / Payment Settings / layout  
**Summary:** With keyboard open, the bottom of the screen (UPI ID input and Save button) overflows by **60 pixels** — "BOTTOM OVERFLOWED BY 60 PIXELS" in debug.  
**Status:** Fixed  
**Notes:** Profile body (avatar, Payment Settings, Log out) wrapped in `Expanded` + `SingleChildScrollView` so content doesn't overflow when the keyboard is open.

---

## 9. Settlement success: "You're all settled!" content not centered

**Area:** Settlement success screen / layout  
**Summary:** On the "You're all settled!" success screen (green checkmark, message, "Back to Group"), the content is **not centered** on the screen.  
**Status:** Fixed  
**Notes:** When no dues and no pending confirmations, success content ("You're all settled!" etc.) is shown in an `Expanded` + `Center` layout so it is centered on screen.

---

## Gaps (pre-existing / follow-up)

Issues that are not V4 tester-reported bugs but are gaps worth tracking for triage. Some are documented in STABILIZATION.md or LOGIC_AUDIT.md; this list surfaces them in one place.

---

### G1. Accessibility (a11y)

**Area:** All screens / UX  
**Summary:** No `Semantics` or `semanticsLabel` (or equivalent) are used in the codebase. Screen readers and TalkBack will not get explicit labels for buttons, amounts, or sections. Touch targets and contrast have been improved in places but there is no systematic a11y pass.  
**Status:** Addressed  
**Notes:** Added `Semantics` with `label` and `button: true` to key actions: Groups list FAB (Create new group), Create Group screen button, Profile Log out, Settlement Back to Group. More screens can be covered in a follow-up pass.  
**Ref:** groups_list.dart, create_group.dart, profile.dart, settlement_confirmation.dart.

---

### G2. Locale-aware number/currency formatting

**Area:** Global app / V4 scope  
**Summary:** V4 scope states the app is global and should be "locale-aware where relevant (e.g. number formats)". Currently:
- `money_format.dart` uses comma as thousands separator and dot for decimals (US/IN style). No locale-based formatting (e.g. `intl`); EU-style (space/dot for thousands, comma for decimals) is not supported.
- Many screens format amounts with inline `replaceAllMapped(RegExp(...))` for "₹X,XXX" instead of a single locale-aware formatter.
**Status:** Addressed  
**Notes:** Added `intl` package. `formatMoneyWithCurrency()` now uses `NumberFormat.currency` with device locale (`PlatformDispatcher.instance.locale`) so thousands/decimal separators follow the user's region. Optional third parameter `locale` allows override (e.g. from BuildContext). Fallback to previous formatting if intl fails. Call sites that still use inline `replaceAllMapped` for amounts could later be migrated to this formatter for consistency.  
**Ref:** `lib/utils/money_format.dart`, `pubspec.yaml` (intl).

---

### G3. Split amounts sum not validated on read

**Area:** Balances / data integrity  
**Summary:** STABILIZATION §4.3: "Split amounts must sum to expense amount — ⚠️ Assumed but not enforced. The code computes splits at write time but does not validate sum equality on read. Historical data may have rounding errors." If stored splits ever diverge from the expense total, balance math can be wrong and there is no read-side check or correction.  
**Status:** Addressed  
**Notes:** In `SettlementEngine.expenseToDeltas()`, when an expense has `splitAmountsById`, we now check that the sum of splits is within 0.01 of the expense amount. If not (or if sum is NaN/Infinite), we skip that expense from balance computation and log in debug. Invalid or legacy data no longer corrupts balances.  
**Ref:** `lib/utils/settlement_engine.dart`, `docs/STABILIZATION.md` §4.3 invariant #3.

---

### G4. Integer-amounts migration incomplete (TODOs)

**Area:** Data model / consistency  
**Summary:** TODOs in code: "Remove once UI is updated to use integer amounts" (settlement_engine.dart, ledger_delta.dart). SettlementEngine and ledger work with minor-unit integers in places, but UI and some paths still use double amounts. Migration is incomplete; double-based paths remain.  
**Status:** Deferred (documented) — **Revisit triggered**  
**Decision:** Option 2 — document and defer. G3 (split-sum validation) already protects balance correctness.  
**Update:** More currencies are now supported (CurrencyRegistry includes scale 0: JPY, KRW; scale 3: KWD, BHD; scale 2: others). With mixed scales, double-based storage is more prone to rounding in splits. Revisiting the migration is recommended.  
**Next step:** Phase 1 (write-path bridge) implemented: when saving an expense we write `amountMinor` and `splitsMinor` to Firestore; read path prefers them when present and populates `Expense.amountMinor` / `splitAmountsByIdMinor`; settlement uses the integer path for such expenses. Encryption supports the new fields. Old expenses without minor fields continue to use the legacy double path.  
**Ref:** `lib/utils/settlement_engine.dart` (lines 317, 334), `lib/utils/ledger_delta.dart` (line 160), `lib/models/currency.dart`.

---

### G5. Silent or empty catch blocks

**Area:** Error handling / observability  
**Summary:** Some failures are swallowed with no user feedback or logging:
- `groq_expense_parser_service.dart`: `catch (_) {}` in fallback/decode paths.
- `data_encryption_service.dart`: empty `catch (_) {}` in key paths.
- `pinned_groups_service.dart`: `catch (_) {}` then `notifyListeners()` — load failure is silent.
If these paths fail, the user may see generic or incorrect behavior with no indication why.  
**Status:** Addressed  
**Notes:** Replaced silent catches with `if (kDebugMode) debugPrint(...)` so failures are visible in debug builds. Parser: cache example failure, strict/relaxed JSON decode failures. DataEncryptionService: participantIds/splits restore failures. PinnedGroupsService: load failure and save failure. No user-facing messages added (services don't have context); consider SnackBar in UI layer for pin save failure if desired.  
**Ref:** groq_expense_parser_service.dart, data_encryption_service.dart, pinned_groups_service.dart.

---

### G6. Closed cycles not read-only in Firestore

**Area:** Security / invariants  
**Summary:** STABILIZATION §4.3: "Closed cycles are read-only — ⚠️ Assumed but not enforced. Firestore rules may not prevent writes to settled_cycles." Current `firestore.rules` allow create, update, delete on `groups/{groupId}/settled_cycles/{cycleId}` and its expenses for any group member. There is no rule that makes archived cycles immutable.  
**Status:** Addressed  
**Notes:** Updated `firestore.rules`: `settled_cycles` and `settled_cycles/{cycleId}/expenses` now allow **read** and **create** only; **update** and **delete** are denied (`allow update, delete: if false`). Archive flow still works (create); no one can modify or delete archived cycle data after creation.  
**Ref:** `firestore.rules`, `docs/STABILIZATION.md` §4.3 invariant #8.

---

### G7. Date stored as string; timezone-fragile

**Area:** Data model / global use  
**Summary:** STABILIZATION §5: "Date stored as string... Expense `date` field is 'Today', 'Yesterday', or 'Mon DD'. This makes date math fragile and timezone-dependent." For a global app, this can cause ordering or "today" boundaries to differ by locale/timezone.  
**Status:** Open — **Discuss**  
**Ref:** `docs/STABILIZATION.md` §5 design shortcut #8.

---

### G8. No pagination (scale)

**Area:** Performance / scale  
**Summary:** Group list, expense list, and cycle history load in full. Acceptable for small datasets; will degrade with hundreds of expenses per cycle or many groups. STABILIZATION §5 lists this as a known limitation.  
**Status:** Acknowledged — **Discuss** if/when to prioritize.  
**Ref:** `docs/STABILIZATION.md` §5 limitation #6.

---

## Discuss with me (not fixed by code alone)

These need product or design decisions, or are larger efforts:

| Gap | Why not fixed in code |
|-----|------------------------|
| **G7** Date as string / timezone | Schema and data migration: would require storing ISO date or timestamp, then deriving "Today"/"Yesterday" in UI from device timezone. Existing data would need backfill or dual read. |
| **G8** No pagination | Feature work: cursor-based or page-based loading for groups, expenses, and history. Deciding when to prioritize (e.g. when groups or cycle size grows). |

**G4** (integer amounts) is deferred by decision; see G4 section above.

---

## More (to be added)

*Additional items will be appended below as reported.*
