# Motion & UI Polish — Implementation Reference

This doc describes the motion, haptics, and UI polish added after the [UI/UX Audit](UI_UX_AUDIT.md): what was implemented, where it lives, and how to tune it.

---

## 1. Overview

| Category | What was added |
|----------|----------------|
| **Entrance / transitions** | Undo toast slide-up + fade; step transitions (PhoneAuth, ExpenseInput); fade-in on static screens (CycleSettled, EmptyStates, ErrorStates); staggered list entry (GroupDetail, GroupsList, SettlementConfirmation). |
| **Success / feedback** | PaymentResult icon scale (elasticOut); circular countdown on undo toast; haptics on primary actions. |
| **Micro-interaction** | TapScale on GroupsList FAB; page transitions via theme. |

All motion uses the app’s existing design tokens (colors, typography). No new visual styles were introduced.

---

## 2. Where motion lives (by screen)

| Screen / flow | Motion |
|---------------|--------|
| **Undo toast** (GroupDetail dialog, UndoExpense route) | Slide up (0.4 → 0) + fade in (280ms); circular countdown ring; haptic on Undo. |
| **PaymentResult** | Success: icon scale 0 → 1, `Curves.elasticOut`, 400ms; haptic on Done. |
| **GroupDetail** | Expense list: staggered fade + slide per item (50ms delay cap 10, 220ms duration). Haptic when opening expense input. |
| **GroupsList** | Group list: same stagger. FAB: TapScale (0.98) on press, 80ms. |
| **SettlementConfirmation** | “Pay individually” UPI cards and “Incoming payments” cards: StaggeredListItem. |
| **PhoneAuth** | AnimatedSwitcher (220ms) when switching phone step ↔ OTP step. |
| **ExpenseInput** | AnimatedSwitcher (220ms) when switching input view ↔ confirm view. Haptic on Confirm. |
| **CycleSettled** | Center content wrapped in FadeIn (280ms). |
| **EmptyStates** | No-groups, no-expenses, new-cycle, no-expenses-new-cycle: center content in FadeIn. |
| **ErrorStates** | All four types: center content in FadeIn. |
| **CreateGroup** | Haptic on Create. |
| **OnboardingName** | Haptic on Get Started. |
| **Navigation** | `pageTransitionsTheme` in `main.dart`: FadeUpwards (Android), Cupertino (iOS). |

---

## 3. Reusable widgets

### 3.1 UndoToast

**File:** `lib/widgets/undo_toast.dart`

**Purpose:** “Expense added” toast with slide-up + fade-in, circular countdown, and Undo. Used from GroupDetail (dialog) and UndoExpense (route).

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| description | String | — | Expense description. |
| amount | double | — | Amount (major units). |
| currencyCode | String | — | For formatting. |
| onUndo | VoidCallback | — | Called when user taps Undo (haptic fired here). |
| onDismiss | VoidCallback | — | Called when countdown reaches 0. |
| countdownSeconds | int | 5 | Countdown length. |

**Tuning:** Enter duration is 280ms (`_enterController`). Slide is `Offset(0, 0.4)` → `Offset.zero`, `Curves.easeOutCubic`. Countdown ring is 24×24, stroke 2.

---

### 3.2 StaggeredListItem

**File:** `lib/widgets/staggered_list_item.dart`

**Purpose:** Wraps a list item and runs a short enter animation with delay = `index * delayMs` (index capped at 10 so later items don’t wait too long).

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| index | int | — | Item index; delay = min(index, 10) * delayMs. |
| child | Widget | — | The list item. |
| delayMs | int | 50 | Delay per index (ms). |
| durationMs | int | 220 | Duration of fade + slide. |

**Animation:** Opacity 0 → 1 (`Curves.easeOut`), offset (0, 0.03) → (0, 0).

**Used in:** GroupDetail expense list; GroupsList group list; SettlementConfirmation (UPI cards + incoming payment cards).

---

### 3.3 FadeIn

**File:** `lib/widgets/fade_in.dart`

**Purpose:** Wraps a child and fades it in after an optional delay.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| child | Widget | — | Content. |
| duration | Duration | 280ms | Fade duration. |
| delay | Duration | zero | Delay before starting. |

**Animation:** Opacity 0 → 1, `Curves.easeOut`.

**Used in:** CycleSettled; EmptyStates (no-groups, no-expenses, new-cycle, no-expenses-new-cycle); ErrorStates (all four types).

---

### 3.4 TapScale

**File:** `lib/widgets/tap_scale.dart`

**Purpose:** Scales child to `scaleDown` on pointer down, back to 1 on pointer up/cancel.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| child | Widget | — | Typically a button or FAB. |
| scaleDown | double | 0.98 | Scale when pressed. |

**Tuning:** Duration 80ms, `Curves.easeInOut`. Uses `Listener` (not `GestureDetector`) so it doesn’t swallow taps.

**Used in:** GroupsList FAB only.

---

## 4. Haptics

`HapticFeedback.lightImpact()` (or equivalent) is used on:

- Add expense (GroupDetail → expense input)
- Create group (CreateGroup)
- Get Started (OnboardingName)
- Confirm expense (ExpenseInput)
- Undo (UndoToast)
- PaymentResult Done

No haptics were added for secondary actions (e.g. Cancel, Edit, Change number).

---

## 5. Timings quick reference

| Effect | Duration | Curve / notes |
|--------|----------|----------------|
| Undo toast enter | 280ms | easeOutCubic (slide), easeOut (fade) |
| PaymentResult icon | 400ms | elasticOut |
| List item stagger (each item) | 220ms | easeOut (opacity), easeOutCubic (slide) |
| Stagger delay per index | 50ms | — (cap at index 10) |
| Step transition (PhoneAuth, ExpenseInput) | 220ms | AnimatedSwitcher default |
| FadeIn (CycleSettled, Empty, Error) | 280ms | easeOut |
| TapScale (FAB) | 80ms | easeInOut |

---

## 6. Related docs

- **[UI_UX_AUDIT.md](UI_UX_AUDIT.md)** — Original audit: gaps, recommendations, screen checklist. Implementation status noted at the bottom.
- **Design system:** `lib/design/colors.dart`, `lib/design/typography.dart` — All motion reuses these; no new colors or type styles.

---

## 7. Tweaking motion

- **Slower / faster:** Change `duration` or `durationMs` in the widget or controller (e.g. UndoToast 280ms, StaggeredListItem 220ms, FadeIn 280ms, TapScale 80ms).
- **Stronger / subtler stagger:** Adjust `delayMs` (default 50) or the cap (10) in `StaggeredListItem`.
- **Different feel:** Swap curves (e.g. `Curves.easeOut` → `Curves.easeInOut`) in the relevant widget.

If something doesn’t feel right, the above widgets and timings are the first place to adjust.
