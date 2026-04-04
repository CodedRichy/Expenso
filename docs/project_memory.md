# Project Memory: Expenso

## Project Name
**Expenso** — A premium, AI-powered group expense tracking application.

## Purpose
Expenso addresses the human psychology of debt in personal relationships. It aims to eliminate the friction and tension associated with asking for money by making the system the authority.
- **The Core Truth**: "I want my money back — without asking."
- **How it solves it**: Using a structured "Cycle" model, neutral group reminders, and automated NLP parsing to make expense entry and settlement feel routine rather than personal.

## Current Status (v5.0.0)
- **Version**: 5.0.0 (March 2026)
- **State**: Production-ready, currently undergoing a "Tactile & Premium Polish" pass (V5).
- **Backend Migration**: Transitioning from Firebase/Firestore to Supabase (Postgres).

## Tech Stack
- **Frontend**: Flutter (Dart), Material 3, Neo-Minimalist UI (Glassmorphism).
- **Backend**: Supabase (Postgres, Realtime, Edge Functions).
- **AI/NLP**: Groq API (Llama-3/4) for the Magic Bar natural language parsing.
- **Payments**: UPI Deep-linking (`upi_india`), Razorpay, and Dynamic QR Generation.

## Architecture Overview
Expenso follows a **Repository-driven Architecture**.
- **UI Layer**: Feature-based screens (`lib/screens`) and reusable widgets.
- **Domain Layer**: Immutable models (`lib/models/cycle.dart`, `expense.dart`, etc.).
- **Logic Layer**: `CycleRepository` (State Manager/Singleton) and `SettlementEngine` (Math).
- **Service Layer**: External API wrappers (Groq, Supabase, UPI).
- **Persistence**: Supabase (active) / Firestore (legacy sync).

## Key Components
- **Magic Bar**: NLP input field for zero-friction expense recording.
- **Cycle Model**: Discrete tracking and settlement phases (Active → Frozen → Archive).
- **Settlement Engine**: Debt minimization algorithm for optimal group settlement.
- **Decision Clarity Card**: Real-time net-balance visualization.

## Key Decisions
- **Singleton Repository**: `CycleRepository` is the single source of truth for in-memory state.
- **Integer-based Accounting**: `MoneyMinor` for all financial math to avoid floating-point issues.
- **Dual Backend Strategy**: Leveraging Firebase's strong Auth/FCM while migrating core state to Supabase.
- **Audit-friendly Ledger**: Expense edits/deletes use compensation events (negation + replacement) rather than in-place mutation.

## Known Issues
- **Multi-currency**: Currently limited to single-currency groups.
- **Offline Support**: Writes require a network connection (Optimistic UI foundation exists but needs refinement).
- **Supabase Transition**: Legacy Firebase Functions and Node-based tests have been deprecated in favor of Supabase Edge Functions.

## Current Focus / Next Steps
- **Animation Polish**: Completing the tactile feedback pass (V5).
- **Skeleton Audit**: Ensuring all loading states match final layouts exactly.
- **UPI Cleanup**: Moving away from unreliable intents towards clear App Picker/QR flows.
- **Supabase Migration**: Completing the final transition from Firestore.

---
*Updated: April 2026*
