# Expenso Documentation

> Primary reference: [APP_BLUEPRINT.md](../APP_BLUEPRINT.md)

---

## Quick Navigation

| Category | Focus |
|----------|-------|
| [Core](#core) | Data model, flows, stability |
| [Features](#features) | Money logic, splits, encryption |
| [Releases](#releases) | Version contracts |
| [Architecture](#architecture) | Module structure, dev history |
| [Research](#research) | Parsing, settlement explorations |
| [Internal](#internal) | Strategy, audits |
| [Future](#future) | Planned capabilities |

---

## Portfolio & Interviews

| Document | Purpose |
|----------|---------|
| [PORTFOLIO.md](PORTFOLIO.md) | Resume bullets, architecture overview, interview talking points |

---

## Core

| Document | Purpose |
|----------|---------|
| [DATA_SPINE.md](DATA_SPINE.md) | Domain entities, mutability, data flow |
| [DATA_FLOW_TABLES.md](DATA_FLOW_TABLES.md) | Screen-to-database data mapping (SQL table format) |
| [STABILIZATION.md](STABILIZATION.md) | Invariants, limitations, change safety |

---

## Features

| Document | Purpose |
|----------|---------|
| [MONEY_BALANCE_LOGIC.md](features/MONEY_BALANCE_LOGIC.md) | Balance computation spec |
| [MONEY_CANONICALIZATION.md](features/MONEY_CANONICALIZATION.md) | Canonical money computation plan |
| [MONEY_PHASE2.md](features/MONEY_PHASE2.md) | Phase 2 invariant enforcement (executed) |
| [MONEY_TESTS.md](features/MONEY_TESTS.md) | Golden test cases |
| [EXPENSE_REVISIONS.md](features/EXPENSE_REVISIONS.md) | Edit/delete via compensation events |
| [MULTI_PAYER.md](features/MULTI_PAYER.md) | Multiple payers per expense |
| [EXPENSE_SPLIT_USE_CASES.md](features/EXPENSE_SPLIT_USE_CASES.md) | Split scenarios |
| [DATA_ENCRYPTION.md](features/DATA_ENCRYPTION.md) | Encryption coverage |
| [DATA_ENCRYPTION_SETUP.md](features/DATA_ENCRYPTION_SETUP.md) | Setup guide |

---

## Releases

| Document | Purpose |
|----------|---------|
| [V1_RELEASE.md](releases/V1_RELEASE.md) | V1 (Magic Bar, Decision Clarity, SettlementEngine) |
| [V2_RELEASE.md](releases/V2_RELEASE.md) | V2 (Profile pictures, UPI deep-linking) |
| [V3_RELEASE.md](releases/V3_RELEASE.md) | V3 (Settlement activity, offline resilience, Dynamic UPI QR) |
| [V4_RELEASE.md](releases/V4_RELEASE.md) | **V4 current** (Cross-group identity, God Mode debt minimization) |

---

## Architecture

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](architecture/ARCHITECTURE.md) | Module structure |
| [DEVELOPMENT.md](architecture/DEVELOPMENT.md) | Dev timeline |
| [BLUEPRINT_GAPS_VERIFICATION.md](architecture/BLUEPRINT_GAPS_VERIFICATION.md) | Blueprint vs implementation |

---

## Research

| Document | Purpose |
|----------|---------|
| [EXPENSE_PARSER_PROMPT_REFINEMENT.md](research/EXPENSE_PARSER_PROMPT_REFINEMENT.md) | AI parser prompt changelog |
| [RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md](research/RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md) | Parsing research notes |
| [PARSER_AND_WHO_IS_INVOLVED.md](research/PARSER_AND_WHO_IS_INVOLVED.md) | Participant detection logic |
| [RESEARCH_SETTLEMENT_LOGIC.md](research/RESEARCH_SETTLEMENT_LOGIC.md) | Settlement research |
| [SETTLEMENT_LOGIC_NOTES.md](research/SETTLEMENT_LOGIC_NOTES.md) | Settlement debugging notes |
| [SURVEY_FEATURE_REQUESTS.md](research/SURVEY_FEATURE_REQUESTS.md) | User survey summary |

---

## Internal

| Document | Purpose |
|----------|---------|
| [LOGIC_AUDIT.md](internal/LOGIC_AUDIT.md) | Known issues, fixes, limitations |
| [MONETIZATION_EXECUTION.md](internal/MONETIZATION_EXECUTION.md) | Pricing, paywalls, rollout plan |

---

## Future

| Document | Purpose |
|----------|---------|
| [DESKTOP_WEB_WORKSPACE.md](future/DESKTOP_WEB_WORKSPACE.md) | Desktop/web workspace vision (Pro-only) |
