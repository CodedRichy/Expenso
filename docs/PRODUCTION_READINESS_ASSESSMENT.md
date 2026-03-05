# Production Readiness Assessment (March 2026)

## Executive verdict

**Status: Conditionally ready — controlled beta / Early Access launch. Not yet cleared for broad public production scale.**

Expenso has solid domain logic, verified settlement math, end-to-end CI with tests and analysis, strict Firestore security rules, and a clean UX with premium micro-animations. The primary remaining gaps are operational: no monitoring/alerting, no canary rollout playbook, and no staging smoke-test suite for the complete settlement lifecycle.

---

## Assessment rubric (ship/no-ship view)

| Area | Status | Evidence | Production impact |
|---|---|---|---|
| Core money logic stability | 🟢 Pass | 187+ unit and widget tests. Settlement engine, normalization, payment routes, balance-after-settlements contract, revision lifecycle, encryption, and parser outcome all covered. | High confidence in balance correctness under normal use. |
| CI quality gates | 🟢 Pass | `build.yml` runs `flutter analyze`, `flutter test`, and release APK build on every push/PR. `functions.yml` runs `npm test` for Cloud Functions. | Regressions blocked from merging into main. |
| Security baseline | 🟢 Pass | Firestore rules: creator-only group delete; settled cycles and their expenses are read-only (`allow create, update, delete: if false`); sensitive fields encrypted at rest (optional). CodeQL + SECURITY.md in repo. | Strong data integrity and disclosure process. |
| Cloud Functions verification | 🟡 Partial pass | `functions.yml` CI runs `npm test` (via `node --test`). No test files found in `functions/test/` — the CI step runs but likely exits with no tests. | Function regressions may not be caught by CI until test cases are added. |
| Scale / operational constraints | 🟡 Partial pass | Known limits documented: no pagination, no offline-first writes, last-write-wins concurrency. Bounded loading (6-8s) prevents indefinite spinners. | Acceptable for small cohorts (< 100 users, groups < 15 members); risky for larger / public rollout. |
| Operational readiness | 🔴 Fail | No monitoring, no alerting (auth failures, Firestore write failures, payment failures), no canary rollout playbook, no incident runbook. | Silent failures in production; no early warning. |

---

## What is production-strong today

- **187+ tests** covering settlement math, balance-after-settlements contract, normalization, revision lifecycle, data encryption, parser outcomes, widget states, and app launch.
- **CI quality gates enforced** — `flutter analyze`, `flutter test`, release APK build, and Cloud Functions CI on every PR.
- **Firestore security rules deployed** — creator-only group delete; settled cycles fully immutable server-side; optional AES-GCM field-level encryption.
- **Settlement archive is Cloud Function-gated** — `settleAndRestart` atomically validates balances, copies expenses, and rotates the cycle; no client can corrupt or skip the archive.
- **Pre-release audit complete** — critical and high issues addressed; scorecard App 96/100, UI 97/100.
- **UPI intent flow removed** — only QR generation, copy UPI ID, and manual "Mark as paid" flow remain, avoiding ambiguous PSP rejections.
- **Invite-link system** — invite via `expenso://join/<groupId>` on InviteMembers screen; creator-only generation; multi-use token; token rotation via `groupId` as implicit revocation.
- **Skeleton screens** — structurally match final UI; no layout shifts on load.
- **Splash → home cross-fade** — static fade under 200ms; no scaling or visual jarring.
- **V5 animation polish** — TapScale, StaggeredListItem, FadeIn; all animations ≤ 300ms; no skipped frames reported.

---

## Remaining gaps (non-blocking for controlled beta, blocking for broad public launch)

### Gap 1 — No functional test cases for Cloud Functions

- `functions.yml` CI runs `npm test` but `functions/test/` appears to contain no test cases.
- **Action:** Add at least one Node `--test` test per exported function (`settleAndRestart`, `createRazorpayOrder`, `getUserEncryptionKey`, `getGroupEncryptionKey`). Use Firebase emulator or mock `admin.firestore()` for transaction logic.
- **Impact:** Without tests, regressions in the core settlement archive function can reach production.

### Gap 2 — No monitoring or alerting

- No crash reporting, no Firebase Performance or Crashlytics integration, no alerting on Firestore write failures or payment attempt errors.
- **Action:** Add Firebase Crashlytics (Flutter plugin); define alert thresholds for auth failure rate, Firestore error rate, and settlement function failure rate.

### Gap 3 — No canary / staged rollout playbook

- No documented procedure for staged rollout (closed beta → open beta → production), rollback criteria, or incident response for settlement defects.
- **Action:** Write a one-page staged rollout checklist and settlement incident runbook before broad public launch.

### Gap 4 — Scalability constraints not mitigated

- No pagination for groups list, expense list, or cycle history. Works for target cohort (< 15 members, < 200 expenses/cycle).
- **Action:** Add cursor-based pagination when group or expense count grows.

### Gap 5 — Date stored as string (design debt)

- Expense `date` field is a human string (`"Today"`, `"Yesterday"`, `"Feb 15"`). Timezone-fragile across locales.
- **Action:** Future schema change — store ISO timestamp, derive display string from device timezone in UI.

---

## Recommended path to full production readiness

### Phase 1 — Cloud Functions test coverage (must-have)

- Add `functions/test/settle_and_restart.test.js` and `create_razorpay_order.test.js` with at least happy-path and error-path cases.
- Ensure `functions.yml` CI finds and runs them.

### Phase 2 — Runtime confidence (must-have before broad launch)

- Add Firebase Crashlytics (Flutter).
- Define alert rules: auth > 5% failure rate, Firestore errors > 1%, settlement function errors > 0%.

### Phase 3 — Canary + operational readiness (should-have before broad launch)

- Staged rollout playbook: closed beta (≤ 50 users) → open beta (Play Store internal track) → 10% staged rollout → 100%.
- Settlement incident runbook: how to detect, triage, and roll back a settlement defect.
- Smoke test suite for the full cycle lifecycle in staging environment.

---

## Launch recommendation

| Audience | Verdict |
|---|---|
| **Controlled beta / Early Access / internal cohort (< 200 users)** | ✅ **Safe to launch now.** |
| **Open beta / public 10% rollout** | ⚠️ Add Crashlytics + Cloud Function tests first (Phase 1 + 2). |
| **Full public production launch** | 🔴 Complete all three phases + staged rollout playbook. |

## Scope note

This assessment is based on repository artifacts (docs, workflows, rules, source, and package metadata). Final production sign-off should include execution of the full test suite in a Flutter-enabled CI environment and a successful settlement round-trip in a staging Firebase project.
