# Agent: Expenso AI System

This document defines how AI agents should interact with the Expenso repository.

## 🧠 Memory Protocol

Agents must prioritize the documentation in `/docs` over raw file scanning for context.

1. **Read First**: Always start with `project_memory.md` to understand purpose and status.
2. **Architecture**: Refer to `architecture.md` before making structural changes.
3. **Tasks**: Check `tasks.md` before proposing new features.

### Rules:
- **Do NOT** read the entire repo first; use the memory files as primary context.
- **Do NOT** duplicate existing functionality; check the "Key Components" in `project_memory.md`.
- **Maintain Consistency**: Ensure all new implementations align with the "Neo-Minimalist" design system and "Repository-driven" architecture.

---

## 🔁 Command: `UPDATE_MEMORY`

When this instruction is given, the AI must:

1. **Scan**: Analyze recent code changes, release notes, and documentation.
2. **Consolidate**: Update the 3 primary files:
   - `project_memory.md`: Reflect new features, tech stack changes, or status updates.
   - `dev_log.md`: Add a concise summary of the latest updates.
   - `tasks.md`: Mark completed tasks and add newly identified gaps.
3. **Summarize**: Keep descriptions high-signal, minimal, and structured.
4. **Purge**: Remove any outdated or redundant information.

---
*Updated: April 2026*
