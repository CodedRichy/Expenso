<p align="center">
  <strong>Expenso</strong>
</p>
<p align="center">
  <em>System-driven group expense management</em>
</p>
<p align="center">
  <sub>Flutter · Dart · Material 3</sub>
</p>

---

> Expenso is a group-centric expense ledger designed to **eliminate the social friction** of shared spending.  
> Unlike traditional split-based apps, it’s built around settlement cycles, centralized authority, and a system-enforced workflow—no manual reminders, no awkward follow-ups.

---

## What it does

| | |
|:---|:---|
| **NLP expense entry** | Log with natural language. Amounts, participants, and context are parsed automatically. |
| **Creator-led groups** | One creator per group with full control over cycles, settlements, and ledger integrity. |
| **Two-phase settlement** | Cycles move **Active → Settling → Closed** so expenses are frozen and verifiable before archival. |
| **Repository-first logic** | Rules live in the data layer, not in the UI—predictable behavior and ready for backend integration. |
| **Minimal UI** | High-contrast, fast to scan. Readability and trust over decoration. |

---

## Status

In-memory implementation with full UI and domain logic. Foundation for persistence, payments, and sync.

| | |
|:---|:---|
| **Stack** | Flutter (Dart), Material 3 |
| **Docs** | [APP_BLUEPRINT.md](APP_BLUEPRINT.md) — routes, screens, data layer, conventions |

---

## License

See [LICENSE](LICENSE).
