# Expenso V5 Release Document

**Lead Product Engineering · V5 Planning & Polish**
Expenso is currently at **V5**. This document defines the V5 release boundary, which focuses on a comprehensive animation polish pass, enhancing the tactile feel and visual premium quality of the app, and standardizing micro-interactions across all user flows without introducing new dependencies.

---

## 1. Relationship to V4

- **V1, V2, V3, and V4 contracts are unchanged**: All core logic, backend synchronization, magic bar parsing, UI structures, and settlement engines remain intact.
- **V5 adds** a strict animation and micro-interaction layer over the existing UI to make Expenso feel responsive, alive, and premium.

---

## 2. V5 Theme: "Tactile & Premium Polish"

V5 is primarily dedicated to the **Animation Polish Pass**. We wanted Expenso to not only function flawlessly but feel satisfying to use. Every tap, sequence, and screen entry has been refined to provide immediate physical feedback to the user.

**Core thesis:** A finance and utility app should feel trustworthy and snappy. Micro-animations confirm user actions instantly without slowing them down.

---

## 3. V5 In-Scope Features & Refinements

| Area | Description | Priority |
|------|-------------|----------|
| **Tactile Interaction Feedback** | Wrapped all primary buttons, list items, and navigation icons with `TapScale` to provide a physical "press" feeling. | P0 |
| **List Entry Cascading** | Applied `StaggeredListItem` to all major lists (Groups, Members, Expenses, Cycle History) to prevent UI popping and guide the eye organically. | P0 |
| **Graceful Entry Transitions** | Implemented `FadeIn` on onboarding headers and empty states. | P1 |
| **Performance Maintenance** | Kept all animation durations strictly under 220-300ms using layer-backed Flutter animations to maintain 60fps performance without jank. | P0 |

---

## 4. Implementation Details

V5 achieved its polish strictly using internal animation utilities, heavily focusing on:

1. **`TapScale` Widget:**
   - Applied to structural navigation (back buttons).
   - Applied to core action buttons ("Submit", "Confirm", "Create Group").
   - Applied to interactive user elements (Profile Avatars, Choice Chips).
   
2. **`StaggeredListItem` Widget:**
   - Used in `CycleHistoryDetail`, `GroupMembers`, and `CycleHistory` screens to animate list items sequentially.

3. **`FadeIn` Widget:**
   - Used for structural empty states and onboarding copy (like `OnboardingNameScreen`), providing a smooth fade rather than an abrupt load.

By avoiding external dependencies, V5 maintains the app's lightweight profile and ensures full control over animation curves and timing.

---

## 5. Quality Bar (V5)

- Animations never block user interaction (no unskippable long transitions).
- Zero performance regressions on lower-end hardware (driven entirely by Flutter's animation engine).
- Consistent scale-down parameters across all back buttons across the app for uniformity.

---

## Document Control

- **Version:** 5.0
- **Status:** V5 Implemented (current release)
- **Audience:** Product and Engineering
- **Prerequisite:** [V4_RELEASE.md](V4_RELEASE.md)
