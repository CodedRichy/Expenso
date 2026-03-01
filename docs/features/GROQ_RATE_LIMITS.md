# Groq API Rate Limits

Reference for rate limits and handling when using the Groq API (e.g. Magic Bar / `GroqExpenseParserService`). Limits apply at the **organization** level; you hit whichever threshold is reached first.

## Metrics

| Abbreviation | Meaning |
|--------------|--------|
| RPM | Requests per minute |
| RPD | Requests per day |
| TPM | Tokens per minute |
| TPD | Tokens per day |
| ASH | Audio seconds per hour |
| ASD | Audio seconds per day |

Cached tokens do not count toward limits.

**Example:** If RPM = 50 and TPM = 200K, sending 50 requests with 100 tokens each in one minute hits the **RPM** limit first, even though token usage is below 200K.

## Model used by Expenso

We use **`meta-llama/llama-4-scout-17b-16e-instruct`** for expense parsing (via Groq).

| Plan | RPM | RPD | TPM | TPD |
|------|-----|-----|-----|-----|
| Free | 30 | 1K | 12K | 100K |
| Developer (base) | 30 | 1K | 12K | 100K |

Higher limits are available for select workloads and enterprise. See [Groq limits page](https://console.groq.com) for your organization’s exact values.

## Rate limit headers

Response headers (values are illustrative):

| Header | Refers to | Notes |
|--------|-----------|--------|
| `retry-after` | Seconds to wait | **Only set on 429.** Use for backoff before retry. |
| `x-ratelimit-limit-requests` | RPD | Daily request limit |
| `x-ratelimit-limit-tokens` | TPM | Per-minute token limit |
| `x-ratelimit-remaining-requests` | RPD | Remaining today |
| `x-ratelimit-remaining-tokens` | TPM | Remaining this minute |
| `x-ratelimit-reset-requests` | RPD | Time until daily reset |
| `x-ratelimit-reset-tokens` | TPM | Time until token bucket reset |

## Handling 429

When a limit is exceeded, the API returns **429 Too Many Requests**. The `retry-after` header (in seconds) indicates how long to wait before retrying.

**In Expenso:** `GroqExpenseParserService` uses **proactive throttling** (minimum 2 seconds between requests) so rapid Magic Bar sends are spaced out. On 429 it retries once after waiting; it uses `retry-after` when present (clamped to a reasonable range), otherwise defaults to 2 seconds. If the retry also returns 429, we throw `GroqRateLimitException` and the Magic Bar shows a 30s cooldown and suggests manual entry. See `lib/services/groq_expense_parser_service.dart` and APP_BLUEPRINT § GroqExpenseParserService. The CLI (`tool/parser_cli.dart`) uses the same 2-second minimum interval and a file-based timestamp for batch runs.
