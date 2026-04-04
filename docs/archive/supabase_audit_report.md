# Supabase Integration Audit Report

This report evaluates the Supabase integration after migration from Firebase, focusing on data integrity, query efficiency, and architectural consistency.

## Section 1: Broken or Inefficient Queries

### In-Memory Filtering in Streams
- **Location**: `lib/services/supabase_service.dart` -> `settledCycleExpensesStream` (Line 677)
- **Issue**: The stream fetches the entire `expenses` table for the group and filters for `cycle_id` in Dart.
- **Risk**: High. As the group history grows, this will cause significant performance degradation and memory pressure.
- **Recommendation**: Use `.eq('cycle_id', cycleId)` in the Supabase query.

### Potentially Broken Settlement Logic
- **Location**: `lib/services/supabase_service.dart` -> `archiveCycleExpenses` (Line 640)
- **Issue**: This method performs a client-side multi-step process (Insert cycle -> Update expenses -> Update group) without a transaction.
- **Redundancy**: This appears to be a stale/duplicate implementation of the `settleAndRestart` Edge Function logic.
- **Severity**: medium (if unused) / high (if called)

---

## Section 2: Schema Mismatches

### Cycle Identification Inconsistency
- **Finding**: `GroupRepository` (Line 117) and `CycleRepository` generate `activeCycleId` using `IdUtils.generateCycleId()` (client-side random string).
- **Issue**: If the Supabase `cycles` table uses UUIDs or incremental IDs, this will cause Foreign Key violations or record mismatches.
- **Risk**: medium

### Mapping Anomalies
- **Finding**: `SupabaseService` maps `photoURL` to `avatar_url` (Postgres) but the Dart model still expects `photoURL`. While mapped in the service, the terminology is inconsistent.
- **Finding**: `system_messages.timestamp` is handled as `int` (BigInt), but standard Supabase practice is `timestamptz`.

---

## Section 3: Auth & Identity Issues

### Hardcoded Firebase Regions
- **Location**: `lib/repositories/auth_repository.dart` -> `continueAuth` (Line 130)
- **Issue**: `DataEncryptionService(region: 'asia-south1')`. This is a hardcoded Firebase Cloud Functions region.
- **Severity**: low (Visual/Stale)

### User ID Consistency
- **Check**: `AuthRepository` syncs `uid` from Supabase Auth. 
- **Finding**: `SupabaseService.setUser` uses `.upsert()`. This is safe, but ensure that legacy `uid`s (from Firebase) were correctly mapped to Supabase `auth.users.id` (UUIDs) during the data migration, otherwise `inFilter` queries will return empty results.

---

## Section 4: RLS & Security Policy Analysis

### RLS Bypass via Service Role
- **Finding**: `supabase/functions/settleAndRestart/index.ts` uses `SUPABASE_SERVICE_ROLE_KEY`.
- **Analysis**: While standard for administrative Edge Functions, the lack of defined RLS policies (`CREATE POLICY`) in the repository or migrations folder suggests that security is currently relying on "Admin-level" scripts rather than granular Postgres policies.
- **Risk**: high (Information Disclosure/Unauthorized Modification if ANON key is used directly).

### Missing Transactions
- **Finding**: The `settleAndRestart` Edge Function (Lines 68-100) executes multiple `await` calls sequentially without a Postgres transaction block.
- **Critical Risk**: If the function execution fails halfway, the system could be left in a corrupted state (e.g., active cycle closed, but no new cycle created).

---

## Section 5: Critical Data Risks / Firebase Leavings

### Naming Anomalies (The "Firestore" Ghost)
The following methods and comments still reference Firebase/Firestore, creating significant maintenance confusion:
- `CycleRepository._expenseFromFirestore`
- `CycleRepository._loadCurrentUserProfileFromFirestore`
- `AuthRepository._loadCurrentUserProfileFromFirestore`
- `CycleRepository.dart`: "Persists to Firestore and local cache" (Line 116).

### Data Flow Inconsistency
There is a split between logic implemented in Flutter (`SupabaseService.archiveCycleExpenses`) and logic in Edge Functions (`settleAndRestart`). The Flutter implementation is dangerous as it lacks atomicity and bypasses the centralized logic in the Edge Function.
