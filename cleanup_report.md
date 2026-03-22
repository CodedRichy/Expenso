# Codebase Cleanup Report

This report identifies unused files, dead routes, duplicate logic, and legacy artifacts for potential removal.

## Section 1: Unused Files & Modules

| File or Module | Issue | Safe to Delete | Risk Level |
| :--- | :--- | :--- | :--- |
| `lib/screens/auth/splash_screen.dart` | Exists in filesystem but is not registered in `main.dart` routes; `RootScreen` handles initialization. | Yes | Low |
| `lib/services/razorpay_order_service.dart` | Zero references found in the codebase. Likely a remnant of a discarded payment provider. | Yes | Low |
| `lib/services/data_encryption_service.dart` | Over-engineered for current local state requirements (caching profile info). Supabase handles transit/at-rest security. | No (Refactor first) | Medium |
| `lib/services/fcm_token_service.dart` | References Firebase Cloud Messaging; app has migrated to Supabase. | No (Check Push strategy) | Medium |

## Section 2: Dead Routes (main.dart)

| Route Path | Screen File | Status | Action |
| :--- | :--- | :--- | :--- |
| `/payment-result` | `lib/screens/settlement/payment_result.dart` | Missing from filesystem (or misplaced). | [NEW] Create or remove route. |

## Section 3: Legacy Naming & "Firestore" Remnants

| File | Issue | Safe to Cleanup | Risk Level |
| :--- | :--- | :--- | :--- |
| `lib/repositories/cycle_repository.dart` | Contains methods like `_expenseFromFirestore` and comments referencing Firestore. | Yes (Rename) | Low |
| `lib/repositories/auth_repository.dart` | Contains `_loadCurrentUserProfileFromFirestore`. | Yes (Rename) | Low |
| `lib/services/user_profile_cache.dart` | Comments refer to Firestore as the source of truth. | Yes (Update docs) | Low |
| `lib/models/expense.dart` | Mapper methods use "Firestore" terminology. | Yes (Rename) | Low |

## Section 4: Duplicate Logic & Redundancy

| Logic Area | Redundancy Source | Issue | Risk Level |
| :--- | :--- | :--- | :--- |
| **User State** | `AuthRepository` vs `CycleRepository` | Both repositories maintain `_currentUserId` and profile maps, leading to sync overhead. | Medium |
| **Settlement** | Client Logic vs Edge Function | `SupabaseService.archiveCycleExpenses` (Client) performs a multi-step update that is also handled by `settleAndRestart` (Backend). | High |
| **Models** | `NormalizedExpense` | App uses both `Expense` and `NormalizedExpense`. One may be redundant depending on specific UI requirements. | Medium |
| **Auth** | `identity_service.dart` | Overlaps with `AuthService` and `Supabase.instance.auth`. | Low |
