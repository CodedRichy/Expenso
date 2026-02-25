# AI expense parser: prompt refinement

**Note:** The app parser (`groq_expense_parser_service.dart`) is not to be changed until the CLI (`tool/parser_cli.dart`) is iterated to satisfaction. Refine the CLI prompt and behavior first, then port to the app.

When the Magic Bar produces a **wrong parse** (wrong payer, participants, split type, amount, or description), fix it by updating the prompt and recording the change here. The prompt lives in `lib/services/groq_expense_parser_service.dart` (`_buildSystemPrompt`). The prompt text is **model-agnostic** and is designed to work with any LLM (Groq, OpenAI, Anthropic, etc.).

**Comprehensive research:** See **docs/RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md** for a full literature summary (structured output, few-shot, error-driven refinement, ambiguity, temperature, negative constraints, evaluation, and provider-agnostic guidance).

---

## Process (every time we hit an error)

1. **Reproduce** – Note the exact user input and what the app did wrong (e.g. wrong participants, wrong payer).
2. **Decide where to fix** – Prompt is structured; choose one or more:
   - **SCENARIO** – Who paid / who shares / split type logic.
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
| 2025-02-18 | "X paid 200" (2-person group) | participants = [X] only; only payer in split | SCENARIO + FIELD RULES: when payer is named but no "with Y", participants = [] (everyone). EXAMPLES: added "B paid 200", "C paid 500 for dinner" with payer + participants:[]. Repo/dialog also fixed to treat [] as all members. |
| 2025-02-18 | "dinner with X amount" / even split with participants | Parser must output participants = others only (app uses total = 1 + participants.length) | FIELD RULES — participants = only others; app adds current user. COMMON MISTAKES — WRONG→RIGHT for "200 with X" (participants:[X]) and "amount with A and B" (participants:["A","B"]). EXAMPLES: "dinner with B 300" -> participants:["B"]. |
| 2025-02-20 | Prompt optimization (structure, concision, tokens) | N/A | Schema-first: OUTPUT SCHEMA + example shape moved to top. Tightened SCENARIO and FIELD RULES; condensed COMMON MISTAKES. Curated EXAMPLES (56→22) for diversity and failure patterns; temperature 0 for extraction. See RESEARCH_PROMPT_REFINEMENT_AND_PARSING.md. |
| 2025-02-20 | Generalize for any AI | N/A | Prompt and docs framed as model-agnostic; refinement doc renamed to EXPENSE_PARSER_PROMPT_REFINEMENT.md; added explicit "works with any language model" line in prompt. |
| 2025-02-25 | "i had dinner for 2000... rest between us two" / "I had ₹800" exact / "I took 2 shares" / "Split between Rishi, Prasi, Alex" / "lowk had to pay 600" | exactAmounts or sharesAmounts omitted current user; participants included current user; payer "Lowk" not in list. | Iteration: Added optional currentUserDisplayName to parse(); prompt now injects "Current user (I/me/my): {name}". FIELD RULES: exactAmounts/sharesAmounts must include current user when stated; participants others only; payer only from list. COMMON MISTAKES: wrong→right for these. EXAMPLES: "400 for me 600 for B" → exactAmounts {"A":400,"B":600}; "600: 400 me 200 B" → {"A":400,"B":200}; "I owe 700 B owes 800" → {"A":700,"B":800}. App passes repo.currentUserName; CLI uses 3rd arg or first member. |
| (future)   | … | … | … |

Add new rows when you fix a parse error. Keep the table concise; details can live in commit messages or DEBUG_SESSION.md if needed.

---

## Prompt sections (quick reference)

- **OUTPUT SCHEMA** – Required and conditional keys; one example shape (schema-first for format lock).
- **SCENARIO** – Order of inference: who paid → who shares → split type. Critical: "X paid amount" vs "amount with X".
- **MEMBER LIST** – Injected at runtime; names must match.
- **FIELD RULES** – amount, description, category, splitType, participants, payer (concise bullets).
- **EDGE CASES** – Ambiguity, JSON validity.
- **COMMON MISTAKES** – Wrong→right lines (error-reflection style).
- **EXAMPLES** – Curated few-shot; add examples that match new failure patterns.

---

## Research notes (why this process)

- **Iterative prompt engineering**: Refine over multiple rounds; fix specific errors with targeted changes rather than vague "improve it" (targeted feedback > vague).
- **Error reflection**: Showing the model "wrong X → right Y" (common mistakes) reduces repeated errors.
- **Structured prompts**: Tracing failures to a specific section (scenario, field rules, examples) allows section-local fixes and reduces regressions.
- **Versioning**: This doc acts as a lightweight changelog so we know what was fixed and why.
