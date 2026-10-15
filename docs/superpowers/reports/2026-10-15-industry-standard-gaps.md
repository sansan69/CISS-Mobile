# Industry-standard gaps in CISS Workforce mobile — 15 October 2026

Audit of the current checkout (`wip/redesign-1.0.21` worktree) against what comparable mobile workforce apps ship, with GitHub references found by repository search on 15 Oct 2026. "Verified here" means I inspected the file/manifest in this repo; "reference" means the linked project implements the pattern today.

## 1. Attendance integrity is inferred server-side only

Verified here: the app has no device-side tamper signal. `isMockLocationSuspected` / `mockLocationReason` arrive as fields on the attendance payload (`lib/core/models/mobile_dashboard_models.dart:318`) and are only rendered as a warning (`field_officer_guard_detail_screen.dart:773`). There is no Play Integrity / app-attestation call anywhere, so a rooted device with a GPS-spoofing app is indistinguishable from a normal phone at the edge of the client's network.

How modern attendance apps do it: request a Play Integrity verdict at check-in and send the token with the punch, so the server scores the device as well as the location.

- Reference: [rexRUBY/app_integrity_attestation](https://github.com/rexRUBY/app_integrity_attestation) — Flutter client + backend verification of Play Integrity verdicts.
- Reference: [talsec/Free-RASP-Flutter](https://github.com/talsec/Free-RASP-Flutter) — RASP kit covering root/jailbreak, hooking, debugger, repackaging and emulator checks, with a Flutter integration path.

## 2. Release build is not hardened

Verified here: the release build type sets only a signing config — no R8/minify, no resource shrinking, no `--obfuscate`/`--split-debug-info` (`android/app/build.gradle.kts:49-64`), and `targetSdk = 34` with `minSdk = 24`. Shipped code keeps readable symbol names, and Crashlytics stack traces are not de-minified because no symbol file is uploaded.

Verified here: no screen-capture protection. Payslips, Aadhaar-adjacent document screens and the employee directory (`docs/`, `guard_document_upload_screen.dart`) can be screenshotted by any app with media access.

- Reference: [prongbang/screen_protector](https://github.com/prongbang/screen_protector) — Flutter plugin setting Android `FLAG_SECURE` and the iOS capture guard, per screen.
- Reference: [prongbang/ScreenProtectorKit](https://github.com/prongbang/ScreenProtectorKit) — the native library behind it.

## 3. Offline queue without a sync/conflict model

Verified here: Hive-backed `OfflineQueue` plus per-feature queues (`lib/core/offline/willingness_queue.dart`, `draft_service.dart`) replay writes, and there is no reconciliation step — no server-ack driven merge, no per-record version/`expectedVersion` handling in the client, and no periodic background sync (`workmanager` is absent from `pubspec.yaml`). Duty willingness writes carry a request UUID (idempotent, good), but attendance/draft replay has no equivalent contract.

How modern apps do it: a local database plus a sync engine that owns push/pull, retries with backoff and conflict rules, so the UI reads local state and never blocks on the network.

- Reference: [powersync-ja/powersync.dart](https://github.com/powersync-ja/powersync.dart) — Flutter/Dart client for a local-first sync engine (SQLite + sync rules + conflict resolution); companion service repos are under the same org.
- Reference: [itsezlife/flutter-instagram-offline-first-clone](https://github.com/itsezlife/flutter-instagram-offline-first-clone) — worked example of an offline-first Flutter app with local cache and queued mutations.

## 4. Large-list reads are unpaginated

Verified here: the employee directory loads the entire roster in one future (`fieldOfficerGuardsProvider` → `fetchFieldOfficerGuards(includeInactive: true)`) and renders it with `ListView` children built from a list; the real roster in the field-officer screenshot was 315 employees. There is no cursor/page parameter in the repository call, so memory and payload grow with the client's headcount, and search/filter runs entirely on the client.

- Reference: [EdsonBueno/infinite_scroll_pagination](https://github.com/EdsonBueno/infinite_scroll_pagination) — the standard Flutter package for lazy paged lists.
- Reference: [ftognetto/riverpod_infinite_scroll](https://github.com/ftognetto/riverpod_infinite_scroll) — the same pattern wired to Riverpod, which this app already uses.
- Reference: [JohannesMilke/firebase_pagination_example](https://github.com/JohannesMilke/firebase_pagination_example) — Firestore cursor pagination example.

## 5. Domain workflows absent (compared with HRMS suites)

Verified here, none of these exist in the app: attendance regularization / missed-punch appeal, shift-clash and rest-period validation when duties are assigned, roster templates with rotation, and overtime computation. Duty assignment is count-based (`field_officer_work_orders_screen.dart`, `assignment_editor_sheet.dart`), and attendance is deliberately decoupled from assignment — but nothing validates that a guard is not double-booked or rostered beyond legal hours.

- Reference: [frappe/hrms](https://github.com/frappe/hrms) — the closest open-source peer to this domain: geo/selfie check-in, shift types and shift assignment, attendance regularization, leave, expense and payroll, with a Flutter mobile app in the same repository. Worth reading as the reference model for the backend siblings.

## 6. Safety and localization for the actual workforce

Verified here: no panic/SOS surface with live-location escalation to a supervisor or control room ("emergency" appears only in an onboarding string and a tool list), and no localization at all — `lib/l10n` does not exist, `flutter_localizations` is not a dependency, and the UI is English-only for a Malayalam/Hindi/Tamil-speaking guard population. Also: no lone-worker check-in timer for night posts.

- Reference: [frappe/hrms](https://github.com/frappe/hrms) — includes shift/attendance surfaces that are localized per-user (`language` field on the employee record), a pattern this app can copy rather than invent.

## 7. Delivery: sideloaded APK instead of signed distribution + OTA

Verified here: updates are distributed by downloading an APK and triggering the system installer (`REQUEST_INSTALL_PACKAGES`, `lib/core/update/app_update_gate.dart`), with a single GitHub Actions workflow `build-apk.yml`. That keeps `installUnknownApps` on every guard's phone, cannot be staged by cohort, and gives no deobfuscated crash symbols.

- Reference: `shorebirdtech/setup-shorebird` (and its marketplace validation forks returned by today's search, e.g. [actions-marketplace-validations/shorebirdtech_setup-shorebird](https://github.com/actions-marketplace-validations/shorebirdtech_setup-shorebird)) — the CI action for Shorebird, which patches Dart code over the air for released Flutter apps.
- Reference: [EdsonBueno/infinite_scroll_pagination](https://github.com/EdsonBueno/infinite_scroll_pagination) style small, single-purpose packages are the norm; the equivalent for distribution is Play-managed in-app updates once the app is published.

## 8. Engineering hygiene that modern Flutter apps treat as baseline

Verified here: strong on unit/widget tests (387 passing) and Riverpod structure; missing: `integration_test/` (absent), golden tests wired into CI (only a local probe exists), image disk caching (`cached_network_image` is not a dependency; avatars use `NetworkImage`), client-side image compression/EXIF stripping before upload, analytics/performance monitoring (Crashlytics only, no breadcrumbs or traces), and accessibility checks beyond widget semantics.

Priority order I would take, by risk to the business: attendance integrity (1) → release hardening and screen protection (2) → offline conflict handling (3) → pagination (4) → regularization and roster rules (5) → SOS and localization (6) → distribution and OTA (7) → hygiene (8).
