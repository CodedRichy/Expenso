# Path to 100+ and 110% Success — Expenso

**Goal:** Be the best expense tracker app. Scorecard at 100/100 and beyond — product, store, and positioning.

Use with [PRE_RELEASE_AUDIT.md](PRE_RELEASE_AUDIT.md) (scorecard), [REACH_90S_GUIDE.md](REACH_90S_GUIDE.md) (tactics), and [APP_BLUEPRINT.md](../../APP_BLUEPRINT.md) (§9 planned features).

---

## 1. Are we there yet?

**Current:** App **96**, UI **97** (PRE_RELEASE_AUDIT §7).

**Gap to literal 100:**

| Area | Current | To 100 | Action |
|------|---------|--------|--------|
| **App – Functionality** | 23/25 | 25 | Remove or mitigate known limits: e.g. pagination for one list (history or expenses), or document “designed for typical use” and call it complete. |
| **App – Performance** | 14/15 | 15 | Pagination for groups and/or expenses (or history) so large datasets don’t degrade; or bounded + retry everywhere and document. |
| **UI – Visual** | 24/25 | 25 | Design tokens on every remaining screen (SettlementConfirmation, GroupDetail remnants, EditExpense, ExpenseInput, etc.). |
| **UI – Accessibility** | 19/20 | 20 | Full pass: every interactive element and amount has Semantics; form fields have labels/hints; contrast check. |
| **UI – Empty/error** | 14/15 | 15 | One more polish pass: ensure every async failure path has a clear message + retry/back; empty states have CTAs. |

**Verdict:** You are **not** at 100 yet. You are close; the table above is the minimal path to 100/100. “110%” is about going beyond the scorecard.

---

## 2. How top expense/split apps win (research)

From public reviews, store copy, and comparisons (Splitwise, Splitty, SplitMyExpenses, Splitkaro, SplitIt):

**What users and stores reward:**

| Factor | What they do | Expenso today |
|--------|----------------|---------------|
| **Speed** | “Split in 30 seconds”, minimal taps | Magic Bar + confirm is fast; manual form is more steps. |
| **Clarity** | “Who owes whom” in one glance | ✅ Decision Clarity card; settlement instructions. |
| **Settlement** | Direct payment (Venmo, UPI, Paytm) | ✅ UPI picker + QR; payer/receiver confirmation. |
| **Debt simplification** | Fewer transactions (A→B, B→C → A→C) | ✅ God Mode / debt minimization (V4). |
| **Receipt / scan** | Photo → items → assign to people | ❌ Not built. Planned in APP_BLUEPRINT §9.1 (receipt attachments, scan-to-prefill). |
| **Unlimited use** | No daily cap on expenses | ✅ No artificial limits. |
| **Trust** | “No paywalls”, “data export”, privacy clear | ✅ Privacy in-app; STORE_CHECKLIST; optional encryption. |
| **UI** | “Smooth”, “intuitive”, “clean” | ✅ Strong; design tokens and a11y improving. |

**Gaps vs “best out there”:**

- **Receipt scanning / photo bills** — Competitors push this hard; you have Magic Bar (NL) but not camera → items.
- **Reminders** — Survey (SURVEY_FEATURE_REQUESTS) and competitors: cycle-based reminders so “no one has to chase”. You have nudge templates in §9.1, not implemented.
- **Export / report** — “Final report”, “statement”, “history”. You have cycle history; no CSV/PDF export yet.
- **“I paid, don’t worry”** — Survey: option to clear/write off without chasing. Not in app yet.
- **Pagination** — You load full lists; at scale, “fast and smooth” needs pagination or lazy load.

---

## 3. Path to 100/100 (scorecard)

Concrete next steps to max out the current criteria.

**App (96 → 100):**

1. **Pagination** — Add `limit` + `startAfter` (or cursor) for at least one of: groups list, expense list, cycle history. Improves Performance & stability and supports “completeness” at scale. See REACH_90S_GUIDE §6.
2. **Functionality 25** — Either (a) ship pagination + document “designed for real-world group size”, or (b) explicitly document “no pagination; optimal for &lt;N groups, &lt;M expenses per cycle” and accept 24, OR add one more “complete” feature (e.g. export) to justify 25.
3. **Testing** — Already 15; keep regression coverage and add E2E for one critical path (sign-in → group → expense → settlement) if you want extra confidence for store and reviews.

**UI (97 → 100):**

1. **Design tokens everywhere** — Replace every remaining `TextStyle(fontSize: …, color: …)` and raw colors with `context.*` and design tokens in: SettlementConfirmation, GroupDetail (all text), EditExpense, ExpenseInput, InviteMembers remnants, error/empty widgets. See REACH_90S_GUIDE §3.
2. **Accessibility 20** — Semantics on every button, link, list item, and amount; form fields with `semanticsLabel` / hint; quick contrast pass. REACH_90S_GUIDE §2.
3. **Empty & error 15** — Audit every async path; ensure message + retry or back; empty states with clear CTA.

---

## 4. 110% success — beyond the score

“110%” = **best expense tracker** in perception, retention, and store performance. That’s product + positioning + a few signature moves.

**A. Differentiators you already have**

- **Magic Bar** — Natural language → structured expense (no receipt needed for quick entry).
- **Decision Clarity card** — One place: cycle total, you paid, your status (credit/debt).
- **Cycle-based settlement** — Clear “freeze → settle → new cycle”; no endless IOU list.
- **UPI in-app** — App picker + QR; payer/receiver confirmation (no “did you pay?” ambiguity).
- **God Mode** — Debt minimization across group (fewer transactions).
- **Offline guards** — No silent failed writes; clear “you’re offline”.
- **Phone + contacts** — Invite by phone; country codes; optional contact suggestions.
- **Optional encryption** — Sensitive fields encrypted at rest.

**B. High-impact additions (recommended order)**

| # | Feature | Why 110% | Effort | Where |
|---|--------|----------|--------|--------|
| 1 | **Receipt / photo attachment** | Table-stakes in “best” comparisons; reduces arguments. | Medium–high | APP_BLUEPRINT §9.1; RECEIPT_SCANNING_AND_ML.md. Scan-to-prefill later. |
| 2 | **Cycle-based reminders** | Survey #1 ask; “no one chases” positioning. | Medium | §9.1 Nudge templates; FCM or local notifications. |
| 3 | **Export (CSV/PDF)** | “Report”, “statement”; trust and power users. | Low–medium | Cycle history → export current + past cycle. |
| 4 | **“I paid, don’t worry”** | Survey; lets one person forgive/write off their share. | Low | Settlement or expense: “Clear for me” / write-off. |
| 5 | **Pagination** | Scale and “smooth” with many groups/expenses. | Medium | REACH_90S_GUIDE §6; Firestore limit/startAfter. |

**C. Positioning and store**

- **Tagline** — e.g. “Group expenses, settled. No chase.” (reminders + clarity).
- **Screenshots** — Lead with Decision Clarity card, then Magic Bar, then UPI settlement.
- **Short description** — Include: split bills, UPI, cycle settlement, Magic Bar (or “natural language”).
- **Ratings** — After launch: in-app prompt at a happy moment (e.g. after first settlement); link to store. One prompt only, not nagging.

**D. What not to do (yet)**

- **OCR receipt → item split** — High support cost; do after receipts as attachment + manual split. APP_BLUEPRINT says do last.
- **Voice entry** — Low usage, high friction; skip for now.
- **Multi-currency** — Out of scope per STABILIZATION; document as future.

---

## 5. New recommendations summary

**To hit 100/100:**

- Add **pagination** (at least one list).
- **Design tokens** on all remaining screens.
- **Full a11y** pass (Semantics + form labels + contrast).
- **Empty/error** audit and polish.

**To aim for 110% (“best expense tracker”):**

1. **Receipt attachments** (and later scan-to-prefill) — Align with RECEIPT_SCANNING_AND_ML.md and §9.1.
2. **Reminders** — Cycle-based, system tone; aligns with survey and “no chase”.
3. **Export** — CSV/PDF for cycle or group; supports “report” and trust.
4. **“I paid, don’t worry”** — Write-off/forgive flow for one member’s share.
5. **Store listing** — Tagline, screenshots, and one rating prompt at a success moment.

**Keep doing:**

- Keep offline guards, G9 and contract tests, parser tests, widget/integration tests.
- Keep STORE_CHECKLIST and PRIVACY in sync with the app.
- Keep design system and a11y improvements with every feature.

---

## 6. References

| Doc | Use |
|-----|-----|
| PRE_RELEASE_AUDIT.md | Scorecard, critical/high items, path to 100. |
| REACH_90S_GUIDE.md | Tactics: a11y, tokens, offline, tests, pagination, locale. |
| APP_BLUEPRINT.md §9 | Planned features and order (receipts, reminders, etc.). |
| STABILIZATION.md | Invariants, limits, safe vs risky changes. |
| SURVEY_FEATURE_REQUESTS.md | User asks (reminders, “I paid”, report, receipts). |
| STORE_CHECKLIST.md | Pre/post submit and store listing. |
| docs/features/RECEIPT_SCANNING_AND_ML.md | Receipt stack when you add scan. |

---

*When you ship any of the above, update this doc and the scorecard in PRE_RELEASE_AUDIT.md.*
