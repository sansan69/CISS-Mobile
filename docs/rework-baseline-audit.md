# CISS Mobile Rework Baseline Audit

Date: 30 July 2026

## Executive summary

The existing Flutter application is a useful base, but its green analyzer and
widget-test results do not cover the production-critical attendance, tracking,
offline, permission, or authentication paths. The app builds successfully, yet
several of those paths are incompatible with the current web API and Firestore
rules.

- Audit health score: **8/20 — Poor**
- Findings: **2 P0, 8 P1, 5 P2**
- Baseline checks:
  - `flutter analyze`: passed with no findings
  - `flutter test`: 12 tests passed
  - Debug Android APK build: passed

The first stabilization release must make attendance and shift tracking
authoritative, recoverable, and API-driven before more portal screens are
expanded.

## Stabilization milestone — 30 July 2026

The first rework pass resolved the two P0 attendance/tracking failures and the
route/permission defects that directly blocked those flows:

- Active shift context is encrypted on-device and reconciled with the server
  after a process or device restart.
- A recovered shift sends an immediate heartbeat and then continues on the
  three-minute foreground-service schedule.
- Successfully synced offline attendance now reconciles tracking state, so a
  queued IN can start tracking only after the server accepts it.
- Guard location writes now use the authenticated heartbeat API exclusively.
  Prohibited direct Firestore writes and the missing geofence-event route were
  removed.
- Online and queued leave submissions use the same supported endpoint.
- Forgot PIN matches the web product's administrator-assisted reset process.
- The tracking service is non-exported, and unused background-location,
  battery-exemption, Wi-Fi, activity, and boot permissions were removed.

Verification completed from a clean command run:

- `flutter analyze`: no issues.
- `flutter test`: 17 tests passed, including new Android tracking and API route
  regression checks.
- Android debug APK build: successful.
- Android API 36 emulator: fresh install and launch successful; notification
  permission, state selection, and the portal hub rendered with no fatal,
  security, foreground-service, or missing-plugin exceptions in the device log.

The remaining P1/P2 items below are retained as the ordered backlog for the next
rework phase.

## Audit health score

| Dimension | Score | Key finding |
| --- | ---: | --- |
| Accessibility | 2/4 | Material controls provide a base, but critical permission and operational states are not consistently announced or recoverable. |
| Performance | 1/4 | A second high-frequency GPS loop performs Firestore writes that the rules reject, wasting battery and network. |
| Responsive design | 2/4 | The UI is phone-oriented, but it is locked to portrait and contains many fixed dimensions without tablet validation. |
| Theming | 2/4 | Theme tokens exist, but 248 direct `Colors.*` or `Color(0x...)` usages bypass them. |
| Anti-patterns | 1/4 | Generic “modern/glass” components, bundled Inter, 11 gradients, and 6 blur effects weaken the official operational design direction. |
| **Total** | **8/20** | **Poor — stabilization and system cleanup required** |

## Anti-pattern verdict

**Fail.** The current interface has a recognizable generated-dashboard style:
glass cards, generic “modern” widgets, decorative gradients, repeated rounded
cards, and a typography choice that does not distinguish CISS. These are not
release blockers, but the shared design system should be simplified before
screen-by-screen polishing.

## P0 — Blocking

### MOB-001: Active shift tracking is not recovered

- Location: `lib/core/location/background_tracking_service.dart:130`,
  `lib/features/guard/presentation/screens/guard_attendance_screen.dart:436`
- Category: Reliability / performance
- Impact: Tracking exists only in the service's in-memory `siteContext`. An app
  process restart, device restart, or service recreation loses that context.
  A guard can remain checked in on the server while the device sends no further
  locations.
- Recommendation: Persist the active tracking context, verify it against
  `/api/guard/tracking/status` on startup, and restart the user-visible
  foreground service only for a verified open shift.

### MOB-002: Offline attendance can sync without starting tracking

- Location: `lib/features/guard/presentation/screens/guard_attendance_screen.dart:484`,
  `lib/core/sync/sync_service.dart:182`
- Category: Reliability
- Impact: An offline IN is queued. When it later syncs, the sync service removes
  the request but never starts the active-shift tracker. Attendance can be open
  while live tracking remains off.
- Recommendation: Return a typed sync result for attendance, then reconcile
  tracking state with the server after every successful attendance sync.

## P1 — Major

### MOB-003: Mobile writes location records that Firestore rules reject

- Location: `lib/core/location/background_tracking_service.dart:351`,
  `lib/core/location/live_location_service.dart:141`,
  `lib/features/guard/presentation/screens/guard_attendance_screen.dart:531`
- Evidence: `firestore.rules` sets `guardLocations` and its history writes to
  `false`; only trusted server routes may write them.
- Impact: The app retries operations that cannot succeed, adds latency and
  battery use, and logs misleading failures.
- Recommendation: Remove all mobile location writes. Use the authenticated
  heartbeat and attendance APIs as the only writers.

### MOB-004: Geofence events are posted to a route that does not exist

- Location: `lib/core/location/background_tracking_service.dart:528`
- Impact: Enter/exit alerts are silently lost.
- Recommendation: Use the authoritative `zoneStatus` returned by the existing
  heartbeat route and add a tested server alert contract later if event
  escalation is required.

### MOB-005: Forgot PIN calls a route that does not exist

- Location: `lib/core/network/mobile_repository.dart:57`,
  `lib/features/auth/presentation/guard_forgot_pin_screen.dart:35`
- Impact: Guard PIN recovery always fails.
- Recommendation: Match the current web flow: explain that an administrator
  must verify the guard and reset the PIN through the audited admin action.

### MOB-006: Offline leave requests use the wrong route

- Location: `lib/features/guard/presentation/screens/guard_leave_screen.dart:89`
- Impact: Online leave submission uses `/api/guard/leave`, while the queued
  request later posts to missing `/api/guard/leave/requests`.
- Recommendation: Queue the same route and payload used online.

### MOB-007: Admin bulk employee upload calls a missing route

- Location: `lib/core/network/mobile_repository.dart:1787`
- Impact: The administration screen can submit a request that the web backend
  cannot handle.
- Recommendation: Use the supported enrollment/import contract or add a
  validated preview-and-commit endpoint before exposing bulk upload.

### MOB-008: Android permissions and service exposure are too broad

- Location: `android/app/src/main/AndroidManifest.xml:10`,
  `android/app/src/main/AndroidManifest.xml:34`,
  `android/app/src/main/AndroidManifest.xml:44`,
  `android/app/src/main/AndroidManifest.xml:54`
- Impact: The app requests background location, battery-optimization exemption,
  and unknown-app installation from first install. The tracking service is
  exported. This increases security risk, permission abandonment, and Play
  review risk.
- Recommendation: Use a user-started location foreground service, make it
  non-exported, remove unused broad permissions, and use Play distribution for
  updates.

### MOB-009: Biometric login stores reusable PINs and passwords

- Location: `lib/core/auth/biometric_credential_store.dart:7`,
  `lib/features/auth/application/auth_controller.dart:173`,
  `lib/features/auth/application/auth_controller.dart:240`,
  `lib/features/auth/application/auth_controller.dart:336`
- Impact: The biometric prompt is only a UI gate; stored credentials are not
  cryptographically bound to biometric authentication.
- Recommendation: Use biometric authentication to unlock an existing Firebase
  session. Do not retain original PINs or passwords for replay.

### MOB-010: Offline queue can silently discard operational submissions

- Location: `lib/core/offline/offline_queue.dart:44`,
  `lib/core/sync/sync_service.dart:53`
- Impact: At 100 items the oldest request is deleted. Requests over the retry
  threshold are also deleted. Attendance, incidents, patrols, or reports can be
  lost without a visible recovery record.
- Recommendation: Never evict critical operations. Move permanently failed
  items to a visible failed queue, classify retryable errors, and require an
  explicit user/admin resolution.

## P2 — Minor

### MOB-011: Admin and client sessions bypass server session resolution

- Location: `lib/core/network/mobile_repository.dart:272`
- Impact: Role shells are created from token claims while guard and field
  officer profiles are resolved from a backend contract. This creates
  inconsistent stale-claim and client-mapping behaviour.
- Recommendation: Extend `/api/mobile/session` to resolve all supported roles
  and scopes.

### MOB-012: Sync retry decay resets failures incorrectly

- Location: `lib/core/sync/sync_service.dart:62`
- Impact: When no request has succeeded, `_lastSuccessTime == null` resets a
  failed request to retry zero, defeating the retry counter and backoff model.
- Recommendation: Store per-request next-attempt time and classify permanent
  versus transient failures.

### MOB-013: Tracking performs unnecessary 30-second GPS work

- Location: `lib/core/location/background_tracking_service.dart:409`
- Impact: It samples location and attempts prohibited Firestore writes every
  30 seconds while inside the site.
- Recommendation: Remove this loop. Add adaptive server batching only after
  movement and battery targets are defined.

### MOB-014: Critical path test coverage is absent

- Location: `test/`
- Impact: Only three test files and 258 test lines cover a 174-file application.
  None verifies tracking recovery, API route compatibility, offline sync,
  permission state, or attendance-to-tracking transitions.
- Recommendation: Add unit tests for state machines and API contracts plus
  integration tests for an entire IN → tracked shift → OUT flow.

### MOB-015: Draft storage is explicitly unencrypted

- Location: `lib/main.dart:43`
- Impact: Field reports or enrollment drafts may contain personal or operational
  information on the device.
- Recommendation: Encrypt drafts or define and enforce a strict non-sensitive
  draft schema.

## Systemic patterns

- Direct Firestore fallbacks undermine the server-authoritative design.
- Several screens encode API paths independently, allowing online and offline
  behaviour to drift.
- Broad permission onboarding happens before the user initiates the feature.
- Errors are often caught and reduced to debug output, leaving users unable to
  recover failed operational work.
- UI tokens coexist with hundreds of hard-coded visual values.

## Positive findings

- The project is organized by role and feature.
- Attendance submissions already use stable client request IDs.
- The web heartbeat validates active attendance sessions and calculates
  geofence status server-side.
- The offline queue is encrypted in its normal configuration.
- Firebase tokens are sent through authenticated routes.
- The app passes static analysis, its existing tests, and an Android debug build.
- Light and dark theme foundations already exist.

## Stabilization order

1. Fix tracking authority, recovery, and attendance reconciliation.
2. Repair broken API contracts for PIN recovery and offline submissions.
3. Replace unsafe queue eviction with visible failure handling.
4. Reduce Android permissions and remove direct APK installation.
5. Unify role session resolution.
6. Expand automated coverage for complete operational journeys.
7. Simplify and polish the shared design system after runtime correctness.
