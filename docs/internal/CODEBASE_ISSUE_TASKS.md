# Codebase issue tasks and gaps (proposed)

## Requested 4 tasks

### 1) Typo fix task
**Task:** Rename the test title `partial success: valid amount with empty description yields description in fromJson` to a clearer sentence (for example: `... yields empty description from fromJson`).

**Why:** The phrase "description in fromJson" is grammatically incorrect and makes test reports harder to scan.

**Source:** `test/parsed_expense_result_test.dart`.

### 2) Bug fix task
**Task:** Prevent parser `reject` outcomes from being silently converted into a fallback parsed expense.

**Why:** `parse()` throws when `parseConfidence == 'reject'`, but the outer `catch` currently attempts `_fallbackParse(userInput)` for any exception. Inputs like "I owe B 500 tomorrow" can therefore be incorrectly accepted because they contain a number.

**Source:** `lib/services/groq_expense_parser_service.dart`.

### 3) Comment/documentation discrepancy task
**Task:** Update architecture docs so top-level directory listings match the current repository.

**Why:** `docs/architecture/ARCHITECTURE.md` still lists files/directories such as `BUGS_FIXED.md`, `BUG_REPORT.md`, and `figma` as top-level items, but they are not present in the current repo tree.

**Source:** `docs/architecture/ARCHITECTURE.md` vs current repository file list.

### 4) Test improvement task
**Task:** Strengthen `even split general rule` test to validate behavior of production code rather than re-computing arithmetic locally.

**Why:** The current test only checks `perShare = amount / (n+1)` computed inside the test itself, without asserting on any output field from `ParsedExpenseResult` that would fail if parsing logic regressed.

**Source:** `test/parsed_expense_result_test.dart`.

---

## Additional codebase gaps observed

### A) Tooling gap: local Flutter/Dart checks are not executable in this environment
- `dart analyze` and `flutter --version` both fail because the executables are not present.
- This blocks automated static-analysis and test verification in the current environment.

### B) Parser resilience gap: broad fallback in `parse()` masks semantic rejects
- The parser intentionally raises for reject outcomes, but a later broad `catch` can convert the same input to a constrained fallback result if it contains numbers.
- This can persist entries that the parser intended to reject.

### C) Documentation freshness gap
- `docs/architecture/ARCHITECTURE.md` says "Current structure (HEAD)" but includes stale top-level paths and file counts that do not match the current repository state.
- This can mislead onboarding and architectural reviews.

### D) Test assertion gap in parser suite
- The "even split general rule" test currently re-derives arithmetic from local variables and does not assert a production-computed split artifact, reducing regression-detection value.
