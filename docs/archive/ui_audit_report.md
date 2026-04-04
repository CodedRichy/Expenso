# Expenso UI Structural Audit Report

This report focuses on structural UI issues, layout correctness, responsiveness, and adherence to design tokens.

## Section 1: Structural & Layout Issues

### AuthScreen (lib/screens/auth/auth_screen.dart)
- **Issue**: Potential keyboard overflow in email/phone input modes.
- **Cause**: While the screen uses a `Stack` and `Column`, it lacks an explicit `SingleChildScrollView` to handle small devices when the keyboard is open.
- **Severity**: medium

### GroupsList (lib/screens/groups/groups_list.dart)
- **Issue**: Horizontal padding mismatch.
- **Cause**: `_DashboardHeroCard` uses `horizontal: 24` padding, while the rest of the list items and section labels use `horizontal: 20`. This creates a slight misalignment in the vertical visual line.
- **Severity**: low

### GroupDetail (lib/screens/groups/group_detail.dart)
- **Issue**: Potential overflow in expense list items.
- **Cause**: `_ExpenseListItem` (implied) doesn't use `FittedBox` for Large amounts. If a group has an expense > 1,000,000,000, it may overflow its container or overlap the description.
- **Severity**: medium

### InviteMembers (lib/screens/groups/invite_members.dart)
- **Issue**: Fixed height overflow risk.
- **Cause**: The phone input field has a hardcoded `height: 56`. On extremely small devices with large accessibility fonts, this could clip text.
- **Severity**: medium

### OnboardingNameScreen (lib/screens/auth/onboarding_name.dart)
- **Issue**: Keyboard overflow.
- **Cause**: Missing `SingleChildScrollView`. The `Column` with `Spacer` will overflow if the keyboard is visible on devices with height < 600dp.
- **Severity**: high

### ExpenseInput (lib/screens/expenses/expense_input.dart)
- **Issue**: Amount display overflow.
- **Cause**: `AnimatedNumber` in the amount display row lacks `FittedBox` or `Flexible` constraints. Extremely large values will bleed off the screen edges.
- **Severity**: medium

### SettlementConfirmation (lib/screens/settlement/settlement_confirmation.dart)
- **Issue**: Large text overflow in UPI section.
- **Cause**: `totalDisplay` text uses `context.displayLarge` without wrapping in `FittedBox`. Large settlement amounts (e.g. "₹1,25,00,000.00") will overflow the card.
- **Severity**: high

### CycleHistoryDetail (lib/screens/settlement/cycle_history_detail.dart)
- **Issue**: Summary card overflow.
- **Cause**: `settledAmount` uses `context.displayLarge` inside a `Row`. Similar to SettlementConfirmation, this is highly prone to overflow with large values.
- **Severity**: high

### ProfileScreen (lib/screens/settings/profile.dart)
- **Issue**: Inconsistent vertical spacing.
- **Cause**: Logout button uses `Padding(bottom: 32)`, while other sections use `SizedBox(height: 24)`.
- **Severity**: low

### UpiPaymentCard (lib/widgets/upi_payment_card.dart)
- **Issue**: Title & Status Chip collision.
- **Cause**: `Text('Pay ${widget.payeeName}')` and `_buildStatusChip()` are in a `Row` where the text is `Expanded`. If the name is very long, it might force the status chip to the next line or make the chip very small if not handled by constraints correctly.
- **Severity**: medium

---

## Section 2: Design Token Adherence

### Positive Findings
- **Typography**: Excellent use of `context.headingMedium`, `context.labelLarge`, etc. across 95% of screens.
- **Colors**: Consistent use of `context.colorPrimary`, `context.colorSuccess`, and `context.colorWarning`.
- **Spacing**: High adherence to `AppSpacing` (radius, padding) especially in newer refactored screens.

### Areas for Improvement
- **Responsive Padding**: While tokens are used, the *value* of the token (e.g. 20 vs 24) is inconsistent between the Home screen (`GroupsList`) and detail screens.
- **Hardcoded Values**: Still present in `InviteMembers` (height 56) and `GroupDetail` (fixed heights for some category bars).

## Section 3: Summary of Structural Integrity
The codebase follows a mature structural pattern using `GradientScaffold` and `GlassCard`. The most significant risks are **overflows caused by large text/amounts** in key financial screens (`SettlementConfirmation`, `CycleHistoryDetail`) and **keyboard-induced overflows** in input-heavy screens (`OnboardingNameScreen`).
