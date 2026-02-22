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

## Setting the master key

Set `DATA_ENCRYPTION_MASTER_KEY` in Firebase Functions (env config or Secret Manager). The key must be **32 bytes**. Supported formats:

- **64 hex characters** — e.g. `9f3c7a1d8b4e2f0c6a5d91e7b2c8f403a6e94d5b0f1c2873e9a4b6d2c5f8e01` (exactly 64 hex digits). The Cloud Function decodes this to 32 bytes and uses it for key derivation.
- **UTF-8 string** — any other value is used as a raw UTF-8 key (e.g. base64 string). Prefer hex for a true 32-byte binary key.

Do not commit the key to the repo; set it only in Firebase config or secrets.
