# Comprehensive research: prompt refinement and expense parsing

Research summary on fine-tuning and iteratively fixing LLM prompts for structured expense parsing, with citations and implications for the AI expense parser (model-agnostic prompt; current implementation uses Groq).

---

## 1. Structured output and JSON parsing

### 1.1 Why structure the prompt

- LLMs are trained on large amounts of text that include JSON, XML, YAML, etc., so **structured formats are a natural target** for instructions and outputs.
- **Structured prompting** (clear schema, required/optional keys, format rules) reduces ambiguity and can **reduce output errors** (e.g. reported ~60% in some settings) and improve consistency.
- **Validation**: With a fixed schema, responses can be checked automatically (missing fields, wrong types, invalid values).

**Sources:** Particula (prompt structure for JSON); JSONPrompt.it (structured prompting guide); OpenAI structured outputs (2024).

### 1.2 Beyond prompt-only: schema enforcement

- **Structured Outputs (OpenAI, 2024)** and **Groq strict mode** (`strict: true`) use constrained decoding so the model can only emit tokens that satisfy the schema, giving very high format compliance (e.g. 100% in some evaluations).
- When the provider supports it, **combine** schema enforcement with a clear prompt: schema handles form, prompt handles semantics (who paid, who shares, split type).
- **Groq:** Supports strict and best-effort structured output; best-effort can still produce malformed JSON, so prompt discipline and parsing fallbacks remain important.

**Sources:** OpenAI structured outputs; Groq docs (structured outputs, prompting); Twardziak (Medium, structured output beyond prompting).

---

## 2. Few-shot prompting: quality vs quantity

### 2.1 Example selection

- **Quality and diversity** of examples usually matter more than raw **quantity**. Picking examples that cover different reasoning patterns and edge cases outperforms simply adding more random examples.
- **Coverage-based selection** (e.g. set-level metrics that maximize coverage of important patterns) can outperform choosing only “most similar” examples (e.g. +17 points in some compositional tasks).
- **Label space, input distribution, and format consistency** in demonstrations are important; even imperfect labels can help if the **output format** is consistent.

### 2.2 Variance and stability

- Performance can **vary a lot** depending on which examples are in the prompt; careful selection reduces instability.
- **Multiple prompts with fewer samples** can perform similarly to one long prompt with more samples, suggesting value in diversity and targeted example sets.

**Implications for Expenso:** Prefer a **curated**, **diverse** set of few-shot examples (even, exact, exclude, percentage, shares; different payers; “with X” vs “X paid”) rather than expanding the list arbitrarily. Add examples that match **observed failure patterns** (see refinement doc).

**Sources:** Coverage-based example selection (arXiv 2305.14907); More samples or more prompts (arXiv 2311.09782); Min et al. (2022); DataCamp / prompting guide (few-shot).

---

## 3. Instruction tuning vs prompt engineering vs in-context learning

### 3.1 Definitions

- **In-context learning (ICL):** Demonstrations at inference time, **no** parameter updates.
- **Instruction tuning (IT):** Training on (instruction, response) pairs; at inference, no (or few) demonstrations needed.
- **Prompt engineering / prompt tuning:** Designing or tuning the prompt (and sometimes a small set of soft prompts) with a frozen model.

### 3.2 How they relate

- ICL can behave like “implicit” instruction tuning in terms of effect on hidden states; the two can yield **similar behavior** in some settings.
- **Instruction Prompt Tuning** combines learned prompts with in-context examples; performance can be more **stable** when both are used, but gains depend on examples being **semantically relevant** to the test input.
- For **smaller or multilingual** models, ICL sometimes underperforms instruction tuning; alignment (e.g. DPO) can partly close the gap.

**Implications for Expenso:** We rely on **in-context learning** (system prompt + few-shot) without fine-tuning. To improve behavior, we refine the **prompt and examples** and, when available, consider provider features (e.g. Groq structured output) rather than training our own model.

**Sources:** How does in-context learning help prompt tuning (ACL 2024, arXiv 2302.11521); Exploring ICL and instruction tuning (ACL 2024); Instruction Prompt Tuning.

---

## 4. Error-driven prompt refinement

### 4.1 Error reflection prompting (ERP)

- **Idea:** Show the model an **incorrect** answer plus a short explanation of the error, then the **correct** reasoning/answer. This helps the model avoid repeating the same mistake.
- ERP can **outperform** standard chain-of-thought on reasoning benchmarks and reduce specific error types (e.g. algebraic, calculation).
- **Targeted feedback** (“fix this specific mistake”) tends to work better than vague “improve it” instructions.

### 4.2 Inference-time refinement (ProRefine, Self-Refine)

- **ProRefine:** An agentic loop where the model gets feedback and the **prompt** is refined at inference time (no extra training). Reported gains of ~3–37 percentage points on some math tasks.
- **Self-Refine:** Model generates output → self-feedback → refine, iteratively. Can improve dialog and reasoning without supervised training.
- **Curative Prompt Refinement:** Fixing ill-formed or vague prompts to align intent with the actual task can reduce hallucinations (e.g. high win rates in quality).

### 4.3 Modular / section-local optimization

- Treating the prompt as **structured sections** (e.g. role, context, task, constraints, output format) allows:
  - **Tracing errors** to a specific section.
  - **Editing one section** without rewriting the whole prompt.
  - Fewer contradictions and better maintainability.
- **Modular Prompt Optimization** uses section-local “textual gradients” to optimize parts of the prompt independently.

**Implications for Expenso:**  
- Use a **COMMON MISTAKES** (or similar) block in a **WRONG → RIGHT** form (error reflection), not only “do not do X.”  
- Keep the prompt **sectioned** (SCENARIO DECISION, FIELD RULES, EDGE CASES, COMMON MISTAKES, EXAMPLES) so each fix is localized.  
- Document failures and fixes in **EXPENSE_PARSER_PROMPT_REFINEMENT.md** and update the prompt (rule, anti-pattern, or example) systematically.

**Sources:** Error Reflection Prompting (arXiv 2508.16729); ProRefine (arXiv 2506.05305); Self-Refine (arXiv 2303.17651); Modular Prompt Optimization (arXiv 2601.04055).

---

## 5. Ambiguity and disambiguation in semantic parsing

### 5.1 The problem

- Natural language is **ambiguous** (e.g. “split with X” vs “X paid” vs “X paid for me”). Models often **favor one interpretation** and under-represent others.
- Directly parsing ambiguous utterances into a single structure can lock in that bias and miss valid alternatives.

### 5.2 Disambiguate-first strategies

- **Disambiguate first, parse later:**  
  1. Generate one or more **natural language interpretations** of the ambiguous input.  
  2. **Then** map each interpretation to the structured form (e.g. JSON).  
  This can improve coverage and generalization.
- **Explicit decision order** in the prompt (e.g. 1) Who paid? 2) Who shares? 3) Split type?) acts as a lightweight “disambiguate then parse” pipeline inside a single call.

**Implications for Expenso:** The **SCENARIO DECISION** section (who paid → who shares → split type) is a low-cost way to force a consistent resolution of ambiguity before emitting JSON. Adding clear rules and examples for ambiguous phrasings (“X paid 200” vs “200 with X”) reduces inconsistent interpretations.

**Sources:** Disambiguate first, parse later (ACL 2025, arXiv 2502.18448); concept-based ambiguity detection; paraphrasing and verification (Monash).

---

## 6. Temperature and reliability

### 6.1 Temperature and determinism

- **Low temperature (e.g. 0)** uses greedy decoding but **does not guarantee** fully deterministic output (e.g. ties, implementation details, MoE routing).
- Some studies report **non-negligible variance** (e.g. accuracy swings, best vs worst run gaps) even at temperature 0.
- For **extraction/parsing**, providers (e.g. Groq) recommend **low temperature** (0–0.2) for consistency.

### 6.2 Problem-solving and temperature

- In some **reasoning** benchmarks, changing temperature from 0 to 1 did **not** show a significant effect; the impact is task-dependent.
- **Instruction-tuned** models are often more stable across temperatures than base models.

**Implications for Expenso:** Keep **temperature low** (e.g. 0.1 as in current code) for the parser. Rely on prompt structure and examples for correctness; treat some variance as inherent and handle it with validation and fallbacks.

**Sources:** Effect of temperature on problem solving (arXiv 2402.05201); non-determinism at temp 0 (Schmalbach; arXiv 2408.04667); Groq prompt basics.

---

## 7. Negative constraints and anti-patterns

### 7.1 Risks of “do not do X”

- **Negative constraints** (“do not output X”) can **backfire**: mentioning a forbidden behavior can **prime** the model toward it (e.g. “do not use names” making names more likely in some setups).
- **Override failure:** Later layers can override earlier “do not” signals. Suppression from negative instructions can be **weaker** when the model fails than when it obeys.
- **Inverse scaling:** Some work suggests **larger** models can perform **worse** on negated prompts than smaller ones.

### 7.2 Safer use of “wrong” in prompts

- **Error reflection** (show **wrong** answer + **correct** answer and reasoning) is different from a bare “do not do X” and is supported by ERP-style results.
- Prefer **positive framing**: state what TO do, show **correct** examples, and use **WRONG → RIGHT** pairs (as in COMMON MISTAKES) rather than long lists of prohibitions.

**Implications for Expenso:** Keep COMMON MISTAKES in **WRONG: X → RIGHT: Y** form. Avoid long, purely negative lists (“never do A, never do B”); instead add targeted wrong→right lines when we fix a real failure.

**Sources:** Semantic gravity wells / negative constraints backfire (arXiv 2601.08070); negated prompts (MLR 2023); Palantir / OpenAI prompt best practices.

---

## 8. Evaluation and regression when changing prompts

### 8.1 Why LLM regression is hard

- **Non-determinism** and **prompt sensitivity**: small wording changes can shift accuracy (e.g. reported ~10% on some benchmarks). Some of this may be **evaluation** sensitivity (e.g. rigid matching) rather than pure model instability.
- **Multiple valid outputs**: one input can have several correct parses (e.g. different descriptions for the same intent), so **exact-match** tests are too strict.
- **Brittleness**: same prompt, different run can yield different results.

### 8.2 Practical evaluation

- **Golden dataset:** Maintain a set of **(input, expected_output)** pairs that cover main scenarios and past failures. After each prompt change, re-run and compare (with semantic or flexible matching where appropriate).
- **Semantic similarity** or **LLM-as-judge** can capture “correct meaning” better than string match.
- **Section-local changes:** When the prompt is modular, change one section at a time and re-test to see which part caused regressions.

**Implications for Expenso:**  
- Keep a **changelog** of errors and fixes (EXPENSE_PARSER_PROMPT_REFINEMENT.md).  
- Optionally add a **small golden set** (e.g. in `tool/` or `test/`) of inputs and expected JSON (or key fields) and run after prompt edits.  
- Prefer **targeted** edits (one section, one rule or example) to reduce unintended regressions.

**Sources:** Why is my prompt getting worse (arXiv 2311.11123); Evidently AI regression testing; Confident AI LLM testing; SCORE / prompt sensitivity (arXiv 2503.00137, 2509.01790).

---

## 9. Provider-agnostic prompt and optional provider features

### 9.1 Structured outputs (when the provider supports it)

- **Strict mode** (when available): schema is enforced at decoding time; use when the pipeline requires strict JSON shape.
- **Best-effort mode:** model tries to follow the schema but may occasionally produce invalid or incomplete JSON; **prompt + client-side parsing/validation** remain important.

### 9.2 Prompting (any LLM)

- Include **role, instructions, context, input, and expected output**.
- Provide **example outputs** to lock format.
- Use **system** prompt for persona and constraints.
- List **exact required keys** in instructions.
- **Minimize context**: only what’s needed (e.g. member list, task description) to limit cost and drift.
- **Low temperature** (e.g. 0–0.2) for extraction/parsing.

**Implications for Expenso:** The expense parser prompt is **model-agnostic** and uses system message, schema, rules, and examples. It is designed to work with any LLM. If the current provider (e.g. Groq) supports structured output, enable it for format guarantees while keeping the same prompt for semantics.

**Sources:** OpenAI/Groq structured outputs; general prompting guides (OpenAI, Groq, Anthropic, etc.).

---

## 10. Prompt length and context

- **Longer context** can **hurt** performance even when retrieval is good; “context length alone” can explain non-trivial drops (e.g. 14–85% in some studies).
- **Compression** (extractive, summarization) and **dynamic example selection** (fewer examples for simpler inputs) can reduce length and preserve accuracy.
- For **in-context learning**, scaling to many examples is possible with **structured prompting** (e.g. position embeddings, rescaled attention) but adds implementation complexity.

**Implications for Expenso:** Keep the prompt **as short as is sufficient**: concise rules, no redundant examples, and a **bounded** COMMON MISTAKES list. Prefer **quality and coverage** of examples over adding more of them.

**Sources:** Context length hurts performance (arXiv 2510.05381); prompt compression (arXiv 2407.08892); structured prompting scaling (arXiv 2212.06713).

---

## 11. Summary: checklist for our parser

| Area | Recommendation |
|------|-----------------|
| **Structure** | Keep prompt sectioned (SCENARIO DECISION, FIELD RULES, EDGE CASES, COMMON MISTAKES, EXAMPLES). Fix one section at a time. |
| **Errors** | Document each failure in EXPENSE_PARSER_PROMPT_REFINEMENT.md; add a rule, a WRONG→RIGHT line, or a few-shot example. |
| **Examples** | Curate for diversity and failure patterns; prefer quality over quantity; avoid bloating the prompt. |
| **Ambiguity** | Use explicit decision order (who paid → who shares → split type); add examples for ambiguous phrasings. |
| **Negative instructions** | Use WRONG→RIGHT (error reflection), not long “never do X” lists. |
| **Temperature** | Keep low (e.g. 0.1) for parsing. |
| **Evaluation** | Consider a small golden set; re-run after prompt changes; use flexible or semantic matching where appropriate. |
| **Provider** | Prompt is model-agnostic. If the provider supports structured output (strict), use it with the current prompt for semantics. |

---

## 12. References (short)

- **Structured output:** Particula, JSONPrompt.it, OpenAI/Groq docs, Twardziak (Medium).
- **Few-shot:** arXiv 2305.14907, 2311.09782; Min et al. 2022; DataCamp, prompting guide.
- **ICL vs IT:** ACL 2024 (EACL, EMNLP findings); Instruction Prompt Tuning.
- **Error refinement:** ERP (arXiv 2508.16729), ProRefine (2506.05305), Self-Refine (2303.17651), MPO (2601.04055).
- **Ambiguity:** Disambiguate first (ACL 2025, arXiv 2502.18448).
- **Temperature:** arXiv 2402.05201, 2408.04667; Schmalbach; Groq.
- **Negative constraints:** arXiv 2601.08070; MLR 2023 (negated prompts); Palantir, OpenAI.
- **Regression:** arXiv 2311.11123, 2503.00137, 2509.01790; Evidently, Confident AI.
- **Context length:** arXiv 2510.05381, 2407.08892, 2212.06713.
- **Providers:** OpenAI, Groq, Anthropic docs (structured outputs, prompting).
