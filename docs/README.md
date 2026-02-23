# Expenso Documentation

> Primary reference: [APP_BLUEPRINT.md](../APP_BLUEPRINT.md)

---

## Core

| Document | Purpose |
|----------|---------|
| [DATA_SPINE.md](DATA_SPINE.md) | Domain entities, mutability, data flow |
| [STABILIZATION.md](STABILIZATION.md) | Invariants, limitations, change safety |

## Releases

| Document | Purpose |
|----------|---------|
| [V1_RELEASE.md](releases/V1_RELEASE.md) | V1 contract |
| [V2_RELEASE.md](releases/V2_RELEASE.md) | V2 state and V3 deferrals |

## Features

| Document | Purpose |
|----------|---------|
| [MONEY_BALANCE_LOGIC.md](features/MONEY_BALANCE_LOGIC.md) | Balance computation spec |
| [MONEY_TESTS.md](features/MONEY_TESTS.md) | Golden test cases |
| [EXPENSE_REVISIONS.md](features/EXPENSE_REVISIONS.md) | Edit/delete via compensation events |
| [MULTI_PAYER.md](features/MULTI_PAYER.md) | Multiple payers per expense |
| [EXPENSE_SPLIT_USE_CASES.md](features/EXPENSE_SPLIT_USE_CASES.md) | Split scenarios |
| [SETTLEMENT_LOGIC_NOTES.md](features/SETTLEMENT_LOGIC_NOTES.md) | Settlement implementation notes |
| [DATA_ENCRYPTION.md](features/DATA_ENCRYPTION.md) | Encryption coverage |
| [DATA_ENCRYPTION_SETUP.md](features/DATA_ENCRYPTION_SETUP.md) | Setup guide |

## Research

| Document | Purpose |
|----------|---------|
| [EXPENSE_PARSER_PROMPT_REFINEMENT.md](research/EXPENSE_PARSER_PROMPT_REFINEMENT.md) | AI parser prompt changelog |
| [PARSER_AND_WHO_IS_INVOLVED.md](research/PARSER_AND_WHO_IS_INVOLVED.md) | Participant detection logic |
| [RESEARCH_SETTLEMENT_LOGIC.md](research/RESEARCH_SETTLEMENT_LOGIC.md) | Settlement research |
| [SURVEY_FEATURE_REQUESTS.md](research/SURVEY_FEATURE_REQUESTS.md) | User survey summary |

## Internal

| Document | Purpose |
|----------|---------|
| [LOGIC_AUDIT.md](internal/LOGIC_AUDIT.md) | Known issues, fixes, limitations |

## Architecture

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](architecture/ARCHITECTURE.md) | Module structure |
| [DEVELOPMENT.md](architecture/DEVELOPMENT.md) | Dev timeline |
| [BLUEPRINT_GAPS_VERIFICATION.md](architecture/BLUEPRINT_GAPS_VERIFICATION.md) | Blueprint vs implementation |
