# Production Review: Expenso

## Shippable: **NO**

---

## Blocking Issues (Priority Order)

### 1. **No `.env` file in repo — app crashes on launch**
`main.dart:42-44` throws a hard `Exception` if `SUPABASE_URL` or `SUPABASE_ANON_KEY` are missing. The `.env` file doesn't exist in the repo (`find_by_name` returned 0 results). Any fresh clone → immediate crash before `runApp`. No `.env.example` either.

### 2. **Email sign-up requires verification before login works — zero UX handling**
`auth_service.dart:70` sends `emailRedirectTo: 'expenso://login-callback'`. After sign-up, the user gets a verification email, but `auth_screen.dart:98-101` only shows a generic "Verification email sent!" snackbar and **does nothing else** — the app stays on the auth screen with no guidance. The deep-link callback (`expenso://login-callback`) has no route handler in `main.dart`. User is stuck.

### 3. **New group has no `activeCycleId` in Supabase — adding expenses silently fails or crashes**
`supabase_service.dart:211-221` inserts the group with `active_cycle_id: activeCycleId` which is `null` (not passed from `create_group.dart:84-88`). `cycle_repository.dart:950-955` then throws `ArgumentError('No active cycle...')` when the user tries to add the first expense. Group creation succeeds but is immediately unusable.

### 4. **`getPaymentAttemptForRoute` reads from `_paymentAttemptsByGroup` (CycleRepository) — always empty**
`cycle_repository.dart:1613-1621` looks up `_paymentAttemptsByGroup[groupId]`, but that map is **never populated** in `CycleRepository`. Payments are stored in `SettlementRepository._paymentAttemptsByGroup` instead. The settlement screen calls `_handleMarkAsPaid` → `getPaymentAttemptForRoute` → always returns `null` → the `if (attempt != null …)` block never executes → **settlement UI does nothing when tapped.**

### 5. **`DataEncryptionService.ensureUserKey()` calls a Supabase Edge Function (`getUserEncryptionKey`) that may not be deployed**
`data_encryption_service.dart:56` calls `functions.invoke('getUserEncryptionKey')`. If that function is not deployed, `continueAuth()` fails silently (exception caught and `_encryption = null`), but more critically, `_writeCurrentUserProfile()` is also called in the same block and **can fail** — this means new users may not get their profile persisted to Supabase, so `currentUserName` stays empty, and `RootScreen` loops them back to `OnboardingNameScreen` on every app open.

---

## Minor Issues

- **`isSettled` is too broad** — `PaymentAttemptStatusX.isSettled` includes `confirmedByPayer` (line 76-78 of `payment_attempt.dart`), meaning a payment the *receiver hasn't confirmed yet* is treated as settled in balance calculations. Balances shown to users will be wrong mid-settlement.

- **`settledCycleExpensesStream` has no filter** — `supabase_service.dart:678-688` fetches ALL expenses (no `.eq('group_id', ...)` on the stream), then filters client-side. On any large dataset this pulls the entire expenses table.

- **Google Sign-In logo fetched from Wikipedia via `Image.network`** — `auth_screen.dart:253`. Will fail silently in offline/restricted environments, showing a fallback icon instead. Should be a local asset.

- **`system_messages` ID collision risk** — `supabase_service.dart:376`: `id: 'sys_$now'` using milliseconds. Concurrent writes from multiple users will collide.

- **`invite_token` is just `DateTime.now().millisecondsSinceEpoch.toString()`** — `supabase_service.dart:844`. Not cryptographically random. Guessable/brute-forceable invite links.

- **No error boundary on settlement screen** — if `SettlementEngine.computePaymentRoutes` throws (e.g. empty member list), the entire screen crashes with no user-visible fallback.

- **Currency symbol hardcoded to `₹` only** — `expense_input.dart:377`: `group.currencyCode == 'INR' ? '₹' : ''`. All non-INR groups show no currency symbol.
