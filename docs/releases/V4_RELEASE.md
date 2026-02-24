# Expenso V4 Release Document

**Lead Product Engineering · V4 Planning**  
Expenso is currently at **V3**. This document defines the V4 release boundary: what is in scope, dependencies, and what is deferred to V5. It builds on [V3_RELEASE.md](V3_RELEASE.md), [V2_RELEASE.md](V2_RELEASE.md), and [V1_RELEASE.md](V1_RELEASE.md), which remain the base contracts.

---

## 1. Relationship to V3

- **V1, V2, and V3 contracts are unchanged** for: Magic Bar, Decision Clarity, Creator Crown, SettlementEngine, profile pictures, UPI deep-linking, push notifications foundation, instant avatar rendering, local profile cache, bounded loading states, settlement activity feed, settlement progress indicator, cash payment flow, passive social pressure, skeleton placeholders, offline resilience, and Dynamic UPI QR.
- **V4 adds** the capabilities listed below. Nothing in V4 removes or weakens V1/V2/V3 guarantees unless explicitly stated here.

---

## 2. V4 Theme: "God Mode Foundation"

V4 establishes the infrastructure for cross-group intelligence and the signature "God Mode" debt minimization feature. All V4 features are **free tier** — no monetization gates.

**Core thesis:** Users with the same contacts across multiple groups should see unified balances and optimized payment paths. This is Expenso's differentiator.

---

## 3. V4 In-Scope

| Area | Description | Priority | Dependencies | Status |
|------|-------------|----------|--------------|--------|
| **Cross-group identity** | Unify member identity across groups using phone number as canonical ID. Ashe person in Group A and Group B resolves to one identity. Used for unified display names. | P0 | None | ✅ Implemented |
| **Global balance view** | ~~New screen showing net balance with each contact across all groups.~~ | P0 | Cross-group identity | ❌ Removed — violates group-centric philosophy |
| **Debt minimization ("God Mode")** | ~~Optimize payment paths across groups.~~ | P1 | Cross-group identity | ❌ Removed — violates group-centric philosophy |
| **Cloud sync status** | Track sync state (synced/syncing/offline/error) for UI feedback. | P1 | None | ✅ Implemented (SyncStatusService) |
| **Push notification infrastructure** | Add `firebase_messaging` to pubspec. Register FCM tokens. Store tokens in Firestore per user. No notification logic yet — just the plumbing. | P2 | None | ✅ Implemented (FcmTokenService) |

---

## 4. Feature Specifications

### 4.1 Cross-Group Identity

**Problem:** Currently, members are stored per-group with phone as identifier, but there's no unified view. "Ash" in Group A and "Ash Jones" in Group B with the same phone are treated as separate entities in the UI.

**Solution:**

1. **Canonical identity:** Phone number (E.164 format) is the unique identifier across groups.
2. **Identity resolution service:** New `IdentityService` that:
   - Maintains a local cache of phone → display name mappings
   - Prefers the most recently updated name for display
   - Merges profile data (photo URL, UPI ID) across groups
3. **Data model:**
   ```
   /users/{phoneE164}/
     displayName: String
     photoURL: String?
     upiId: String?
     lastUpdated: Timestamp
     groups: [groupId, ...]
   ```
4. **Migration:** On app start, scan all groups the user is part of, extract member phones, and build the identity map.

**Constraints:**
- No breaking changes to existing group/member storage
- Phone remains the key; no new "user accounts" for non-app users
- Works offline with cached data

**UI impact:**
- Member names become consistent across groups
- Profile photos sync across groups (if available)

---

### 4.2 Global Balance View

**Problem:** Users don't know their total financial position with a contact. They have to mentally sum across groups.

**Solution:**

1. **New screen:** "Balances" tab or accessible from profile
2. **Data structure:**
   ```dart
   class GlobalBalance {
     final String contactPhone;
     final String contactName;
     final int netBalanceMinor; // positive = they owe you
     final List<GroupContribution> breakdown;
   }
   
   class GroupContribution {
     final String groupId;
     final String groupName;
     final int balanceMinor;
   }
   ```
3. **Computation:**
   - For each group, compute net balance using existing `SettlementEngine`
   - Aggregate by contact phone across groups
   - Sort by absolute balance (largest first)

**UI:**
- List of contacts with net balance
- Tap to expand: see per-group breakdown
- Color coding: green (they owe you), red (you owe them)
- "Settle" CTA links to God Mode suggestion or manual payment

**Constraints:**
- Read-only initially (no direct actions)
- Computed on-demand, not stored
- Respects offline mode (uses cached group data)

---

### 4.3 Debt Minimization ("God Mode")

**Problem:** Without optimization, users make redundant payments. A owes B ₹500, B owes C ₹500 = 2 transactions. With optimization: A pays C ₹500 = 1 transaction.

**Solution:**

1. **Algorithm:** Extend `SettlementEngine` with `computeOptimizedRoutes`:
   ```dart
   static List<PaymentRoute> computeOptimizedRoutes(
     Map<String, int> globalNetBalances,
     String currencyCode,
   )
   ```
   - Input: Global net balances (aggregated across all groups)
   - Output: Minimum set of payments to settle all debts
   - Ashe greedy algorithm as per-group, but applied to global balances

2. **UI flow:**
   - User opens Global Balance view
   - Sees "Optimize payments" CTA
   - Shows comparison: "Current: 5 payments → Optimized: 2 payments"
   - User can accept suggestion or dismiss
   - Accepting shows payment instructions (UPI, QR, cash options)

3. **Constraints:**
   - **Suggestion only** — no automatic settlement
   - **Opt-in** — user explicitly triggers optimization
   - **No cross-group settlement records** — optimization is a UI convenience; actual settlements still happen per-group
   - **Reversible** — dismissing returns to normal view

**Edge cases:**
- User not in all groups (can only optimize groups they're in)
- Pending payments in some groups (exclude from optimization)
- Settling groups mid-optimization (recalculate)

---

### 4.4 Cloud Backup & Sync

**Problem:** Users expect data to persist across devices and reinstalls. Data is in Firestore, but there's no explicit "backup" concept or cross-device awareness.

**Solution:**

1. **Backup is implicit:** Data already in Firestore is the backup. This feature adds:
   - **Backup status indicator:** "Last synced: 2 min ago"
   - **Manual sync button:** Force refresh from Firestore
   - **Offline indicator:** Shows when operating on cached data
   - **Conflict resolution:** Last-write-wins for simple fields

2. **Cross-device awareness:**
   - On login, pull all groups where user is a member
   - Merge local pending changes if any
   - Show "Syncing..." indicator during initial load

3. **Export (optional, lower priority):**
   - Export group data as JSON for personal backup
   - No import (too complex for V4)

**Constraints:**
- No new backend infrastructure
- Leverages existing Firestore real-time listeners
- Offline-first: local changes queue and sync when online

---

### 4.5 Push Notification Infrastructure

**Problem:** V2 mentions push notifications but no FCM infrastructure exists.

**Solution:**

1. **Add dependencies:**
   ```yaml
   firebase_messaging: ^15.0.0
   flutter_local_notifications: ^18.0.0
   ```

2. **Token management:**
   - On app start, request notification permission
   - Get FCM token
   - Store in Firestore: `/users/{uid}/fcmTokens/{tokenId}`
   - Refresh token on change

3. **No notification logic in V4:**
   - V4 only adds plumbing
   - Actual notifications (join, expense added, settlement reminder) are V5

**Constraints:**
- Permission request is non-blocking (user can decline)
- Works without notifications (graceful degradation)
- Token storage is fire-and-forget (no blocking on success)

---

## 5. Implementation Order

```
Phase 1: Foundation
├── 1.1 Cross-group identity service
├── 1.2 Identity migration on app start
└── 1.3 Update member display to use unified identity

Phase 2: Global View
├── 2.1 Global balance computation
├── 2.2 Global balance screen UI
└── 2.3 Per-contact breakdown

Phase 3: God Mode
├── 3.1 computeOptimizedRoutes algorithm
├── 3.2 Optimization suggestion UI
└── 3.3 Payment flow integration

Phase 4: Infrastructure
├── 4.1 Cloud sync status indicator
├── 4.2 Manual sync button
├── 4.3 FCM token registration
└── 4.4 Notification permission flow
```

---

## 6. Quality Bar (V4)

- All V1, V2, and V3 guarantees remain.
- **Cross-group identity:**
  - Phone matching is exact (E.164 normalized)
  - Name conflicts resolved by most-recent-update
  - No data loss during identity merge
- **Global balance:**
  - Math is consistent with per-group balances (same engine)
  - Breakdown sums to total (no rounding errors)
  - Works offline with cached data
- **God Mode:**
  - Optimization is always correct (fewer or equal transactions)
  - User explicitly accepts suggestions
  - No automatic settlements
- **Cloud sync:**
  - Never lose data
  - Offline changes sync when online
  - Clear status indicators

---

## 7. V5 / "Not Now" for V4

The following stay out of the V4 release boundary:

| Item | Notes |
|------|--------|
| **Push notification logic** | V4 adds FCM infrastructure only. Actual notifications are V5. |
| **Real-time join notifications** | "X invited you to a group" push. Needs FCM + backend trigger. V5. |
| **Live activity feed** | "Ash added Dinner" real-time updates with push. V5. |
| **Multi-currency** | V4 keeps single-currency (INR) semantics. |
| **Receipt attachments** | Photo attachments for expenses. Plus feature, not V4. |
| **Monetization features** | Smart reminders, export, etc. Not V4. |
| **Cross-group settlement records** | Optimization is UI-only; actual settlements remain per-group. |

No V4 behavior or UI should depend on these.

---

## 8. Data Model Changes

### 8.1 New: Global Identity Cache

Location: Local (SharedPreferences or Hive)

```dart
class GlobalIdentity {
  final String phoneE164;
  final String displayName;
  final String? photoURL;
  final String? upiId;
  final List<String> groupIds;
  final int lastUpdated;
}
```

### 8.2 New: FCM Token Storage

Location: Firestore `/users/{uid}/fcmTokens/{tokenId}`

```json
{
  "token": "fcm_token_string",
  "platform": "android|ios",
  "createdAt": 1234567890,
  "lastRefresh": 1234567890
}
```

### 8.3 No Changes

- Group structure unchanged
- Member structure unchanged
- Expense structure unchanged
- PaymentAttempt structure unchanged
- SettlementEvent structure unchanged

---

## 9. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Identity merge conflicts | Medium | Low | Last-write-wins, user can edit |
| Optimization suggests wrong amount | Low | High | Ashe engine as per-group; extensive testing |
| FCM permission denied | High | Low | Graceful degradation; app works without push |
| Performance with many groups | Low | Medium | Lazy loading, pagination |
| Offline data staleness | Medium | Low | Clear "last synced" indicator |

---

## 10. Success Metrics

| Metric | Target |
|--------|--------|
| Global balance load time | < 500ms for 10 groups |
| Optimization accuracy | 100% (same or fewer transactions) |
| FCM token registration rate | > 80% of users |
| Cross-group identity match rate | > 95% (same phone = same person) |

---

## Document Control

- **Version:** 1.1  
- **Status:** V4 Implemented (current release)  
- **Audience:** Product, Engineering, and anyone defining or implementing Expenso.  
- **Prerequisite:** [V3_RELEASE.md](V3_RELEASE.md), [V2_RELEASE.md](V2_RELEASE.md), [V1_RELEASE.md](V1_RELEASE.md)  
- **Updates:** Changes to this document should be versioned; they define the V4 boundary.
