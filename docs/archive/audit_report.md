# Expenso Codebase Audit Report

## Section 1: Screen Inventory

| Screen Name | File Path | Status |
| :--- | :--- | :--- |
| **Splash Screen** | `lib/screens/auth/splash_screen.dart` | Fully Functional |
| **Root Screen** | `lib/screens/auth/root_screen.dart` | Fully Functional |
| **Auth Screen** | `lib/screens/auth/auth_screen.dart` | Fully Functional |
| **Onboarding Name** | `lib/screens/auth/onboarding_name.dart` | Fully Functional |
| **Groups List** | `lib/screens/groups/groups_list.dart` | Fully Functional |
| **Create Group** | `lib/screens/groups/create_group.dart` | Fully Functional |
| **Group Detail** | `lib/screens/groups/group_detail.dart` | **Partially Functional** |
| **Invite Members** | `lib/screens/groups/invite_members.dart` | Fully Functional |
| **Group Members** | `lib/screens/groups/group_members.dart` | Fully Functional |
| **Invite Resolver** | `lib/screens/groups/invite_resolver.dart` | Fully Functional |
| **Edit Expense** | `lib/screens/expenses/edit_expense.dart` | Fully Functional |
| **Expense Input** | `lib/screens/expenses/expense_input.dart` | Fully Functional |
| **Cycle History** | `lib/screens/settlement/cycle_history.dart` | Fully Functional |
| **Cycle History Detail**| `lib/screens/settlement/cycle_history_detail.dart` | Fully Functional |
| **Settlement Confirmation** | `lib/screens/settlement/settlement_confirmation.dart` | Fully Functional |
| **Profile Screen** | `lib/screens/settings/profile.dart` | Fully Functional |

---

## Section 2: Navigation Flow

The main flow from app launch to settlement is mapped as follows:

1.  **Entry**: `main.dart` -> `RootScreen` (Auth State Monitor)
2.  **Auth**: `RootScreen` -> `AuthScreen` (Google/Email/Phone Login)
3.  **Onboarding**: `AuthScreen` -> `OnboardingNameScreen` (Profile Setup)
4.  **Main Hub**: `OnboardingNameScreen` -> `GroupsList` (Dashboard)
5.  **Group Access**: `GroupsList` -> `GroupDetail` (Passes `Group` object)
6.  **Action**: `GroupDetail` -> `ExpenseInput` or `SettlementConfirmation`
7.  **Settlement**: `SettlementConfirmation` -> `PaymentResultSheet` (Refactored to Sheet)

---

## Section 3: Broken or Incomplete Flows

### 1. Dead Routes in `main.dart`
Routes defined in `main.dart` point to non-existent files in `lib/screens/settlement/`:
- `/payment-result`: Target file `payment_result.dart` missing.
- `/cycle-settled`: Target file `cycle_settled.dart` missing.
- **Reason**: These were migrated to bottom sheets in `lib/widgets/` (`payment_result_sheet.dart`, `cycle_settled_sheet.dart`) but the routes were not removed or bridged.

### 2. Navigation Argument Risks
- **`EditExpense`**: Expects `arguments` to be a `Map`. If passed a `Group` or `null` from a deep link or manual push, the screen shows a "Not Found" error instead of resolving the expense.
- **`SettlementConfirmation`**: Contains defensive logic for `Group` vs `Map` arguments, suggesting inconsistent push patterns across the app.

### 3. Missing Deep Link Coverage
- The `InviteResolver` handles group invites, but there is no dedicated routing logic for direct "View Expense" or "Settlement History" deep links (though `main.dart` mentions deep link support).

---

## Section 4: Critical Issues

### 1. UI Placeholders
- **`GroupDetail`**: Line 293 contains `// Placeholder for payment methods/cards`. This is not wired to any backend service or real-time data for user payment methods.

### 2. Mock/Fallback Data Identification
- **`GroupsList`**: The `_DashboardHeroCard` calculation for "Total Balance" relies on `CycleRepository.instance.totalNetBalance`, which computes local state from the current groups list. If `CycleRepository` is not fully synced with Supabase, these numbers are fallbacks.
- **`GroupDetail`**: Uses `SettlementActivityTapToExpand` with `CycleRepository.instance.getPaymentAttemptsForGroup`. If the fetch fails, it shows an empty feed rather than a standard error state.

### 3. Supabase Storage Dependency
- **`ProfileScreen`**: Profile photo upload (Line 91) explicitly warns that it fails if Supabase Storage is not enabled/configured. This is a deployment-side "soft break".

### 4. Compilation Warning (Dead Imports)
- `main.dart` currently imports three missing files in the `settlement` directory, which will prevent a successful build in any environment.
