# Expenso V3 Release Document

**Lead Product Engineering · V3 Current State**  
Expenso is currently at **V3**. This document is the single source of truth for the V3 release: what is in scope (building on V2), what defines "V3," and what is deferred to V4. It builds on [V2_RELEASE.md](V2_RELEASE.md) and [V1_RELEASE.md](V1_RELEASE.md), which remain the base contracts.

---

## 1. Relationship to V2

- **V1 and V2 contracts are unchanged** for: Magic Bar, Decision Clarity, Creator Crown, SettlementEngine, profile pictures, UPI deep-linking, and push notifications.
- **V3 adds** the capabilities listed below. Nothing in V3 removes or weakens V1/V2 guarantees unless explicitly stated here.

---

## 2. V3 In-Scope

| Area | Description | Status |
|------|-------------|--------|
| **Logout** | Profile screen includes a Log out button with confirmation dialog. Clears auth state and returns user to login. | V3 |
| **International country codes** | InviteMembers supports 15 country codes (IN, US, UK, UAE, SG, AU, DE, FR, JP, CN, KR, BR, MX, RU, ZA) via a dropdown picker. Phone storage format updated to support international numbers. | V3 |
| **Human-friendly dates** | Expense model includes `displayDate` getter that shows "Today", "Yesterday", "3 days ago", "Feb 15", or "Feb 15, 2025" based on expense date relative to now. | V3 |
| **Instant avatar rendering** | MemberAvatar shows letter fallback immediately; photo loads as an upgrade layer via CachedNetworkImage with fade transition. Zero visible waiting for avatars. | V3 |
| **Local profile cache** | User profile (name, photoURL, upiId) is persisted to SharedPreferences via `UserProfileCache`. On cold start, profile is loaded from cache **before** Firebase resolves, enabling instant avatar rendering even on slow networks. Cache syncs with Firestore updates and clears on logout. | V3 |
| **Bounded loading states** | Loading indicators are time-bounded (6–8s). After timeout, UI shows slow-loading hint with retry option instead of spinning indefinitely. Applied to groups list and cycle history. | V3 |
| **Explicit error handling** | Error messages are human-readable and calm. All error screens have back buttons. Network failures show clear feedback ("Check your connection") without erasing existing data. | V3 |
| **Settlement activity feed** | Read-only activity feed for settlement events. Shows in both GroupDetail (when settling) and SettlementConfirmation screens. Event types: payment initiated/pending/confirmed/failed, cash confirmation requested/confirmed, cycle settled/archived. Neutral system voice, no names, no chat, no reactions. Events stored in Firestore `settlement_events` subcollection. | V3 |
| **Settlement progress indicator** | "X of Y payments settled" with subtle progress bar in GroupDetail. Shows only when cycle is in settling mode. Updates in real-time based on payment attempt states. | V3 |
| **Auto-detect full settlement** | When all payment routes are confirmed, system emits "Cycle fully settled" event. Button turns green and shows "Start New Cycle ✓" for creator. No manual checking required. | V3 |
| **Cash payment flow** | Payer can mark a settlement route as "Paid via cash" (creates `CASH_CONFIRMATION_REQUESTED` event). Receiver sees "Confirm cash received" button. On confirmation, route is settled and `CASH_CONFIRMED` event is emitted. No edits allowed after confirmation. Both actions logged as system events. | V3 |
| **Passive social pressure** | Settlement progress shows "X of Y members settled" with "N pending" badge. In settlement details, members who owe and haven't paid show "Pending" badge (no names in public view). Daily system activity "X members still pending settlement" is emitted once per day when in settling mode. No direct reminders, no push notifications—UI only. | V3 |
| **Skeleton placeholders** | Loading states use skeleton placeholders (shimmering cards) instead of spinners. Applied to groups list and settlement confirmation. Perceived performance improvement—content shape visible immediately. | V3 |
| **Offline resilience** | `ConnectivityService` detects online/offline status. Offline banner ("Offline — showing last known state") appears at top of screens when disconnected. Destructive actions (delete group, confirm payment) are blocked with clear feedback. Read-only browsing of cached data remains available. | V3 |
| **Dynamic UPI QR** | Payment cards show "Show QR" toggle alongside UPI app picker. Generates scannable QR code with amount pre-filled. Works with all UPI apps (GPay, PhonePe, Paytm, BHIM, etc.). QR displays amount prominently and includes helper text. | V3 |

---

## 3. Quality Bar (V3)

- All V1 and V2 micro-interactions and stability guarantees remain.
- Logout requires confirmation to prevent accidental sign-out.
- Country code picker defaults to India (+91) for backward compatibility.
- Date display is purely cosmetic; underlying storage format unchanged.
- **Avatar UX:** Letter placeholder renders instantly; no loaders or empty circles ever shown. PhotoURL is available from local cache on cold start (before Firestore responds).
- **Loading resilience:** No unbounded spinners; UI degrades gracefully after timeout with retry option.
- **Error UX:** Errors surface clear feedback, never silently fail, and never erase existing screen data.

---

## 4. V4 / "Not Now" for V3

The following stay out of the V3 release boundary:

| Item | Notes |
|------|--------|
| **Multi-currency** | V3 keeps single-currency (INR) semantics. Country codes are for phone numbers only. |
| **Rich social identity** | Beyond profile pictures (e.g. bios, status). |
| **Engagement mechanics** | Gamification, streaks, or retention hooks. |
| **Receipt attachments** | Photo attachments for expenses. |

No V3 behavior or UI should depend on these.

---

## Document Control

- **Version:** 1.0  
- **Status:** V3 Current State (current release)  
- **Audience:** Product, Engineering, and anyone defining or implementing Expenso.  
- **Prerequisite:** [V2_RELEASE.md](V2_RELEASE.md), [V1_RELEASE.md](V1_RELEASE.md)  
- **Updates:** Changes to this document should be versioned; they define the V3 boundary.
