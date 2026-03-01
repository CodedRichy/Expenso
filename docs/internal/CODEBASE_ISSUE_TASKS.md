# Codebase issue tasks and gaps (proposed)

## Requested 4 tasks

### 1) Typo fix task
**Task:** Rename the test title `partial success: valid amount with empty description yields description in fromJson` to a clearer sentence (for example: `... yields empty description from fromJson`).

**Why:** The phrase "description in fromJson" is grammatically incorrect and makes test reports harder to scan.

**Source:** `test/parsed_expense_result_test.dart`.

**Status:** ✅ Addressed — test name now reads `partial success: valid amount with empty description yields empty description from fromJson`.

### 2) Bug fix task
**Task:** Prevent parser `reject` outcomes from being silently converted into a fallback parsed expense.

**Why:** `parse()` throws when `parseConfidence == 'reject'`, but the outer `catch` currently attempts `_fallbackParse(userInput)` for any exception. Inputs like "I owe B 500 tomorrow" can therefore be incorrectly accepted because they contain a number.

**Source:** `lib/services/groq_expense_parser_service.dart`.

**Status:** ✅ Addressed — `parseConfidence == 'reject'` now throws `GroqParserRejectException`, which is explicitly excluded from the broad fallback catch so semantic rejects never become fallback expenses.

### 3) Comment/documentation discrepancy task
**Task:** Update architecture docs so top-level directory listings match the current repository.

**Why:** `docs/architecture/ARCHITECTURE.md` still lists files/directories such as `BUGS_FIXED.md`, `BUG_REPORT.md`, and `figma` as top-level items, but they are not present in the current repo tree.

**Source:** `docs/architecture/ARCHITECTURE.md` vs current repository file list.

**Status:** ✅ Addressed — `docs/architecture/ARCHITECTURE.md` “Current structure (HEAD)” section now reflects the real git-tracked top-level entries and counts from `git ls-files`.

### 4) Test improvement task
**Task:** Strengthen `even split general rule` test to validate behavior of production code rather than re-computing arithmetic locally.

**Why:** The current test only checks `perShare = amount / (n+1)` computed inside the test itself, without asserting on any output field from `ParsedExpenseResult` that would fail if parsing logic regressed.

**Source:** `test/parsed_expense_result_test.dart`.

**Status:** ✅ Addressed — the test now asserts parsed `amount`, `splitType`, `participantNames`, and that `exactAmountsByName` / `percentageByName` / `sharesByName` remain empty for even splits.

---

## Additional codebase gaps observed

### A) Tooling gap: local Flutter/Dart checks are not executable in this environment
- `dart analyze` and `flutter --version` both fail because the executables are not present.
- This blocks automated static-analysis and test verification in the current environment.

### B) Parser resilience gap: broad fallback in `parse()` masks semantic rejects
- **Status:** ✅ Addressed — semantic rejects now throw `GroqParserRejectException`, which bypasses fallback; only transport/JSON/validation errors can trigger `_fallbackParse`.

### C) Documentation freshness gap
- **Status:** ✅ Addressed — `docs/architecture/ARCHITECTURE.md` “Current structure (HEAD)” and module table are now generated from the current `git ls-files` output.

### D) Test assertion gap in parser suite
- **Status:** ✅ Addressed — the "even split general rule" test now asserts on `ParsedExpenseResult` fields (amount, splitType, participants, and absence of exact/percentage/share maps) instead of only recomputing local arithmetic.
