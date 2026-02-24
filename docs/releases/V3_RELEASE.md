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

---

## 3. Quality Bar (V3)

- All V1 and V2 micro-interactions and stability guarantees remain.
- Logout requires confirmation to prevent accidental sign-out.
- Country code picker defaults to India (+91) for backward compatibility.
- Date display is purely cosmetic; underlying storage format unchanged.

---

## 4. V4 / "Not Now" for V3

The following stay out of the V3 release boundary:

| Item | Notes |
|------|--------|
| **Multi-currency** | V3 keeps single-currency (INR) semantics. Country codes are for phone numbers only. |
| **Rich social identity** | Beyond profile pictures (e.g. bios, status). |
| **Engagement mechanics** | Gamification, streaks, or retention hooks. |
| **Receipt attachments** | Photo attachments for expenses. |
| **Dynamic UPI QR** | QR code generation for settlement. |

No V3 behavior or UI should depend on these.

---

## Document Control

- **Version:** 1.0  
- **Status:** V3 Current State (current release)  
- **Audience:** Product, Engineering, and anyone defining or implementing Expenso.  
- **Prerequisite:** [V2_RELEASE.md](V2_RELEASE.md), [V1_RELEASE.md](V1_RELEASE.md)  
- **Updates:** Changes to this document should be versioned; they define the V3 boundary.
