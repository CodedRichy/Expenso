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
