# Expenso Codebase Architecture (Explained)

This document explains how Expenso is organized, how data moves through the app, and where to add new features safely.

---

## 1) System at a Glance

Expenso is a Flutter + Firebase application with a repository-driven client architecture and server-assisted critical operations.

- Client: Flutter (Dart), Material 3 UI
- Data + Auth: Firestore, Firebase Auth, Firebase Storage
- Server Logic: Firebase Cloud Functions (Node.js)
- Core Pattern: Single state hub (`CycleRepository`) + service adapters + pure utility engine (`SettlementEngine`)

In practice:

1. UI screens/widgets collect intent.
2. `CycleRepository` coordinates reads/writes and in-memory state.
3. Services execute external operations (Firestore, auth, AI parsing, payments, encryption).
4. Cloud Functions handle privileged/atomic backend operations.

---

## 2) Directory-Level Architecture

### `lib/` (Flutter app)

- `main.dart`: app bootstrap, Firebase initialization, routes, theme setup.
- `models/`: immutable domain entities (`Group`, `Member`, `Expense`, `Cycle`, etc.).
- `repositories/`: orchestration layer (`CycleRepository`) and source of truth for active-cycle state.
- `services/`: integrations and gateways (Firestore, auth, parser, encryption, profile, payment APIs).
- `utils/`: pure/domain-heavy logic (`SettlementEngine`, normalization, validation, revision guards).
- `screens/`: feature screens and user flows.
- `widgets/`: reusable UI components and motion primitives.
- `design/`: design tokens (colors, typography, spacing).

### `functions/` (Firebase functions)

- Backend endpoints for high-trust workflows and transactional operations.
- Includes settlement/archive rotation logic and key derivation helpers.

### `test/` + `integration_test/`

- Unit and widget tests for core math, invariants, and UI contracts.
- Integration test(s) for app-level flow validation.

### `docs/`

- Product, architecture, release contracts, implementation notes, and research references.

---

## 3) Architectural Layers and Responsibilities

### Presentation Layer

Location: `lib/screens/`, `lib/widgets/`, `lib/design/`

Responsibilities:

- Render state and collect user actions.
- Keep UI concerns local (layout, interaction, animation).
- Avoid direct persistence logic.

Rule of thumb: screens should ask repository/services for behavior, not implement storage rules directly.

### Application/State Layer

Location: `lib/repositories/cycle_repository.dart`

Responsibilities:

- Maintain active state for current group/cycle.
- Subscribe to Firestore updates and publish updates to UI.
- Coordinate writes and derived state refresh.

Why this matters:

- Centralized state transitions reduce drift between screens.
- Real-time updates flow through one choke point.

### Domain Logic Layer

Location: `lib/utils/`

Responsibilities:

- Deterministic, testable business logic.
- Settlement math and debt minimization.
- Input normalization/validation and lifecycle constraints.

Examples:

- `SettlementEngine` for who-owes-whom computation.
- Normalization and revision guard utilities to preserve invariants.

### Infrastructure/Integration Layer

Location: `lib/services/` and `functions/`

Responsibilities:

- Communicate with Firebase, AI parser provider, UPI/payment systems.
- Encapsulate third-party SDK details away from UI and domain logic.
- Handle optional encryption for sensitive data paths.

---

## 4) Core Runtime Flows

### A) Expense Creation (Manual or Magic Bar)

1. User enters an expense via screen/widget.
2. For Magic Bar, parser service (`GroqExpenseParserService`) turns text into structured payload.
3. `CycleRepository` validates/normalizes intent and writes via service layer.
4. Firestore emits updated snapshots.
5. Repository updates cache/listenables.
6. UI rebuilds with new balances/expense list.

### B) Settlement and Cycle Rotation

1. User initiates settlement completion.
2. Client calls callable Cloud Function (`settleAndRestart`).
3. Function performs server-side validation + atomic archive/rotation transaction.
4. Firestore state transitions to next active cycle.
5. Repository receives stream updates and UI transitions accordingly.

This design prevents partial archive states and enforces authoritative backend checks.

### C) Authentication and Profile

1. Phone auth service performs OTP sign-in with Firebase Auth.
2. Profile data and avatar updates flow via profile/storage services.
3. Repository/UI consume updated identity data through normal state channels.

---

## 5) Data and Consistency Strategy

- Firestore is the canonical persisted state.
- Repository state is the canonical in-memory state for the running app.
- Domain math uses integer-minor-unit concepts where applicable to avoid floating-point drift.
- Sensitive fields can be encrypted at the service boundary (optional/backward-compatible strategy).
- High-risk state transitions (settle/archive/restart) are server-validated.

---

## 6) Cross-Cutting Concerns

### Security

- Firebase rules and auth gate access.
- Optional field-level encryption path for sensitive values.
- Server functions for critical transitions and key derivation helpers.

### Reliability

- Real-time stream-driven UI updates.
- Focused utility modules for deterministic business behavior.
- Test coverage around settlement and expense processing logic.

### Performance

- Feature-based UI composition with reusable widgets.
- State updates centralized to reduce duplicated fetch/recompute logic.
- Animation and skeleton patterns improve perceived responsiveness.

---

## 7) How to Add a New Feature (Safe Path)

1. Add or update domain model(s) under `lib/models/`.
2. Implement pure rules in `lib/utils/` first when business logic is involved.
3. Add/extend integration in `lib/services/` for external APIs.
4. Wire orchestration/state transitions in `CycleRepository`.
5. Build UI in `lib/screens/` and reusable pieces in `lib/widgets/`.
6. Add tests in `test/` (and integration tests when flow-wide behavior changes).

Keep Firestore access centralized through the repository/service path to preserve architecture consistency.

---

## 8) Known Tradeoffs

- Singleton-style central repository simplifies state coherence but can increase coupling if not modularized carefully.
- Real-time Firestore patterns are simple and responsive, but write orchestration discipline is required to avoid hidden side effects.
- Optional encryption mode supports rollout flexibility but requires clear operational setup for key management.

---

## 9) Quick Mental Model

Think of Expenso as:

- UI shell (`screens/widgets`) for interaction,
- one state brain (`CycleRepository`) for orchestration,
- pure math/legal rules (`utils`) for correctness,
- adapters (`services`) for the outside world,
- and Cloud Functions (`functions/`) for privileged atomic operations.

That separation is what keeps feature velocity high without compromising settlement correctness.

---

Updated: March 18, 2026
