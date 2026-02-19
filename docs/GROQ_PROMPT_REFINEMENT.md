# Groq expense parser: prompt refinement

When the Magic Bar produces a **wrong parse** (wrong payer, participants, split type, amount, or description), fix it by updating the prompt and recording the change here. The prompt lives in `lib/services/groq_expense_parser_service.dart` (`_buildSystemPrompt`).

**Comprehensive research:** See **docs/RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md** for a full literature summary (structured output, few-shot, error-driven refinement, ambiguity, temperature, negative constraints, evaluation, Groq-specific guidance).

---

## Process (every time we hit an error)

1. **Reproduce** – Note the exact user input and what the app did wrong (e.g. wrong participants, wrong payer).
2. **Decide where to fix** – Prompt is structured; choose one or more:
   - **SCENARIO DECISION** – Who paid / who shares / split type logic.
   - **FIELD RULES** – amount, description, category, splitType, participants, payer.
   - **EDGE CASES** – One-off rules.
   - **COMMON MISTAKES** – Add a wrong → right line so the model avoids the pitfall.
   - **EXAMPLES** – Add or adjust a few-shot example that matches the failing input pattern.
3. **Edit the prompt** – Add a rule, an anti-pattern in COMMON MISTAKES, or an example. Prefer minimal, targeted changes so other behaviors don’t regress.
4. **Log it below** – Add a row to the changelog: date, input, wrong behavior, fix (which section + what you added).

---

## Changelog (errors and fixes)

| Date       | User input (example) | Wrong behavior | Fix applied |
|------------|----------------------|----------------|-------------|
| 2025-02-18 | "X paid 200" (2-person group) | participants = [X] only; only payer in split | SCENARIO DECISION + FIELD RULES: when payer is named but no "with Y", participants = [] (everyone). EXAMPLES: added "Bob paid 200", "Carol paid 500 for dinner" with payer + participants:[]. Repo/dialog also fixed to treat [] as all members. |
| (future)   | … | … | … |

Add new rows when you fix a parse error. Keep the table concise; details can live in commit messages or DEBUG_SESSION.md if needed.

---

## Prompt sections (quick reference)

- **SCENARIO DECISION** – Order of inference: who paid → who shares → split type. Critical line for "X paid amount" vs "amount with X".
- **OUTPUT SCHEMA** – Required and conditional JSON keys.
- **MEMBER LIST** – Injected at runtime; names must match.
- **FIELD RULES** – 1) amount 2) description 3) category 4) splitType 5) participants 6) payer.
- **EDGE CASES** – Ambiguity, member list, JSON validity.
- **COMMON MISTAKES** – Short wrong→right lines (error-reflection style).
- **EXAMPLES** – Few-shot list; add examples that match new failure patterns.

---

## Research notes (why this process)

- **Iterative prompt engineering**: Refine over multiple rounds; fix specific errors with targeted changes rather than vague “improve it” (targeted feedback > vague).
- **Error reflection**: Showing the model “wrong X → right Y” (common mistakes) reduces repeated errors.
- **Structured prompts**: Tracing failures to a specific section (scenario, field rules, examples) allows section-local fixes and reduces regressions.
- **Versioning**: This doc acts as a lightweight changelog so we know what was fixed and why.
