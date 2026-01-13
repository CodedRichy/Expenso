# Expenso - Navigation Flow Map

## All Screens Connected ✅

### 1. PhoneAuth (`/`)
- **Entry Point**: App starts here
- **Navigation**:
  - After OTP verification → **GroupsList** (`/groups`)

### 2. GroupsList (`/groups`)
- **Navigation**:
  - "Create Group" button → **CreateGroup** (`/create-group`)
  - Tap on any group → **GroupDetail** (`/group-detail`)
  - Empty state "Create Group" button → **CreateGroup** (`/create-group`)

### 3. CreateGroup (`/create-group`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupsList)
  - "Create Group" button → **InviteMembers** (`/invite-members`)

### 4. InviteMembers (`/invite-members`)
- **Navigation**:
  - Back button → Pop to previous screen (CreateGroup)
  - "Done" button → **GroupDetail** (`/group-detail`)

### 5. GroupDetail (`/group-detail`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupsList)
  - Members icon (top right) → **GroupMembers** (`/group-members`)
  - Tap on expense → **EditExpense** (`/edit-expense`)
  - "Add expense" input → **ExpenseInput** (`/expense-input`)
  - "Close cycle" button (when closing) → **SettlementConfirmation** (`/settlement-confirmation`)
  - "Pay now via UPI" button → **SettlementConfirmation** (`/settlement-confirmation`)

### 6. ExpenseInput (`/expense-input`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupDetail)
  - "Confirm" button → Pop back to GroupDetail
  - Shows **UndoExpense** toast after adding (overlay, not navigation)

### 7. UndoExpense (`/undo-expense`)
- **Note**: This is typically shown as an overlay/toast, not a full screen
- Auto-dismisses after 5 seconds

### 8. EditExpense (`/edit-expense`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupDetail)
  - "Save Changes" button → Pop back to GroupDetail
  - "Delete Expense" button → Pop back to GroupDetail
  - If cycle closed, only shows back button

### 9. GroupMembers (`/group-members`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupDetail)
  - Tap on member (future) → **MemberChange** (`/member-change`)

### 10. MemberChange (`/member-change`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupMembers)
  - "Confirm" button → Pop back to GroupMembers
  - "Cancel" button → Pop back to GroupMembers

### 11. DeleteGroup (`/delete-group`)
- **Navigation**:
  - Back button → Pop to previous screen
  - "Delete Group" button → Pop back (group deleted)
  - "Cancel" button → Pop back

### 12. SettlementConfirmation (`/settlement-confirmation`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupDetail)
  - "Continue to Payment" or "Close Cycle" → **PaymentResult** (`/payment-result`)
  - "Cancel" button → Pop back to GroupDetail

### 13. PaymentResult (`/payment-result`)
- **Navigation**:
  - "Done" or "Close" button → **CycleSettled** (`/cycle-settled`)

### 14. CycleSettled (`/cycle-settled`)
- **Navigation**:
  - Back button → Pop to previous screen
  - "Continue" button → **GroupDetail** (`/group-detail`)
  - "View History" button → **CycleHistory** (`/cycle-history`)

### 15. CycleHistory (`/cycle-history`)
- **Navigation**:
  - Back button → Pop to previous screen (GroupDetail or CycleSettled)
  - Tap on any cycle → **CycleHistoryDetail** (`/cycle-history-detail`)

### 16. CycleHistoryDetail (`/cycle-history-detail`)
- **Navigation**:
  - Back button → Pop to previous screen (CycleHistory)

### 17. EmptyStates (`/empty-states`)
- **Types**: `no-groups`, `no-expenses`, `new-cycle`
- **Navigation**:
  - "Create Group" button (no-groups) → **CreateGroup** (`/create-group`)
  - Other types are informational only

### 18. ErrorStates (`/error-states`)
- **Types**: `network`, `session-expired`, `payment-unavailable`, `generic`
- **Navigation**:
  - "Try Again" button → Pop back
  - "Verify" button (session-expired) → **PhoneAuth** (`/`)
  - "Cancel" button → Pop back

---

## Navigation Routes Summary

All routes are defined in `lib/main.dart`:

```dart
routes: {
  '/': (context) => const PhoneAuth(),
  '/groups': (context) => const GroupsList(),
  '/create-group': (context) => const CreateGroup(),
  '/invite-members': (context) => const InviteMembers(),
  '/group-detail': (context) => const GroupDetail(),
  '/expense-input': (context) => const ExpenseInput(),
  '/undo-expense': (context) => const UndoExpense(),
  '/edit-expense': (context) => const EditExpense(),
  '/group-members': (context) => const GroupMembers(),
  '/member-change': (context) => const MemberChange(),
  '/delete-group': (context) => const DeleteGroup(),
  '/settlement-confirmation': (context) => const SettlementConfirmation(),
  '/payment-result': (context) => const PaymentResult(),
  '/cycle-settled': (context) => const CycleSettled(),
  '/cycle-history': (context) => const CycleHistory(),
  '/cycle-history-detail': (context) => const CycleHistoryDetail(),
  '/empty-states': (context) => const EmptyStates(),
  '/error-states': (context) => const ErrorStates(),
}
```

## Navigation Methods Used

- **`Navigator.pushNamed(context, route)`** - Navigate to new screen, keeping current in stack
- **`Navigator.pushReplacementNamed(context, route)`** - Replace current screen with new one
- **`Navigator.pop(context)`** - Go back to previous screen

---

## Testing Navigation Flow

### Primary User Journey:
1. **PhoneAuth** → Enter phone → Enter OTP → **GroupsList**
2. **GroupsList** → Tap "Create Group" → **CreateGroup**
3. **CreateGroup** → Fill details → "Create" → **InviteMembers**
4. **InviteMembers** → Add members → "Done" → **GroupDetail**
5. **GroupDetail** → "Add expense" → **ExpenseInput**
6. **ExpenseInput** → Enter expense → "Confirm" → Back to **GroupDetail**
7. **GroupDetail** → Tap expense → **EditExpense**
8. **GroupDetail** → Members icon → **GroupMembers**
9. **GroupDetail** → "Close cycle" → **SettlementConfirmation**
10. **SettlementConfirmation** → "Continue" → **PaymentResult**
11. **PaymentResult** → "Done" → **CycleSettled**
12. **CycleSettled** → "View History" → **CycleHistory**
13. **CycleHistory** → Tap cycle → **CycleHistoryDetail**

### All Screens Are Now Connected! ✅
