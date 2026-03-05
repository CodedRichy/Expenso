# Monitoring & Alerting — Expenso

**Owner:** Engineering Lead  
**Last updated:** March 2026 (v5.0.0)

---

## Overview

Expenso uses Firebase Crashlytics, Firebase Performance Monitoring, and Firebase Analytics as its monitoring stack. Alerts fire to the team before users notice. This document defines what we watch, thresholds, and response steps.

---

## 1. Crash reporting (Firebase Crashlytics)

**SDK:** `firebase_crashlytics ^4.3.2`

**What is captured automatically:**
- All Flutter framework errors via `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`
- All async / Dart isolate errors via `PlatformDispatcher.instance.onError`
- Native Android / iOS crashes

**Enabled in:** `lib/main.dart` — enabled at startup after `Firebase.initializeApp()`.

**Firebase Console:** Firebase Console → Crashlytics → Expenso project.

### Alert thresholds

| Alert | Threshold | How to set up |
|---|---|---|
| **New fatal crash** | Any new crash type not seen in previous 7 days | Crashlytics → Alerts → "New issue" |
| **Crash-free users degraded** | Users < 99.5% crash-free | Crashlytics → Alerts → Velocity alert |
| **Crash velocity spike** | > 10 crashes in 30 min for a single issue | Crashlytics → Alerts → Velocity alert |

**Set up in Firebase Console:**  
Crashlytics → Project Settings → Integrations → Enable email alerts for new issues and velocity alerts.  
Or use Firebase Alerts → Cloud Monitoring to route to Slack/PagerDuty.

### Annotation (manual reporting)

For non-fatal domain errors (e.g. settlement balance mismatch, Cloud Function call failure), call:

```dart
// Non-fatal — visible in Crashlytics but does not count as crash
FirebaseCrashlytics.instance.recordError(
  exception,
  stackTrace,
  reason: 'settleAndRestart failed',
  fatal: false,
);
```

**Priority annotation sites (add these):**
- `CycleRepository.archiveAndRestart()` — on Cloud Function call failure
- `GroqExpenseParserService.parse()` — on non-rate-limit API failure
- `FirestoreService` — on write failure after offline guard

---

## 2. Performance monitoring (Firebase Performance)

**SDK:** `firebase_performance ^0.10.0+8`

**What is captured automatically:**
- All HTTP requests (Groq API, Razorpay, Firebase Functions calls) — response time, success/failure rate
- App startup time (cold start, warm start)
- Screen rendering (slow frames, frozen frames)

**Enabled in:** `lib/main.dart` — `FirebasePerformance.instance.setPerformanceCollectionEnabled(true)`

**Firebase Console:** Firebase Console → Performance → Expenso project.

### Alert thresholds

| Metric | Alert threshold | Action |
|---|---|---|
| **App start time** (cold) | > 4s p75 | Profile render pipeline; check blocking operations in main() |
| **Groq API response time** | > 5s p75 | Check Groq status; consider caching or fallback |
| **Cloud Function `settleAndRestart` duration** | > 8s p75 | Check Firestore transaction size; add index |
| **Slow frame rate** | > 5% slow frames | Switch to Flutter DevTools timeline; find hot rebuild |

**Set up custom traces (add these for settlement-critical paths):**

```dart
final trace = FirebasePerformance.instance.newTrace('settle_and_restart');
await trace.start();
try {
  final result = await callable.call({'groupId': groupId});
  trace.setMetric('success', 1);
  return result;
} catch (e) {
  trace.setMetric('error', 1);
  rethrow;
} finally {
  await trace.stop();
}
```

---

## 3. Firebase Analytics (events)

**SDK:** `firebase_analytics ^11.4.2`

Already enabled at startup. `FirebaseAnalyticsObserver` in `MaterialApp.navigatorObservers` logs all screen transitions automatically.

### Key custom events to add

| Event | When | Parameters |
|---|---|---|
| `expense_added` | On successful `addExpense` | `group_id`, `split_type`, `amount_major` |
| `magic_bar_used` | On successful Magic Bar parse | `parse_confidence`, `split_type` |
| `settlement_started` | On `settleAndRestartCycle` | `group_id` |
| `cycle_archived` | On `archiveAndRestart` success | `group_id`, `expense_count` |
| `payment_confirmed` | On receiver confirmation | `group_id`, `amount_major`, `method` (upi/cash) |

---

## 4. Cloud Function monitoring

Cloud Functions emit structured logs to Google Cloud Logging automatically.

### Alert rules (set in Google Cloud → Alerting)

| Signal | Threshold | Priority |
|---|---|---|
| `settleAndRestart` error rate | > 0% over 5 min | P0 — settlement is the core write; any failure blocks cycle rotation |
| `settleAndRestart` execution count | < 1 per day (when users are active) | P1 — might indicate the button is broken silently |
| `createRazorpayOrder` error rate | > 5% over 15 min | P1 — Razorpay optional; investigate key config |

**How to set up:**
1. Google Cloud Console → Logging → Logs Explorer → filter: `resource.type="cloud_function" AND resource.labels.function_name="settleAndRestart" AND severity>=ERROR`
2. Create "Log-based metric" from this query.
3. Creating alerting policy on the metric with threshold = 0 errors / 5 min window.

---

## 5. Firestore safety alerts

| Signal | Alert |
|---|---|
| Unusual delete on `settled_cycles` | Firestore rules already deny client deletes. Add Cloud Logging alert on any Admin SDK delete of `settled_cycles` (Cloud Function bug) |
| Write spike on `groups` collection | > 100 writes/min may indicate runaway loop; alert via Cloud Monitoring |

---

## 6. Incident response quick-reference

### Settlement defect (balance mismatch / lost expenses)

1. Check Crashlytics for `settleAndRestart failed` non-fatal events — look at frequency and stack.
2. Check Cloud Logging for `settleAndRestart` errors — look at error message for which guard fired.
3. **Do not roll back** `settled_cycles` data manually. Request investigation trace with `groupId` + `cycleId`.
4. If data was corrupted, restore from Firestore `settled_cycles` backup (Point-in-Time Recovery — enable PITR in Firebase Console).

### Auth failure spike

1. Check Firebase Auth → Usage for OTP send failures.
2. Check Crashlytics for auth-related crashes.
3. If > 5% failure rate: verify Phone Auth is enabled in Firebase Console; check App Check configuration.

### Magic Bar unavailable

1. Check Crashlytics for `GroqRateLimitException` or HTTP timeout non-fatals.
2. Check Groq status page: `status.groq.com`.
3. Magic Bar failure is non-blocking — manual entry still works. Communicate ETA via in-app message if extended.

---

## Summary of setup tasks

- [x] Crashlytics SDK added (`pubspec.yaml`, `main.dart`)
- [x] Performance Monitoring SDK added (`pubspec.yaml`, `main.dart`)
- [ ] Enable Crashlytics alerts in Firebase Console (new issue + velocity)
- [ ] Add Cloud Monitoring log-based metric for `settleAndRestart` errors
- [ ] Add `recordError` calls in `archiveAndRestart`, parser, and Firestore write paths
- [ ] Add custom `FirebasePerformance` traces around `settleAndRestart` and Groq API calls
- [ ] Add key Analytics events (`expense_added`, `cycle_archived`, `payment_confirmed`)
- [ ] Enable Firestore Point-in-Time Recovery (PITR) in Firebase Console
