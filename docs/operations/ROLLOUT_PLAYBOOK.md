# Release & Canary Rollout Playbook — Expenso

**Owner:** Engineering Lead / Release Manager  
**Last updated:** March 2026 (v5.0.0)  
**Use for:** Every release to production, including patch releases.

---

## Philosophy

> Never ship directly to 100% of users. Every release is a canary.

Expenso handles real money. A silently broken `settleAndRestart` or balance calculation is harder to recover from than a delayed rollout. Staged rollout gives you a window to detect problems before most users see them.

---

## Prerequisite checklist (before any rollout starts)

- [ ] All CI checks pass on `main`: `flutter analyze`, `flutter test` (187+ tests), release APK build, Cloud Functions `npm test` (36+ tests)
- [ ] No open P0 or Crashlytics fatal issues unresolved from the current build
- [ ] Firebase Cloud Functions deployed and smoke-tested in staging: `firebase deploy --only functions --project expenso-staging`
- [ ] Firestore rules deployed: `firebase deploy --only firestore`
- [ ] `.env` secrets verified in CI (see `build.yml` secrets)
- [ ] `STORE_CHECKLIST.md` pre-submit steps completed
- [ ] Release notes written (Play Store long description + short changelog)

---

## Stage 1 — Internal testing (1–5 users, Day 0)

**Target:** Dev team + 2–3 trusted power users.  
**Channel:** Play Store Internal Testing track or direct APK sideload.  
**Duration:** Minimum 24 hours, or until each tester has completed a full cycle (add expenses → settle → archive).

### Success criteria

- Zero new fatal crashes in Crashlytics.
- `settleAndRestart` Cloud Function completes without error for at least 2 real settlement cycles.
- Magic Bar parses at least 5 real-world inputs correctly.
- No balance discrepancy reported by any tester.

### Go / No-Go

| Signal | Go | No-Go |
|---|---|---|
| Crashlytics fatal crashes | 0 | > 0 |
| Settlement function errors | 0 | > 0 |
| Balance wrong report | 0 reports | Any report |
| Tester blocker bugs | 0 | Any |

---

## Stage 2 — Closed Beta / Early Access (< 200 users, Day 2+)

**Target:** Invited users from pre-launch list or Play Store Closed Testing track (or TestFlight for iOS).  
**Channel:** Play Store Closed Testing track.  
**Duration:** Minimum 5 days.

### Monitoring during Stage 2

Check daily:
- Crashlytics → crash-free users rate (target: > 99.5%)
- Cloud Function → `settleAndRestart` success rate (target: 100%; any failure = P0)
- Firebase Performance → app start time p75 (target: < 3s cold start)
- Analytics → `cycle_archived` event count (confirms settlements are completing)

### Success criteria

- Crash-free user rate ≥ 99.5%
- Zero `settleAndRestart` Cloud Function errors
- No balance discrepancy reported
- p75 cold start time < 3s on mid-range Android
- Support inbox: < 2% of users report any issue

### No-Go triggers (immediately halt rollout, do not proceed to Stage 3)

| Trigger | Action |
|---|---|
| Any `settleAndRestart` error in Cloud Logging | Halt. Investigate. Hotfix before continuing. |
| Crash-free rate < 99% | Halt. Check Crashlytics for root cause. |
| Balance discrepancy report from any user | Halt. Pull transaction logs for the affected group. |
| Critical security report | Halt immediately. Follow `docs/SECURITY.md` disclosure process. |

---

## Stage 3 — Staged Production Rollout (10% → 50% → 100%, Day 7+)

**Channel:** Play Store Production track with staged rollout.  
**Platform:** Android (10% → 50% → 100%); iOS via App Store staged release (7-day rollout window).

### Day 7: Bump to 10%

1. Play Console → Expenso → Production → Edit rollout → 10%
2. Monitor for 48 hours:
   - Crashlytics: no new fatal issue types
   - Cloud Function: error rate = 0%
   - Analytics: `cycle_archived` events appear (settlements completing)
3. If No-Go trigger fires: halt rollout (Play Console → Halt rollout). Do not proceed.

### Day 9: Bump to 50%

1. Play Console → Edit rollout → 50%
2. Monitor for 48 hours (same signals as 10%)
3. Check Performance → server-side `settleAndRestart` p75 duration (target: < 10s)

### Day 11: Full rollout (100%)

1. Play Console → Edit rollout → 100% (or "Complete rollout")
2. Monitor for 72 hours post-full-rollout

---

## Rollback procedure

### When to rollback

- Crash-free rate drops below 98%
- Any confirmed settlement data loss or balance corruption
- `settleAndRestart` error rate > 0% sustained over 10 minutes

### How to rollback (Android)

1. **Halt rollout immediately:** Play Console → Production → Halt rollout
2. If needed, **demote to previous release:**  
   Play Console → Release → Production → select previous build → Rollout → 100%
3. **Communicate:** Post incident note in internal Slack / notify affected Beta users

### How to rollback Cloud Functions

```bash
# List function versions in Cloud Console, then redeploy previous source
git checkout <previous-tag>
firebase deploy --only functions
```

> **Note:** Cloud Functions rollback does NOT un-archive already-settled cycles. Firestore data is preserved. The function change only affects future `settleAndRestart` calls.

---

## Settlement incident runbook

### Detecting a settlement defect

Signs in Crashlytics/Cloud Logging:
- Non-fatal error: `settleAndRestart failed — Member X has unsettled balance of N`
- Or: "There are unpaid or disputed payment attempts."
- Or: Firestore transaction conflict / aborted

### Investigation steps

1. Get `groupId` from the error log or affected user report.
2. In Firestore Console, inspect:
   - `groups/{groupId}` — check `cycleStatus`, `activeCycleId`
   - `groups/{groupId}/expenses` — are expenses still present (archive failed)?
   - `groups/{groupId}/settled_cycles/{cycleId}/expenses` — did archive succeed?
   - `groups/{groupId}/payment_attempts` — are there unconfirmed attempts?
3. Determine if the archive was partial (expenses copied but active cycle not rotated) by checking both paths.

### Recovery options

| Scenario | Recovery |
|---|---|
| Function errored before writes — no data change | User retries; data is clean. |
| Function errored mid-transaction — Firestore rolled back | No partial writes (Firestore transaction). Data clean. |
| Bug caused unconfirmed attempt to be counted as settled | Manually update attempt status in Firestore Console (requires admin access). |
| Expenses archived but cycle not rotated | Set `cycleStatus: 'settling'` and `activeCycleId` back to old value; re-run function. |

> **Principle:** Prefer doing nothing and letting the user retry. The function is idempotent for the zero-expense case, but not safe to double-run if archive was partially applied. When in doubt, restore from PITR backup.

---

## Post-rollout tasks

- [ ] Tag the release in git: `git tag v5.x.x && git push --tags`
- [ ] Update `APP_BLUEPRINT.md` version reference if major
- [ ] Archive monitoring baseline: record p50/p75 for cold start, `settleAndRestart` duration, crash-free rate at 100% rollout
- [ ] Close the `STORE_CHECKLIST.md` pre-submit items as done
- [ ] Write 1-sentence summary in `docs/architecture/DEVELOPMENT.md` if notable

---

## Contact / escalation

| Role | Responsibility |
|---|---|
| Engineering Lead | Release go/no-go decision, settlement incident investigation |
| On-call Dev | Daily monitoring checks during staged rollout |
| Firebase Support | Firestore PITR restore, auth issues |
