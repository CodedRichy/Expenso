# Expenso V2 Release Document

**Lead Product Engineering · V2 Scope**  
This document defines the V2 release boundary for Expenso: what is in scope after V1, what behaviors and features define “V2,” and what remains deferred. It builds on the [V1 Release contract](V1_RELEASE.md), which remains the base for Magic Bar, Decision Clarity, Authority, and the SettlementEngine.

---

## 1. Relationship to V1

- **V1 contract is unchanged** for: Magic Bar (NLP contract, Sacred Amount, no crash), Decision Clarity card, Creator Crown and destructive-action permissions, SettlementEngine math and minimum-debt path, and the V1 quality bar (haptics, layout stability).
- **V2 adds** the capabilities listed below. Nothing in V2 removes or weakens V1 guarantees unless explicitly stated here.

---

## 2. V2 In-Scope

| Area | Description | Status |
|------|-------------|--------|
| **Profile pictures** | User avatars or photos (e.g. in group members, Decision Clarity, settlement). Identity remains name/phone; avatars are an optional visual layer. | Planned |
| **UPI deep-linking** | From settlement instructions, open UPI apps with pre-filled payee and amount so users can pay in one tap. | Planned |
| **Push notifications** | Optional reminders, “X added an expense,” or settlement nudges. Must be opt-in and respect user preferences. | Planned |

These were on the V1 “Not Now” list and are now part of the V2 scope. Implementation details (e.g. storage for profile pictures, notification triggers) belong in APP_BLUEPRINT or design docs and should be updated when built.

---

## 3. Settlement and Data Consistency (V2)

V2 reinforces a **single code path** for balances and settlement:

- **SettlementEngine** is the only source for net balances and debt list in the UI (Decision Clarity, Balances).
- **CycleRepository** settlement APIs (e.g. `getSettlementInstructions`, `getSettlementTransfersForCurrentUser`) must use the same logic as the engine (or call the engine) so that group detail and settlement dialogs always agree.
- **Participant and payer resolution:** UID→phone must use a consistent strategy (e.g. `_membersById` then `_userCache`) so that no participant or payer is dropped when building `participantPhones` / `paidByPhone`. No defaulting of missing payer to current user.

Documentation that describes where and why settlement can be inconsistent: [SETTLEMENT_WHERE_AND_WHY.md](SETTLEMENT_WHERE_AND_WHY.md). V2 aims to eliminate those inconsistencies.

---

## 4. Quality Bar (V2)

- All V1 micro-interactions and stability guarantees remain.
- New V2 features (profile pictures, UPI deep-linking, push) must not reduce reliability or clarity: no mandatory profile photo, deep-links must have a clear fallback (e.g. copy instructions), notifications must be dismissible and non-intrusive.

---

## 5. V3 / “Not Now” for V2

The following stay out of the V2 release boundary:

| Item | Notes |
|------|--------|
| **Rich social identity** | Beyond profile pictures (e.g. bios, status). |
| **Engagement mechanics** | Gamification, streaks, or retention hooks. |
| **Multi-currency** | V2 keeps single-currency (INR) semantics. |

No V2 behavior or UI should depend on these.

---

## Document Control

- **Version:** 1.0  
- **Status:** V2 Scope  
- **Audience:** Product, Engineering, and anyone defining or implementing “Expenso V2.”  
- **Prerequisite:** [V1_RELEASE.md](V1_RELEASE.md)  
- **Updates:** Changes to this document should be versioned; new in-scope items or behavior changes define the V2 boundary.
