# Data Flow: Screens → Database (SQL Table Format)

This document shows all data written from each screen to Firestore, presented in SQL-like table format for clarity.

> **Note:** Expenso uses Cloud Firestore (NoSQL), not SQL. The tables below represent the *logical* structure of data as if it were relational.

---

## Database Collections Overview

```
Firestore Collections:
├── users/{uid}                                    # User profiles
├── groups/{groupId}                               # Group documents
│   ├── expenses/{expenseId}                       # Current cycle expenses
│   ├── settled_cycles/{cycleId}                   # Archived cycle metadata
│   │   └── expenses/{expenseId}                   # Archived expenses
│   ├── system_messages/{msgId}                    # Activity feed
│   ├── expense_revisions/{id}                     # Edit tracking
│   └── deleted_expenses/{id}                      # Soft-delete markers
```

---

## 1. USERS Table

**Collection:** `users/{uid}`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `uid` (doc ID) | STRING | NO | Firebase Auth UID (primary key) |
| `displayName` | STRING | YES | User's display name |
| `phoneNumber` | STRING | YES | Phone number (e.g. "+919876543210") |
| `photoURL` | STRING | YES | Firebase Storage URL for profile photo |
| `upiId` | STRING | YES | UPI ID for payments |

### Screens that write to USERS:

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **PhoneAuth** | CREATE/UPDATE | `phoneNumber` |
| **OnboardingName** | UPDATE | `displayName` |
| **Profile** | UPDATE | `displayName`, `photoURL`, `upiId` |

---

## 2. GROUPS Table

**Collection:** `groups/{groupId}`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `groupId` (doc ID) | STRING | NO | e.g. "g_1708901234567" |
| `groupName` | STRING | NO | Display name of the group |
| `creatorId` | STRING | NO | Firebase UID of creator |
| `members` | ARRAY\<STRING\> | NO | List of Firebase UIDs |
| `pendingMembers` | ARRAY\<MAP\> | YES | `[{phone, name}, ...]` |
| `pendingPhones` | ARRAY\<STRING\> | YES | Normalized phone numbers (for querying) |
| `activeCycleId` | STRING | NO | e.g. "c_1708901234567" |
| `cycleStatus` | STRING | NO | "active", "settling", or "closed" |
| `settlementRhythm` | STRING | YES | "weekly", "biweekly", "monthly", "none" |
| `settlementDay` | INTEGER | YES | Day of week (1-7) or month (1-31) |

### Screens that write to GROUPS:

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **CreateGroup** | CREATE | `groupName`, `creatorId`, `members`, `activeCycleId`, `cycleStatus`, `settlementRhythm`, `settlementDay` |
| **InviteMembers** | UPDATE | `pendingMembers`, `pendingPhones` |
| **GroupsList** | UPDATE | `members`, `pendingMembers`, `pendingPhones` (on accept/decline) |
| **GroupsList** | DELETE | Entire group document (creator only) |
| **MemberChange** | UPDATE | `members` or `pendingMembers`, `pendingPhones` |
| **SettlementConfirmation** | UPDATE | `cycleStatus` → "settling" |
| **GroupDetail** | UPDATE | `cycleStatus`, `activeCycleId` (on cycle restart) |

---

## 3. EXPENSES Table

**Collection:** `groups/{groupId}/expenses/{expenseId}`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` (doc ID) | STRING | NO | Timestamp-based ID |
| `groupId` | STRING | NO | Parent group ID |
| `description` | STRING | NO | What the expense was for |
| `amount` | DOUBLE | NO | Total amount (e.g. 150.50) |
| `payerId` | STRING | NO | Firebase UID of who paid |
| `participantIds` | ARRAY\<STRING\> | NO | UIDs of who is involved |
| `splitType` | STRING | NO | "Even", "Exact", "Exclude", "Percentage" |
| `splits` | MAP\<STRING, DOUBLE\> | YES | `{memberId: amount}` for unequal splits |
| `category` | STRING | YES | Category tag |
| `date` | STRING | NO | Display date ("Today", "Feb 20", etc.) |
| `dateSortKey` | INTEGER | NO | Unix timestamp for sorting |

### Screens that write to EXPENSES:

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **ExpenseInput** | CREATE | All fields |
| **GroupDetail** (Magic Bar) | CREATE | All fields (via NormalizedExpense) |
| **EditExpense** | UPDATE | Any field except `id`, `groupId` |
| **EditExpense** | DELETE | Entire document (soft or hard) |
| **UndoExpense** | DELETE | Entire document (hard delete within undo window) |

---

## 4. SETTLED_CYCLES Table

**Collection:** `groups/{groupId}/settled_cycles/{cycleId}`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `cycleId` (doc ID) | STRING | NO | e.g. "c_1708901234567" |
| `startDate` | STRING | NO | Cycle start date |
| `endDate` | STRING | NO | Cycle end date |

### Screens that write to SETTLED_CYCLES:

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **GroupDetail** | CREATE | `startDate`, `endDate` (on cycle archive) |

---

## 5. SETTLED_CYCLE_EXPENSES Table

**Collection:** `groups/{groupId}/settled_cycles/{cycleId}/expenses/{expenseId}`

*Same schema as EXPENSES table — expenses are copied here when archived.*

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **GroupDetail** | CREATE | All expense fields (copied from active cycle) |

---

## 6. SYSTEM_MESSAGES Table

**Collection:** `groups/{groupId}/system_messages/{msgId}`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` (doc ID) | STRING | NO | e.g. "sys_1708901234567" |
| `type` | STRING | NO | "joined", "declined", "left", "created" |
| `userId` | STRING | YES | Firebase UID (if applicable) |
| `userName` | STRING | NO | Display name for message |
| `timestamp` | INTEGER | NO | Unix timestamp in milliseconds |

### Screens that write to SYSTEM_MESSAGES:

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **GroupsList** | CREATE | `type`="joined" or "declined", `userName`, `userId`, `timestamp` |
| **MemberChange** | CREATE | `type`="left", `userName`, `userId`, `timestamp` |

---

## 7. EXPENSE_REVISIONS Table

**Collection:** `groups/{groupId}/expense_revisions/{id}`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` (doc ID) | STRING | NO | Same as new expense ID |
| `expenseId` | STRING | NO | The new expense ID |
| `replacesExpenseId` | STRING | YES | Previous expense ID (if edit) |
| `createdAt` | TIMESTAMP | NO | Server timestamp |

### Screens that write to EXPENSE_REVISIONS:

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **EditExpense** | CREATE | `expenseId`, `replacesExpenseId`, `createdAt` |

---

## 8. DELETED_EXPENSES Table

**Collection:** `groups/{groupId}/deleted_expenses/{id}`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` (doc ID) | STRING | NO | Expense ID that was deleted |
| `deletedAt` | TIMESTAMP | NO | Server timestamp |

### Screens that write to DELETED_EXPENSES:

| Screen | Operation | Fields Written |
|--------|-----------|----------------|
| **EditExpense** | CREATE | `deletedAt` (soft delete) |

---

## Screen-to-Database Summary

| Screen | Database Operations |
|--------|---------------------|
| **PhoneAuth** | `users` → CREATE/UPDATE |
| **OnboardingName** | `users` → UPDATE |
| **Profile** | `users` → UPDATE |
| **CreateGroup** | `groups` → CREATE |
| **InviteMembers** | `groups` → UPDATE (pendingMembers) |
| **GroupsList** | `groups` → UPDATE (accept/decline), DELETE |
| **GroupDetail** | `expenses` → CREATE, `settled_cycles` → CREATE, `groups` → UPDATE |
| **ExpenseInput** | `expenses` → CREATE |
| **EditExpense** | `expenses` → UPDATE/DELETE, `expense_revisions` → CREATE, `deleted_expenses` → CREATE |
| **UndoExpense** | `expenses` → DELETE (hard) |
| **MemberChange** | `groups` → UPDATE, `system_messages` → CREATE |
| **SettlementConfirmation** | `groups` → UPDATE (cycleStatus) |
| **CycleHistory** | READ ONLY |
| **CycleHistoryDetail** | READ ONLY |
| **CycleSettled** | UI ONLY |
| **GroupMembers** | READ ONLY |
| **PaymentResult** | READ ONLY |
| **SplashScreen** | READ ONLY |
| **EmptyStates** | UI ONLY |
| **ErrorStates** | UI ONLY |

---

## Data Flow Diagrams

### Creating an Expense

```
ExpenseInput / GroupDetail (Magic Bar)
        │
        ▼
┌─────────────────────────────────────────┐
│  groups/{groupId}/expenses/{expenseId}  │
├─────────────────────────────────────────┤
│  id: "1708901234567"                    │
│  groupId: "g_1708901234567"             │
│  description: "Lunch"                   │
│  amount: 450.00                         │
│  payerId: "uid_abc123"                  │
│  participantIds: ["uid_abc", "uid_xyz"] │
│  splitType: "Even"                      │
│  splits: null                           │
│  category: "Food"                       │
│  date: "Today"                          │
│  dateSortKey: 1708901234567             │
└─────────────────────────────────────────┘
```

### Creating a Group

```
CreateGroup Screen
        │
        ▼
┌─────────────────────────────────────────┐
│  groups/{groupId}                       │
├─────────────────────────────────────────┤
│  groupName: "Roommates"                 │
│  creatorId: "uid_abc123"                │
│  members: ["uid_abc123"]                │
│  pendingMembers: []                     │
│  pendingPhones: []                      │
│  activeCycleId: "c_1708901234567"       │
│  cycleStatus: "active"                  │
│  settlementRhythm: "monthly"            │
│  settlementDay: 1                       │
└─────────────────────────────────────────┘
```

### Inviting a Member

```
InviteMembers Screen
        │
        ▼
┌─────────────────────────────────────────┐
│  groups/{groupId}                       │
├─────────────────────────────────────────┤
│  pendingMembers: [                      │
│    { phone: "+919876543210",            │
│      name: "Alice" }                    │
│  ]                                      │
│  pendingPhones: ["9876543210"]          │
└─────────────────────────────────────────┘
```

### Settling a Cycle

```
SettlementConfirmation → GroupDetail
        │
        ├──► groups/{groupId}
        │    └── cycleStatus: "settling" → "active"
        │    └── activeCycleId: "c_NEW"
        │
        └──► groups/{groupId}/settled_cycles/{oldCycleId}
             ├── startDate: "Feb 1, 2024"
             ├── endDate: "Feb 23, 2024"
             └── /expenses/{id}... (copied from current cycle)
```

---

## Encryption Note

All sensitive fields may be encrypted using `DataEncryptionService` before storage:
- **User data:** `displayName`, `phoneNumber`, `photoURL`, `upiId`
- **Group data:** `pendingMembers`, `groupName`
- **Expense data:** `description`, `amount`, `splits`

The encryption is transparent to the application layer — data is encrypted on write and decrypted on read.
