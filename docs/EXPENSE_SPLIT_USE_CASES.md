# Expense split use cases

Reference for split semantics, who-paid scenarios, and edge cases so the app stays consistent across Magic Bar, manual entry, and settlement.

**AI scenario selection:** The Groq parser prompt includes a **SCENARIO DECISION** section so the model infers, in order: (1) who paid, (2) who shares the cost, (3) split type. The model chooses the scenario from natural language (e.g. "Rockey paid 200" → payer Rockey, participants [], even). No separate classifier; the same LLM does disambiguation via the structured prompt and few-shot examples. See `lib/services/groq_expense_parser_service.dart` (_buildSystemPrompt).

---

## 1. Split types (industry alignment)

| Type | Meaning | When to use | Expenso |
|------|--------|-------------|---------|
| **Even** | Equal share per person | Group meals, rent, utilities, “split with X”, “everyone” | ✓ Magic Bar + manual; `participants: []` = everyone |
| **Exact** | Stated amount per person | “400 me 600 Bob”, “Alice 200 Carol 300”, itemized | ✓ Magic Bar (exactAmounts); manual via edit |
| **Exclude** | Equal among all except listed | “Dinner 2000 except Carol”, “not Bob”, “only me and Y” | ✓ Magic Bar (excluded); repo: allPhones − excluded |
| **Percentage** | % of total per person | “60-40 with Bob”, “50% me 50% Carol” | ✓ Magic Bar → converted to Exact for persist |
| **Shares** | By units (nights, shares) | “Alice 2 nights Bob 3”, “split by nights” | ✓ Magic Bar → converted to Exact for persist |

---

## 2. Who paid

| Phrase / case | Payer | Participants (even) | Result |
|---------------|--------|----------------------|--------|
| “I paid 500” / “paid 500” / no payer | Current user | From “with X” or [] = everyone | You paid; split by participants or everyone |
| “Rockey paid 200” / “paid by Rockey” | Rockey | [] = **everyone** (not just payer) | Rockey paid; everyone owes equal share (e.g. 2 people → 100 each) |
| “Alice paid for me 1200” | Alice | [] = everyone | Alice paid; even split including you |
| “Bob paid 500 for dinner” | Bob | [] = everyone | Bob paid; even split |

**Rule:** `participants: []` in Magic Bar means “everyone in the group”, not “only the payer”. Repo and confirmation dialog must treat empty participants for Even as **all group members** (see §4).

---

## 3. Participants

| Input | participants | Repo (Even) | UI |
|-------|----------------|-------------|-----|
| “everyone” / “all” / “with everyone” | [] | allPhones | Chips for all members |
| “with Bob” | [Bob] | [Bob] + you (implicit) | You + Bob chips, 50–50 |
| “with Alice and Bob” | [Alice, Bob] | [Alice, Bob] + you | Three-way even |
| “rockey paid 200” (no “with”) | [] | allPhones | Chips for all (e.g. You 100, Rockey 100) |
| “only me and Bob” | exclude others | Exclude: [Alice, Carol…] | Even between you and Bob |

Manual entry: “Who’s involved” = explicit set; if empty, repo uses allPhones for Even (same as Magic Bar).

---

## 4. Two-person group (Rishi + Rockey)

| Scenario | Expected cycle total | Your share | Your status |
|----------|----------------------|------------|-------------|
| “rockey paid 200” (even, everyone) | 200 | 100 | −100 (you owe 100) |
| “I paid 200” (even, everyone) | 200 | 100 | +100 (Rockey owes you 100) |
| “200 with Rockey” (you paid) | 200 | 100 | +100 |
| “rockey paid 200 with me” (explicit) | 200 | 100 | −100 |

Implementation: Even + `participantPhones.isEmpty` → repo uses `allPhones`; confirmation dialog builds slots for all members when `participantNames.isEmpty`.

---

## 5. Edge cases and validation

- **Exact sum ≠ total (rounding):** Prompt says “Sum of exactAmounts + me share = total”. Confirmation requires `|exactSum − amount| ≤ 0.01`. If AI omits “me” from exactAmounts, dialog may show sum ≠ total; consider adding “me” slot with `amount − sum(exactAmounts)` when splitType is exact and only others are listed.
- **Exclude everyone:** If excluded set = all members, repo falls back to [payer] so at least one person is in the split; avoid UX that allows excluding all.
- **Empty group / no members:** Repo uses `[payer]` or `[currentUser]` when `allPhones.isEmpty` so we never divide by zero.
- **Settlement:** Net balance = total paid − total share per person; debts computed from that. “Your share” in the card = sum of your portions (from splits or even share); “Your status” = net (positive = owed to you, negative = you owe).

---

## 6. Manual entry (ExpenseInput)

- Format: “Description Amount with Name, Name”.
- Who paid: Picker (default = you).
- Who’s involved: Checkboxes; can select all, subset, or none. **If none selected**, repo `addExpense` uses **all group members** (same as Magic Bar “everyone”).
- Manual expense gets `splitAmountsByPhone` from repo (equal split among participants); settlement uses it.

---

## 7. Consistency checklist

- [ ] Even + empty participants → allPhones in repo and in Magic Bar confirmation slots.
- [ ] “X paid [amount]” → payer = X, participants = [] → split among everyone.
- [ ] Two-person: “X paid 200” → cycle total 200, your share 100, your status −100 (if you’re not X).
- [ ] Exclude: allPhones − excludedPhones; if result empty, fallback to [payer].
- [ ] Exact: persist only keys present (AI omits “me”; confirmation can add “me” slot so sum = total).
- [x] Your share card: sum of my portion per expense (splits or amount/participants.length or amount/members.length when participants empty).
- [x] Manual entry with no one selected in “Who’s involved” → all members (same as Magic Bar everyone).

---

## 8. References

- Groq prompt: `lib/services/groq_expense_parser_service.dart` (§ FIELD RULES, EXAMPLES).
- Repo: `addExpenseFromMagicBar` and `addExpense` in `lib/repositories/cycle_repository.dart`.
- Balances: `lib/utils/settlement_engine.dart` (`computeNetBalances`, `computeDebts`).
- Confirmation dialog: `_showConfirmationDialog` and `_onConfirm` in `lib/screens/group_detail.dart`.
- **Prompt refinement:** When the parser produces a wrong result, document the error and fix in **docs/GROQ_PROMPT_REFINEMENT.md** and update the prompt (rule, COMMON MISTAKES, or example) in `groq_expense_parser_service.dart`.
