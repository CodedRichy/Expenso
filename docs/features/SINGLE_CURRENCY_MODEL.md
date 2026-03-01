# Single Currency Model: Enforcement and Architecture

**Status:** Confirmed Design  
**Scope:** Parsing, Validation, Storage, and UX

To preserve absolute ledger purity and uphold the zero-sum invariants established by `MoneyMinor`, Expenso strictly enforces a **Single `baseCurrency` per Group** model. Mixed currencies within a single ledger delta introduce floating exchange rates, rounding errors, and temporal drift—all of which shatter integer-based accounting.

By hard-rejecting mismatched currencies before they enter the system, the `SettlementEngine` is guaranteed to receive homogenous, type-safe data.

---

## 1. Group Creation (The Base Currency)

Every group possesses a permanent, immutable `baseCurrency` defined at creation.

* **Initialization:** When a user creates a group, they select a standard ISO 4217 currency code (e.g., `INR`, `USD`, `EUR`). It defaults to their device's locale.
* **Immutability:** Once written to the group's metadata in Firestore, this currency code cannot be changed. All ledger arithmetic for this group is mathematically bound to this specific denomination and its ISO scale (e.g., scale 2 for USD/INR, scale 0 for JPY).

## 2. The Parser (Extraction & Defaulting)

The `GroqExpenseParserService` must be updated to act as the first line of currency detection.

* **Explicit Extraction:** The LLM prompt must be instructed to identify explicit currency markers—either symbols (`$`, `€`, `¥`, `₹`) or words ("dollars", "euros", "rupees")—and map them to their corresponding ISO 4217 code. The `ParsedExpenseResult` schema will include an optional `currencyCode` field.
* **Implicit Defaulting:** If a user provides a naked number (e.g., *"Lunch was 500"*), the parser leaves `currencyCode` null. The application layer will implicitly assume this means the group's `baseCurrency`.

## 3. Validation (The Hard Reject)

The most critical guardrail exists between the parser and the ledger. Conversion via live API is **strictly prohibited**.

* **The Check:** The application evaluates the parsed intent:
  ```dart
  final detectedCurrency = parsed.currencyCode ?? group.baseCurrency;
  if (detectedCurrency != group.baseCurrency) {
    throw GroqParserRejectException(
      'This group strictly operates in ${group.baseCurrency}. Please enter amounts in ${group.baseCurrency}.'
    );
  }
  ```
* **The Safety Net:** By triggering a `GroqParserRejectException` (which bypassed fallbacks via recent updates), the transaction is forcefully aborted. Discrepant `MoneyMinor` objects are never instantiated, ensuring the core dataset remains mathematically pure.

## 4. Storage & Processing (MoneyMinor)

Once validated, the data enters the type-safe integer environment.

* **Constructing the Delta:** The expense is persisted using `MoneyMinor(amountMinor, group.baseCurrency)`.
* **Runtime Safeguards:** Even if a mismatched currency miraculously bypassed the parser, `MoneyMinor` overloads arithmetic operators to throw an immediate exception on currency mismatch, causing a loud crash rather than silent corruption.
* **Settlement Engine:** Because the data is universally homogenous, `SettlementEngine.computeNetBalances` and `computeDebts` can blindly execute their highly-optimized, zero-sum greedy matching algorithms without any partitioning or conversion logic.

## 5. UI and UX (Guiding the User)

The interface must proactively channel user behavior so that the hard-reject rule is rarely hit.

* **Input Hinting:** The Magic Bar's placeholder text must dynamically display the group's symbol: *"Paid ₹500 for dinner..."* (if INR) or *"Paid €50 for taxi..."* (if EUR).
* **Feedback Loop:** If a user's input is rejected due to a currency mismatch, the UI surfaces the semantic rejection message clearly. The user is responsible for determining the exchange rate and entering the final `baseCurrency` amount.
* **Multi-Currency Trips:** For international trips spanning multiple currencies, the UX pattern is to create separate groups (e.g., *"Japan Trip - JPY"* and *"Japan Trip Flights - USD"*). This maintains the strict isolation required for bulletproof accounting.
