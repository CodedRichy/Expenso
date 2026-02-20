# Data encryption — where it’s used

Application-level encryption is **used throughout the project**. This note records coverage and the one intentional gap.

## Single choke point

- **All Firestore access goes through `FirestoreService`.** There is no direct `FirebaseFirestore.instance` usage outside `lib/services/firestore_service.dart`.
- When `DataEncryptionService` is set (after auth), `FirestoreService` encrypts before write and decrypts after read for every method that touches sensitive fields.

## Coverage

| Path | Encrypted |
|------|-----------|
| **Users** | `setUser`, `getUser`, `userStream` — displayName, phoneNumber, photoURL, upiId |
| **Groups** | `updateGroup`, `addPendingMemberToGroup`, `removePendingMemberFromGroup` — groupName, pendingMembers. `groupsStream` — decrypt on read |
| **Expenses** | `addExpense`, `updateExpense`, `expensesStream` — description, amount, date, splits, participantIds, category, etc. |
| **Settled cycles** | `getSettledCycleExpenses` — decrypt expense data. Meta (`startDate`, `endDate`) is plaintext for `orderBy` |
| **Archive** | `archiveCycleExpenses` copies current-cycle expense docs as-is (already encrypted) |

## Intentional gap

- **`createGroup`** — The initial group document is written in plaintext because the group key is only available after the group exists (it’s derived from `groupId`). The first update (e.g. add pending member or change name) is encrypted. So the first write is briefly plaintext; all later reads/writes for that group use encryption.

## Callers

All Firestore usage is from `CycleRepository` calling `FirestoreService.instance.*`. No other file touches Firestore. Encryption is enabled in `CycleRepository.continueAuthFromFirebaseUser()` and cleared in `clearAuth()`.
