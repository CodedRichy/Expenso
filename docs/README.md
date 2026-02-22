# Expenso Documentation

> Primary reference: [APP_BLUEPRINT.md](../APP_BLUEPRINT.md) (routes, data layer, logic)

---

## Key References

| Document | Purpose |
|----------|---------|
| [DATA_SPINE.md](DATA_SPINE.md) | Formal definition of core domain entities (User, Group, Expense, Cycle, etc.), their mutability, and data flow. |
| [STABILIZATION.md](STABILIZATION.md) | Post-hoc stabilization analysis: system snapshot, execution flows, invariants, limitations, and change safety guide. |

---

## Releases

| Document | Purpose |
|----------|---------|
| [V1_RELEASE.md](releases/V1_RELEASE.md) | V1 release contract: parser rules, Decision Clarity, authority, SettlementEngine, quality bar. |
| [V2_RELEASE.md](releases/V2_RELEASE.md) | V2 current state: profile pictures, UPI deep-linking, push; settlement consistency; V3 deferrals. |

## Architecture

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](architecture/ARCHITECTURE.md) | Module/directory structure over time (from Git). |
| [DEVELOPMENT.md](architecture/DEVELOPMENT.md) | Development timeline from commit history. |
| [BLUEPRINT_GAPS_VERIFICATION.md](architecture/BLUEPRINT_GAPS_VERIFICATION.md) | Gaps between blueprint and implementation. |

## Features

| Document | Purpose |
|----------|---------|
| [DATA_ENCRYPTION.md](features/DATA_ENCRYPTION.md) | Where encryption is used (project-wide via FirestoreService); coverage and intentional gap. |
| [DATA_ENCRYPTION_SETUP.md](features/DATA_ENCRYPTION_SETUP.md) | Step-by-step: set master key, deploy functions, verify. |
| [EXPENSE_SPLIT_USE_CASES.md](features/EXPENSE_SPLIT_USE_CASES.md) | Split scenarios and who-paid semantics. |
| [SETTLEMENT_LOGIC_NOTES.md](features/SETTLEMENT_LOGIC_NOTES.md) | Settlement logic implementation notes. |
| [MONEY_BALANCE_LOGIC.md](features/MONEY_BALANCE_LOGIC.md) | Balance computation isolation and specification. |

## Research

| Document | Purpose |
|----------|---------|
| [EXPENSE_PARSER_PROMPT_REFINEMENT.md](research/EXPENSE_PARSER_PROMPT_REFINEMENT.md) | AI expense parser prompt refinement (model-agnostic). |
| [RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md](research/RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md) | Literature and guidance for prompt refinement and parsing. |
| [RESEARCH_SETTLEMENT_LOGIC.md](research/RESEARCH_SETTLEMENT_LOGIC.md) | Settlement logic research and decisions. |
| [PARSER_AND_WHO_IS_INVOLVED.md](research/PARSER_AND_WHO_IS_INVOLVED.md) | Parser participant detection logic. |
| [SETTLEMENT_WHERE_AND_WHY.md](research/SETTLEMENT_WHERE_AND_WHY.md) | Settlement implementation rationale. |
| [SURVEY_FEATURE_REQUESTS.md](research/SURVEY_FEATURE_REQUESTS.md) | Survey summary and feature requests. |

## Internal

| Document | Purpose |
|----------|---------|
| [DEBUG_SESSION.md](internal/DEBUG_SESSION.md) | Debug session notes. |
| [TERMINAL_ERRORS_LOG.md](internal/TERMINAL_ERRORS_LOG.md) | Terminal error log. |
| [ISSUES_LIST.md](internal/ISSUES_LIST.md) | Known issues tracker. |
| [LOGIC_AUDIT.md](internal/LOGIC_AUDIT.md) | Logical errors found/fixed and follow-up items. |
