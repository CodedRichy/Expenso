# Terminal Errors Log

Notes from `flutter run` on device AIN065 (Nothing phone). Build succeeded (exit code 1 was from "Lost connection to device" / batch terminate), but the following errors and warnings appeared in the log.

---

## Build (Gradle / Java)

| What | Detail |
|------|--------|
| Source/target 8 obsolete | `warning: [options] source value 8 is obsolete and will be removed in a future release` (same for target). Use `-Xlint:-options` to suppress, or bump Java version in Gradle. |
| Razorpay deprecation | `RazorpayDelegate.java` uses deprecated API. Recompile with `-Xlint:deprecation` for details. |

---

## Device / vendor (Nothing / AIN065)

| What | Detail |
|------|--------|
| Invalid resource ID 0x0 | `E/example.expenso: Invalid resource ID 0x00000000` with `Resources$NotFoundException: String resource ID #0x0`. From `NothingExperience.getAppName()` — Nothing Experience SDK expects an app name resource the Flutter app doesn’t provide. Device/vendor issue, not app logic. |
| NtQueueManager logs | Repeated `NtQueueManager: Clear queue, clearCondition: Closure: (NtTask) => bool` — Nothing system logging. |
| userfaultfd MOVE ioctl | `userfaultfd: MOVE ioctl seems unsupported: Connection timed out` — kernel/device quirk. |
| Choreographer | `Skipped 40 frames! The application may be doing too much work on its main thread` — possible startup jank; worth profiling if UI feels slow. |

---

## Google Play Services / GMS

| What | Detail |
|------|--------|
| GoogleApiManager DEVELOPER_ERROR | `Failed to get service from broker` with `SecurityException: Unknown calling package name 'com.google.android.gms'`. Often means debug build / device not recognized in Google Cloud Console (e.g. SHA-1 not added, or Play Services mismatch). |
| FlagRegistrar / Phenotype.API | `Phenotype.API is not available on this device. ConnectionResult{statusCode=DEVELOPER_ERROR}` — same GMS/config theme; Firebase/GMS not fully validated for this build. |
| ProviderInstaller | `Failed to load providerinstaller module` (local/remote version 0). `Failed to report request stats` — GMS security provider; common on some devices/emulators. |
| DynamiteModule | `Local module descriptor class for com.google.android.gms.providerinstaller.dynamite not found` — GMS dynamic loading; often benign on debug devices. |

---

## Firebase

| What | Detail |
|------|--------|
| X-Firebase-Locale null | `Ignoring header X-Firebase-Locale because its value was null` — Firebase client sending null locale; harmless. |
| App Check | `Error getting App Check token; using placeholder token instead. No AppCheckProvider installed` — App Check not configured; backend may accept placeholder in dev. For production, configure App Check. |
| Firestore bloom filter | `Applying bloom filter failed: (Invalid hash count: 0); ignoring the bloom filter and falling back to full re-query` — Firestore client fallback; no change needed unless you see performance issues. |

---

## Session end

| What | Detail |
|------|--------|
| Lost connection to device | App was running then connection to AIN065 was lost (e.g. USB, device sleep, or process killed). Terminal then prompted "Terminate batch job (Y/N)?". |

---

## Summary

- **App / project:** Razorpay deprecation warning; Java 8 obsolete warnings in Gradle.
- **Device / vendor:** Nothing SDK resource ID, NtQueueManager logs, userfaultfd, possible main-thread jank.
- **Google / Firebase:** GMS DEVELOPER_ERROR (package/SHA/config), App Check placeholder, Firestore bloom fallback, null locale — mostly config/device recognition.
- **Session:** Run ended with lost connection to device.

Add new entries to this file as new errors show up in the terminal.

---

## Follow-up (to investigate)

- **Balance / settlement logic** — User reported problems; details to be provided later.
