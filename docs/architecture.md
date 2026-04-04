# Architecture: Expenso

## Detailed System Design
Expenso is built on a modular "Repository-driven" architecture designed for high-fidelity UI and robust financial tracking.

### Core Architecture Layers
1.  **Presentation (lib/screens & lib/widgets)**: Standard Flutter views. Screens never touch the database; they interact exclusively with `CycleRepository`.
2.  **Business Logic (lib/repositories & lib/utils)**:
    -   `CycleRepository`: The central orchestrator. Manages streams from Supabase/Firestore, maintains local caches, and notifies consumers.
    -   `SettlementEngine`: Pure logic utility for computing net balances, debts, and minimizing payment routes.
3.  **Data Models (lib/models)**: Immutable entities. Financial amounts use `MoneyMinor` (integers) for precision.
4.  **Services (lib/services)**: Infrastructure-specific wrappers (Auth, AI Parser, UPI, Database).

---

## Folder Structure & Modules

### `lib/` (Application Source)
-   `design/`: Modern Neo-Minimalist design system (tokens, glassmorphism, animations).
-   `models/`: Immutable data entities (Group, Expense, Cycle, MoneyMinor).
-   `repositories/`: `CycleRepository` — the heartbeat of the app.
-   `screens/`: Feature-oriented views (Auth, GroupDetail, Settlement).
-   `services/`: AI Parser (Groq), Payments (UPI, Razorpay), Storage (Supabase/Firestore).
-   `utils/`: `SettlementEngine`, normalization logic, and lifecycle guards.
-   `widgets/`: Custom UI components like `MagicBar`, `TapScale`, and loaders.

### `supabase/` (Backend Source)
-   `functions/`: Supabase Edge Functions (Typescript for Deno).
    -   `settleAndRestart`: Atomic cycle rotation logic.
    -   `_shared`: Shared utilities (CORS, types).
-   `migrations/`: SQL migrations for the Postgres database.

---

## Data Flow & Interactions
1.  **Input Flow (Magic Bar)**:
    -   User types → `GroqExpenseParserService` → AI JSON Response → Confirmation Dialog → `CycleRepository`.
2.  **Write Flow**:
    -   `CycleRepository` → `FirestoreService`/`SupabaseService` → Backend.
    -   Backend triggers (Firestore Sync/Realtime) → `CycleRepository` internal cache updates → `notifyListeners()` → UI Rebuilds automatically.
3.  **Settlement Flow**:
    -   `GroupDetail` → `SettlementEngine.computeNetBalances()` → UI Balance Card.
    -   `SettlementConfirmation` → `SettlementEngine.computePaymentRoutes()` → `UpiPaymentService`.
    -   Archive → Cloud Function (Atomic Transaction) → Cycle Rotation.

---

## Persistence & State Management
-   **In-Memory State**: Singleton `CycleRepository` holds all active groups and expenses for the current session.
-   **Synchronization**: Uses real-time streams (Firestore/Supabase Realtime) to ensure multi-device consistency.
-   **Compensation Model**: Instead of deleting an expense, the system appends a "negation" event to maintain a perfect audit trail.

---
*Updated: April 2026*
