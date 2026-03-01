# Production Readiness Assessment (March 2026)

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
