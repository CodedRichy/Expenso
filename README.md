# Expenso

**System-driven group expense management.**

Expenso is a group-centric expense ledger designed to eliminate the social friction of shared spending.

Unlike traditional split-based apps, Expenso is built around **settlement cycles**, **centralized authority**, and a **system-enforced workflow** that removes the need for manual reminders or personal enforcement.

---

## Key concepts

### NLP-driven expense entry

Expenses are logged using natural language input. The system parses amounts, participants, and context to reduce interaction cost and errors.

### Creator-authority model

Each group has a designated creator with elevated permissions to manage cycles, enforce settlements, and maintain ledger integrity.

### Two-phase settlement engine

Cycles transition through a controlled lifecycle (**Active → Settling → Closed**), ensuring expenses are frozen and verifiable before archival.

### System-first architecture

Business rules live in a centralized repository layer, not in UI widgets, enabling predictable behavior and future backend integration.

### Minimal, high-contrast UI

The interface is designed for speed, clarity, and trust, prioritizing readability over decorative elements.

---

## Status

This repository implements the full UI and in-memory domain logic, serving as a foundation for future persistence, payments, and multi-device sync.

**Stack:** Flutter (Dart), Material 3.

For implementation details, routes, and conventions, see **[APP_BLUEPRINT.md](APP_BLUEPRINT.md)**.

---

## License

Proprietary. All rights reserved. This source code is for **viewing only**; no use, copy, or distribution without permission. See [LICENSE](LICENSE).
