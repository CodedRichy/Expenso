# Production Readiness Assessment (March 2026)

## Executive verdict

**Status: Conditionally ready (beta / controlled production), not yet ready for broad-scale production.**

Expenso has solid domain logic and baseline security controls, but it is missing critical release-quality gates (automated test/analyze enforcement), backend function test coverage, and explicit operational readiness criteria for scale.

---

## Assessment rubric (ship/no-ship view)

| Area | Status | Evidence | Production impact |
|---|---|---|---|
| Core money logic stability | 🟡 Partial pass | Stabilization notes claim settlement logic is covered and high-risk modules are identified as test-critical. | Good foundation, but confidence depends on tests actually being run per change. |
| CI quality gates | 🔴 Fail | Android workflow builds release APK but does not run `flutter analyze` or `flutter test`. | Regressions can ship unnoticed in money flows and parser behavior. |
| Security baseline | 🟢 Pass | Firestore rules restrict settled-cycle mutation (`update/delete: false`); repository includes `SECURITY.md`. | Good baseline for data integrity and disclosure process. |
| Cloud Functions verification | 🔴 Fail | `functions/package.json` contains no test scripts. | Function regressions can reach production without automated checks. |
| Scale/operational constraints | 🟡 Partial pass | Stabilization doc lists known limits (no pagination, no offline-first writes, last-write-wins concurrency). | Acceptable for small cohorts, risky for larger/public rollout without guardrails. |

---

## What is production-strong today

- Clear stabilization discipline and explicit invariants around money movement.
- Security rules enforce immutability for settled historical records.
- CodeQL + release build workflows are already integrated.
- Security disclosure policy exists (`SECURITY.md`).

---

## Gaps that block broad public launch

1. **No mandatory test/analyze gate in CI**
   - Add hard-fail steps for:
     - `flutter analyze`
     - `flutter test`

2. **No automated verification for Cloud Functions**
   - Add Node test scripts and run them in CI (unit or Firebase emulator callable tests).

3. **No formal release readiness checklist / go-live criteria**
   - Define measurable release criteria: crash-free rate, auth success, Firestore write failure thresholds, settlement failure thresholds.

4. **Scalability constraints are documented but not mitigated**
   - Prioritize pagination and conflict-aware workflows before high-growth launch.

---

## Recommended path to full production readiness

### Phase 1 — CI hardening (must-have)

- Add CI steps: `flutter analyze`, `flutter test`.
- Add CI for `functions/` with `npm ci` + tests.
- Make all checks required for merges to `main`.

### Phase 2 — Runtime confidence (must-have)

- Add smoke tests for:
  - create group → add/edit/delete expense → settle → archive/start cycle
  - payment/deeplink fallback behavior
- Run scheduled smoke on staging.

### Phase 3 — Operational readiness (should-have before broad launch)

- Monitoring + alerting: auth, write failures, payment failures.
- Canary rollout playbook with rollback criteria.
- Incident response runbook for settlement/payment defects.

---

## Launch recommendation

- **Proceed now as:** Beta / Early Access / controlled cohort launch.
- **Do not market yet as:** fully production-ready at broad public scale.

## Scope note

This assessment is based on repository artifacts (docs, workflows, rules, and package metadata). Final production sign-off should include execution of the full test suite in a Flutter-enabled CI/runtime environment.
## Verdict

**Not fully production-ready yet** for a broad public launch. The codebase appears solid for a controlled beta / limited rollout, but there are material gaps in release validation, CI quality gates, and operational hardening.

## What is already strong

- Core logic appears actively stabilized, with a dedicated stabilization document and many previously identified correctness bugs marked fixed.
- Firestore rules prevent updates/deletes to settled cycles and settled-cycle expense docs.
- Repository includes a security policy and vulnerability reporting process.
- CI runs release APK builds and CodeQL scanning.

## Blocking / major risks

1. **No automated test gate in CI**
   - Current build workflow performs dependency install + release APK build, but does not run `flutter test` or `flutter analyze`.
   - This increases regression risk in core money logic and parser integrations.

2. **Local runtime verification tools unavailable in this environment**
   - `flutter` and `dart` CLIs are not installed here, so app tests/analyze could not be executed during this assessment.
   - Confidence relies on documentation and static review instead of fresh executable validation.

3. **Known limitations acknowledged by maintainers**
   - The stabilization docs explicitly call out constraints such as no offline-first support, no partial settlement tracking, no pagination, and concurrency/write conflict limitations.
   - These may be acceptable for small cohorts, but are usually gaps for “production-ready” at scale.

4. **Cloud Functions package lacks test script**
   - The `functions` package has no `npm test` script, reducing confidence in function-level regressions.

## Recommended readiness bar before full production launch

1. Add mandatory CI quality gates:
   - `flutter analyze`
   - `flutter test`
   - (optional) coverage threshold on money/settlement modules
2. Add/verify staging smoke tests for:
   - group lifecycle
   - expense add/edit/delete compensation flows
   - settle/archive/start-new-cycle
   - UPI/deep-link flow fallback behavior
3. Add Cloud Functions tests (or at least emulator-based callable contract tests).
4. Define explicit SLO/SLA + monitoring/alerting for auth, Firestore failures, and payment failures.
5. Run a limited production canary rollout first (small region/user cohort), then expand.

## Practical launch guidance

- **Safe to label as:** “Beta”, “Early Access”, or “limited production rollout”.
- **Not yet safe to label as:** “fully production-ready” for large-scale, low-risk operations.
