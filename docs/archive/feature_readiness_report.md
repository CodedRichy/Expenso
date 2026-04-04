# Core Feature Readiness Report

This report evaluates the usability and production-readiness of Expenso's core features.

## Feature: Create Group
- **Status**: Complete
- **Working**: High-fidelity UI for naming, currency selection (including ₹), and instant Supabase persistence.
- **Missing**: Advanced features like group-specific categories or monthly budgets.
- **Blocking Issues**: None.

## Feature: Invite Members
- **Status**: Complete
- **Working**: Multi-channel invite links and QR code generation. Support for pending member tracking before they join.
- **Missing**: Push notifications or in-app "Pending Invites" inbox (currently relies on external link sharing).
- **Blocking Issues**: None (though deep link verification in `main.dart` needs the `login-callback` fix to ensure smooth onboarding).

## Feature: Add Expense (Manual + Magic Bar)
- **Status**: Partial
- **Working**: 
    - **Manual**: Fast numeric keypad, Haptic feedback, flexible split options (Even, Exact, Percentage, Shares, Exclude).
    - **Magic Bar**: Natural language parsing ("Dinner 500 with Ash") via Groq is functional.
- **Missing**: Magic Bar and OCR access *inside* the `ExpenseInput` screen. Currently, they only exist as a bottom bar in `GroupDetail`.
- **Blocking Issues**: 
    - **OCR**: Relies on `callOcrScanner` Edge Function (must be deployed).
    - **UX**: If a user taps the floating `+` button, they lose access to the "Magic" features.

## Feature: View Balances
- **Status**: Partial
- **Working**: Real-time balance summary ("You owe" vs "You are owed"), integrated settlement progress indicator.
- **Missing**: "Audit Trail" view (a clear list showing which specific expenses led to a specific balance).
- **Blocking Issues**: 
    - **Performance**: The data stream filters 100% of group expenses in memory. This **will block usage** once a group has >100 expenses due to UI lag and memory pressure.

## Feature: Settlement (UPI Flow)
- **Status**: Partial / Broken
- **Working**: Native UPI intent switching (PhonePe, GPay, PayTM), two-way confirmation flow (Payer marks as paid -> Receiver confirms), Cash payment fallback.
- **Missing**: Integrated bank verification; the system currently operates on mutual trust.
- **Blocking Issues**: 
    - **Atomicity**: The `settleAndRestart` Edge Function lacks transaction safety. A failure during settlement can leave a group without an active cycle, effectively breaking it for all members.
    - **Placeholders**: The payment methods tray in `GroupDetail` is currently a UI placeholder (💳).
