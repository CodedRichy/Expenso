# Expenso Screen Architecture Audit

## 1. Research: What Screens Does an Expense-Splitting App Actually Need?

Based on competitive analysis (Splitwise, SettleUp, Tricount) and UX best practices for financial apps, the core user journeys are:

### Essential User Journeys
| Journey | Purpose | Screens Required |
|---------|---------|------------------|
| **Authentication** | Sign up / Sign in | 1-2 screens |
| **Onboarding** | First-time setup | 1 screen |
| **Group Management** | Create, view, manage groups | 2-3 screens |
| **Member Management** | Invite, manage members | 1 screen (or modal) |
| **Expense Entry** | Add expenses | 1-2 screens |
| **Settlement** | Pay balances, track payments | 1-2 screens |
| **History** | View past cycles | 1-2 screens |
| **Profile/Settings** | User preferences, payment methods | 1 screen |

**Industry Standard: 10-14 screens maximum** for a complete expense-splitting app.

---

## 2. Core 100% Necessary Screens for Expenso

Based on the README and your "Cycle" model (active → frozen → archive), here are the **essential** screens:

### Tier 1: Absolutely Critical (Cannot remove)
| Screen | Route | Why Required |
|--------|-------|--------------|
| **RootScreen** | `/` | Auth state routing & deep link handling |
| **PhoneAuth** | (embedded in RootScreen) | Firebase phone authentication |
| **GroupsList** | `/groups` | Main entry, list all user's groups |
| **GroupDetail** | `/group-detail` | Core screen - expenses, balances, status |
| **CreateGroup** | `/create-group` | Group creation flow |
| **ExpenseInput** | `/expense-input` | Add expenses (Magic Bar + manual) |
| **SettlementConfirmation** | `/settlement-confirmation` | Pay/settle balances |
| **ProfileScreen** | `/profile` | User settings, UPI IDs, theme |

**Count: 8 core screens**

### Tier 2: Strongly Recommended (High user value)
| Screen | Route | Why Recommended |
|--------|-------|-----------------|
| **InviteMembers** | `/invite-members` | Shareable links, QR codes for group invites |
| **GroupMembers** | `/group-members` | Manage members, remove, view UPI IDs |
| **EditExpense** | `/edit-expense` | Fix mistakes (inevitable need) |
| **CycleHistory** | `/cycle-history` | View archived cycles |
| **PaymentResult** | `/payment-result` | Post-UPI payment feedback |

**Count: 5 recommended screens**

### Tier 3: Optional / Edge Cases
| Screen | Route | Notes |
|--------|-------|-------|
| **CycleSettled** | `/cycle-settled` | Celebration screen after cycle archive - could be a modal |
| **CycleHistoryDetail** | `/cycle-history-detail` | Deep dive into old cycle - could be modal |
| **InviteResolver** | (deep link only) | Handle invite links - minimal, keep it |

**Total Recommended: 13-16 screens**

---

## 3. Screens You Have But Don't Need

### Current Inventory: 26 Screens

| Screen | Location | Size | Verdict | Action |
|--------|----------|------|---------|--------|
| **CrossGroupDiscovery** | `groups/cross_group_discovery.dart` | 1.4KB | ❌ **Remove** | Placeholder stub, not in roadmap, not routed |
| **UndoExpense** | `expenses/undo_expense.dart` | 1.4KB | ❌ **Convert to Widget** | Full screen wrapping a toast - should be a Snackbar/Overlay |
| **GroupListSkeleton** | `groups/group_list_skeleton.dart` | 2.4KB | ❌ **Convert to Widget** | Skeleton loading state, belongs in widgets/ |
| **MemberChange** | `groups/member_change.dart` | 8KB | ⚠️ **Merge into GroupMembers** | Small screen, could be a modal in GroupMembers |
| **EmptyStates** | `common/empty_states.dart` | ? | ⚠️ **Convert to Widget** | Should be reusable widget, not a routed screen |
| **ErrorStates** | `common/error_states.dart` | ? | ⚠️ **Convert to Widget** | Same as above |

### Detailed Analysis

#### 1. `cross_group_discovery.dart` - REMOVE
```
Status: Stub/Placeholder
Routed: NO (not in main.dart routes)
Referenced: NO
Action: Delete file
```
- Only returns mock data (`['Rahul', 'Ananya', 'Priya']`)
- Listed in README roadmap as future feature ("Cross-Group Discovery")
- Not currently integrated
- **Delete it. Re-add when IdentityService is built.**

#### 2. `undo_expense.dart` - CONVERT TO WIDGET
```
Status: Full screen that wraps a toast
Routed: YES (/undo-expense)
Usage: Overlay/Snackbar replacement
Action: Refactor to use OverlayPortal or showModalBottomSheet
```
- A full Scaffold with transparent background just to show `UndoToast`
- Expensive navigation for a simple action
- Should use: `showUndoSnackBar()` pattern like Gmail

#### 3. `group_list_skeleton.dart` - CONVERT TO WIDGET
```
Status: Skeleton loading UI
Routed: NO (imported by GroupsList)
Action: Move to lib/widgets/skeletons/
```
- Not a screen, it's a loading state component
- Currently in screens/ folder incorrectly

#### 4. `member_change.dart` - MERGE INTO GROUP_MEMBERS
```
Status: Standalone screen for member edits
Routed: YES (/member-change)
Size: 8KB (relatively small)
Action: Convert to modal/dialog within GroupMembers
```
- Handles "change member name/phone"
- Could be a bottom sheet modal in GroupMembers
- Reduces navigation complexity

#### 5. `empty_states.dart` & `error_states.dart` - CONVERT TO WIDGETS
```
Status: Full screens for empty/error states
Routed: YES (/empty-states, /error-states)
Action: Convert to parameterized widgets, use as children in other screens
```
- Currently routed as standalone screens
- Better pattern: `EmptyStateWidget` used inside `GroupsList` when no groups exist
- Error states should be inline widgets, not navigation destinations

---

## 4. Consolidation Recommendations

### Recommended Architecture (13 Screens)

```
lib/screens/
├── auth/
│   └── root_screen.dart              # Routes: / (handles auth + onboarding)
│   └── phone_auth.dart               # (Embedded in RootScreen flow)
│   └── splash_screen.dart            # (Optional, can merge with RootScreen)
├── groups/
│   └── groups_list.dart              # Routes: /groups
│   └── group_detail.dart             # Routes: /group-detail
│   └── create_group.dart             # Routes: /create-group
│   └── group_members.dart             # Routes: /group-members (includes member management)
│   └── invite_members.dart            # Routes: /invite-members
│   └── invite_resolver.dart           # Deep link handling (keep minimal)
├── expenses/
│   └── expense_input.dart             # Routes: /expense-input (includes edit mode)
├── settlement/
│   └── settlement_confirmation.dart   # Routes: /settlement-confirmation
│   └── cycle_history.dart             # Routes: /cycle-history (includes detail view)
│   └── payment_result.dart            # Routes: /payment-result
│   └── cycle_settled.dart             # Routes: /cycle-settled (or merge into modal)
└── settings/
    └── profile.dart                   # Routes: /profile
```

### Widgets to Extract (Move from screens/ to widgets/)

1. `UndoToast` → `lib/widgets/undo_snackbar.dart`
2. `GroupListSkeleton` → `lib/widgets/skeletons/group_list_skeleton.dart`
3. `EmptyState` → `lib/widgets/empty_state.dart`
4. `ErrorState` → `lib/widgets/error_state.dart`

---

## 5. Migration Path

### Phase 1: Remove Dead Code (30 min)
- [ ] Delete `cross_group_discovery.dart`
- [ ] Remove `/empty-states` and `/error-states` routes from `main.dart`
- [ ] Delete `empty_states.dart` and `error_states.dart` screens (convert first if needed)

### Phase 2: Refactor to Widgets (1-2 hours)
- [ ] Convert `UndoExpense` screen to `UndoSnackBar` widget
- [ ] Update all `Navigator.pushNamed('/undo-expense')` calls to show snackbar
- [ ] Move `group_list_skeleton.dart` to `widgets/skeletons/`

### Phase 3: Merge Small Screens (2-3 hours)
- [ ] Merge `member_change.dart` into `group_members.dart` as modal
- [ ] Remove `/member-change` route
- [ ] Update navigation calls in `group_members.dart`

### Phase 4: Consolidate Input (Optional - 2 hours)
- [ ] Merge `edit_expense.dart` into `expense_input.dart` with `isEditMode` flag
- [ ] Single route: `/expense-input` with optional `expense` argument

---

## 6. Summary

| Metric | Current | Recommended | Reduction |
|--------|---------|-------------|-----------|
| **Total Screens** | 26 | 13-16 | ~40-50% |
| **Routed Screens** | 19 | 12 | 37% |
| **Auth Flow** | 4 files | 2 files | 50% |
| **Group Management** | 11 files | 6 files | 45% |
| **Expense Flow** | 3 files | 1-2 files | 33-66% |

**Bottom Line:** You can safely remove **4 screens immediately** (`cross_group_discovery`, `empty_states`, `error_states`, `undo_expense` as screen) and merge **2-3 more** to get down to **13 high-quality, focused screens**.

This aligns with industry standards and reduces maintenance burden while improving UX consistency.
