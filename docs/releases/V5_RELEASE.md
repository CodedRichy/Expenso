# Expenso V5 Release Document

**Lead Product Engineering · V5 Planning & Polish**
Expenso is currently at **V5**. This document defines the V5 release boundary, which covers the animation polish pass and additional polish items shipped alongside it: skeleton refinement, splash cross-fade, invite link, and UPI flow cleanup.

---

## 1. Relationship to V4

- **V1, V2, V3, and V4 contracts are unchanged**: All core logic, backend synchronization, magic bar parsing, UI structures, and settlement engines remain intact.
- **V5 adds** a strict animation and micro-interaction layer over the existing UI and ships several polish/correctness items that complete the pre-release audit.

---

## 2. V5 Theme: "Tactile & Premium Polish"

V5 is primarily dedicated to the **Animation Polish Pass**, with bundled polish items that complete the pre-release audit and production-readiness assessment.

**Core thesis:** A finance and utility app should feel trustworthy and snappy. Micro-animations confirm user actions instantly without slowing them down. Every remaining UI gap (skeleton mismatches, jarring splash, ambiguous UPI flow) blocks the app from feeling production-grade.

---

## 3. V5 In-Scope Features & Refinements

### 3.1 Animation Polish Pass

| Area | Description | Priority |
|------|-------------|----------|
| **Tactile Interaction Feedback** | Wrapped all primary buttons, list items, and navigation icons with `TapScale` to provide a physical "press" feeling. | P0 |
| **List Entry Cascading** | Applied `StaggeredListItem` to all major lists (Groups, Members, Expenses, Cycle History) to prevent UI popping and guide the eye organically. | P0 |
| **Graceful Entry Transitions** | Implemented `FadeIn` on onboarding headers and empty states. | P1 |
| **Performance Maintenance** | Kept all animation durations strictly under 220–300ms using layer-backed Flutter animations to maintain 60fps performance without jank. | P0 |

### 3.2 Skeleton Screen Audit & Fix

All skeleton screens now structurally match their corresponding final screens:

- `_BoundedGroupsLoading` — matches `GroupsList` SafeArea, header dimensions, and row heights exactly.
- `GroupListSkeleton` — shimmer row heights, padding, and member-count indicators match final layout.
- `SkeletonExpenseRow` — matches final expense row height, padding, and avatar position.

**Forbidden zones enforced:** Skeletons are not used between routes, after errors, or when `loading == false`.

### 3.3 Splash → Home Cross-fade

Splash screen remains static (no scaling, no bounce). Home screen fades in over ≤ 200ms using a clean cross-fade navigator transition. No visual interruption or layout shift between splash and first content screen.

### 3.4 Invite via Link

- Creator generates invite link: `expenso://join/<groupId>` from InviteMembers screen.
- Link is copied to clipboard; creator shares via any channel.
- Multi-use token (groupId acts as implicit token); revocation via token rotation not implemented — group deletion achieves equivalent effect.
- Deep linking: Android intent filter and iOS URL scheme already configured for `expenso://` scheme.

### 3.5 UPI Intent Flow Removal

The unreliable UPI intent path (direct app-to-app payment via `flutter_upi` intents with ambiguous return codes) has been removed. Only the following remain:

| Method | Description |
|--------|-------------|
| **UPI App Picker** | `upi_india` package — shows installed apps (GPay, PhonePe, Paytm, etc.), launches transaction, handles result with Zomato-style waiting overlay. |
| **Show QR** | `qr_flutter` — generates scannable QR pre-filled with payee UPI ID and amount. |
| **Copy UPI ID** | One-tap copy of payee UPI ID to clipboard. |
| **Mark as paid / Paid via cash** | Manual confirmation without app launch. |

UPI intent-specific UI elements, error messages for "bank limit exceeded", and the old `UpiIntentService` are removed.

---

## 4. Implementation Details

### Animation Widgets

1. **`TapScale` Widget:**
   - Applied to structural navigation (back buttons).
   - Applied to core action buttons ("Submit", "Confirm", "Create Group").
   - Applied to interactive user elements (Profile Avatars, Choice Chips).

2. **`StaggeredListItem` Widget:**
   - Used in `CycleHistoryDetail`, `GroupMembers`, and `CycleHistory` screens to animate list items sequentially.

3. **`FadeIn` Widget:**
   - Used for structural empty states and onboarding copy, providing a smooth fade rather than an abrupt load.

By avoiding external dependencies, V5 maintains the app's lightweight profile and ensures full control over animation curves and timing.

---

## 5. Quality Bar (V5)

- Animations never block user interaction (no unskippable long transitions).
- Zero performance regressions on lower-end hardware (driven entirely by Flutter's animation engine).
- Consistent scale-down parameters across all back buttons for uniformity.
- All skeleton screens structurally match their final screens — no layout shifts on load.
- Splash-to-home transition completes in ≤ 200ms with no visual jarring.
- UPI payment flow unambiguous — no PSP-rejection edge cases from intent path.

---

## Document Control

- **Version:** 5.1
- **Status:** V5 Implemented (current release)
- **Audience:** Product and Engineering
- **Prerequisite:** [V4_RELEASE.md](V4_RELEASE.md)
