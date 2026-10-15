# Astra full-stack audit — 15 October 2026

Status: audit findings established; local fixes and targeted re-review in progress. This report records the originally deployed baseline separately from subsequent local changes. No production attendance, employee, willingness, assignment or tracking data was changed by the audit.

## Scope and baseline

- Android: `edfec10..4a2e762`, 170 changed files. `4a2e762` is the 15 October checkpoint; its actual parent is `edfec10`. The wider `98578fe..4a2e762` range includes earlier 11 October checkpoint work and was not presented as all authored today.
- Web/backend: `cad17132..1ce4b100`, 91 changed files, including the 15 October duty changes, remote merge and Firebase audit/config fixes. `cad17132` itself is dated 13 October. Its attendance/auth/profile contracts were inspected where today's mobile changes depend on them.
- Firebase: read-only deployed Firestore rules, Storage rules and full composite index inventory for `ciss-workforce`.
- Working copies: isolated `redesign-continuation/CISS-Mobile` and `redesign-continuation/CISS`. Original Documents checkouts left untouched. No commit, push or deploy performed by this audit.

The acceptance checklist covered attendance independent of work orders/assignments; actual punches only in field-officer history; new TCS enrollment defaulting to adhoc; willingness closing at IST duty-day midnight without reserving capacity; night-shift semantics; Employee Directory and five-tab field-officer navigation; safe-area/loading states; permission readiness; notifications; offline owner/session integrity; server authorization and Firebase configuration.

## Findings at the deployed baseline

### A1 — P1: a completed overnight duty appears open on guard Home

`CISS-Mobile/lib/features/guard/application/open_duty_session.dart:54` originally reconstructed each punch from `dateLabel + time` and sorted those reconstructed values. The server deliberately stores an OUT under the IN's operational date (`CISS/src/lib/attendance/attendance-validation.ts:406`), and `/api/guard/attendance` serialized only that date plus HH:mm, removing the real timestamp. IN 20:05 on 14 October followed by OUT 06:10 on 15 October therefore arrived with date 14 October on both rows. The mobile sort placed OUT before IN and returned an open session after a valid checkout.

Fresh failing reproduction: `.superpowers/sdd/2026-10-15-astra-audit/attendance_contract_probes_test.dart`, first case. Expected null; received `OpenDutySession`. Corrective requirement: preserve real `reportedAt` and session identity in the DTO/model and derive current session from authoritative data; keep operational date for grouping. Any legacy fallback must not double-roll already calendar-dated rows.

### A2 — P2: same-minute punches become two incomplete shifts

`CISS-Mobile/lib/core/attendance/attendance_pairing.dart:160` originally rolled OUT to tomorrow whenever it was **not after** IN. The server rounds both times to minutes. A legitimate IN 08:00:05 and OUT 08:00:50 become 08:00/08:00 and are treated as 24 hours apart, exceeding the inferred window and producing two `missedCheckOut` pairs. This affects history totals and muster output.

Fresh failing reproduction: the second attendance contract probe expected one closed pair; received two incomplete pairs. Corrective requirement: prefer absolute timestamps, and a clock-only fallback must not interpret equality as crossing midnight.

### A3 — P2: month rollover hides a guard's still-open overnight duty

`OpenDutySessionCard` originally read `attendanceHistoryProvider`; that provider calls `fetchAttendanceHistory()` without a month argument. `CISS/src/app/api/guard/attendance/route.ts` defaults to the current IST month and filters by operational `attendanceDate`. At 02:00 on 1 November, the 31 October IN is absent from that response. The new card therefore disappears while the duty is still open. This is a source-traced contract gap; the original card tests supplied preassembled records and never exercised the month query.

Corrective requirement: a dedicated current-session/recent-duty source that spans the month boundary, separate from the displayed month history. Do not solve by silently widening the history screen's selected month.

### A4 — P2: configured shift bounds are discarded and guessed from labels

`CISS/src/app/api/attendance/submit/route.ts:781` already persists `shiftStartsAt`, `shiftEndsAt`, `shiftStartTime` and `shiftEndTime`. Both attendance DTOs omitted those fields. `CISS-Mobile/lib/core/attendance/shift_window.dart` then assumed every "Night" label means 20:00–06:00 and other labels mean 12 hours from check-in. A configured 20:00–08:00 duty is flagged overdue two hours early relative to the same grace policy; an 8-hour day duty remains counted on duty four hours too long. The plan had recorded this as an inference limitation, but it is avoidable because authoritative data already exists.

Corrective requirement: serialize and use persisted bounds before the legacy inference; add configured 8-hour/day and 12-hour/night regressions.

### A5 — P2: one inactive site breaks the entire work-order list

`CISS/src/app/api/field-officer/work-orders/route.ts:150` enriches every otherwise in-scope order with `Promise.all(tallyWorkOrderWillingness(...))`. `tallyWorkOrderWillingness` calls `resolveDutySite`, which throws 409 for an inactive site. The list builder did not filter inactive sites, so one stale future order makes all healthy orders disappear behind an error.

Fresh failing reproduction: `CISS/.superpowers/sdd/2026-10-15-astra-audit/duty-list-probe.test.ts`; inactive centre plus a healthy centre returns 409 instead of a list containing the healthy order. Corrective requirement: consistently exclude ineligible sites or isolate expected stale-row errors; preserve genuine database failures rather than suppressing them wholesale. Apply equivalent protection to admin enrichment if needed.

### A6 — P1: location monotonicity/session validity is not atomic

`CISS/src/lib/guard-tracking-persist.ts:530` reads the current pin, compares timestamps, then writes with an unconditional batch. Concurrent calls can both see the old pin: the newer call commits first, then the older call overwrites it. Similarly, the pre-resolved open-session context can become stale during a batch and a later location write can restore status `In` after checkout.

Fresh failing reproduction: `tracking-race-probe.test.ts` deliberately holds the older commit until a newer request completes; final `sampleCapturedAtMs` regresses by one minute. Corrective requirement: perform current-pin comparison and current attendance/session recheck in the same Firestore transaction as the write. Do not rely solely on context resolved before processing a 200-sample batch.

### A7 — P2: break writes can overwrite a concurrently closed session

`CISS/src/app/api/mobile/attendance/break/route.ts:73` reads attendance state and session outside a transaction; lines 147–171 later batch-write break fields. A checkout that commits between those steps leaves a closed session and OUT attendance state with `onBreak:true`. Concurrent start/stop requests can also use stale accumulated seconds.

Fresh failing reproduction: `break-race-probe.test.ts` inserts a checkout between validation and commit; the closed session ends with `onBreak:true`. Corrective requirement: transactionally read, validate and update both documents; return a business conflict when the current session changes.

### A8 — P1: buffered locations can be attributed to another guard or later session

This mobile spool predates today's checkpoint, but today's deployed batch endpoint makes its integrity relevant. `CISS-Mobile/lib/core/location/background_tracking_service.dart:236` stores the raw heartbeat payload. The file is global, without owner UID, API origin or attendance-session identity. Logout stops tracking and clears its context, but does not partition this file. `SyncService._flushTrackingSamples` sends the entire file with the currently available credentials. The backend attributes same-site samples to the current open session without verifying they were captured after that session started.

Two fresh failing reproductions:

1. `CISS-Mobile/.superpowers/sdd/2026-10-15-astra-audit/tracking_owner_probe_test.dart`: a stored prior-account sample is dispatched with guard B's bearer token.
2. `CISS/.superpowers/sdd/2026-10-15-astra-audit/tracking-session-probe.test.ts`: current session began one minute ago, sample is one hour old; backend returns accepted=1 and writes it into the current session.

Corrective requirement: persist an owner/origin/session envelope; select and dispatch only matching operations, with identity guards around asynchronous token refresh/retry; verify capture/session bounds on the server. Legacy unowned rows cannot safely be attributed and need an explicit quarantine/retirement policy. Other owners' valid pending rows must not be silently reassigned or broadly erased on logout.

## Existing requirement gaps and minor issues

- Guard Home still rendered an `Absent` monthly count (`guard_dashboard_screen.dart:251` at baseline), sourced from whole-month working days minus present days in `/api/guard/dashboard`. Guard history also had an Absent summary. This is a legacy requirement gap against recorded-attendance-only presentation; it is not evidence that the corrected field-officer aggregator still synthesizes absent rows. Remove unsupported absence presentation without altering stored punches.
- Muster PDF uses default Helvetica while emitting em dash/bullet and potentially non-Latin names. Fresh Flutter test output reports missing U+2014/U+2022 glyphs. Use a supported embedded font and visual verification; PDF-byte generation alone does not prove readable glyphs.
- Read-only production GET `/api/client/attendance` without bearer token returns HTTP 500 with `{"error":"Missing bearer token."}`. This is a pre-existing auth-error mapping defect; expected 401, not a data exposure observed in this audit.

## Fresh verification evidence

Coordinated root verification on the audited baseline:

| Check | Result |
| --- | --- |
| Flutter analyzer | clean |
| Flutter suite | 524 passed |
| Web typecheck | passed |
| Web unit suite | 109 files, 713 tests passed; 35 opt-in emulator tests excluded from this invocation |
| Web production build | exit 0; environment warnings retained in log |
| Sequential rules-emulator runs | duty 19, TCS 9, guard-location 7 passed |
| Remote main heads | web `1ce4b100`, Android `4a2e762` |
| Exact web deployment status | Vercel success for `1ce4b100` |
| 56 unauthenticated mobile route probes | 34 × 401, 20 × 405, 1 × 400, 1 × 200; no 404/5xx/network errors |
| Targeted audit regressions | 7 newly constructed assertions failed at baseline (2 attendance, 3 server lifecycle/list, 2 tracking ownership/session) |

Logs: `/tmp/ciss-astra-audit-{flutter-tests,web-tests,web-build,duty-rules,tcs-rules,location-rules}.log`; `/tmp/ciss-astra-attendance-contract-probes.log`; `/tmp/ciss-astra-server-contract-probes.log`; `/tmp/ciss-astra-tracking-{owner,session}-probe.log`; `/tmp/ciss-astra-audit-api-probes.json`.

The broad suites passing does not override the targeted failures. Audit probe fixtures use existing local fakes and deterministic interleavings; they do not send authenticated requests to production.

## Firebase deployment verification

- Fresh Firebase MCP read confirms project `ciss-workforce`.
- Deployed Firestore and Storage rule text equals the reviewed worktree text.
- All 137 repository composite index signatures match the 137 deployed indexes; all are READY, with no missing signatures, extras or continuation page.
- This includes the two client-attendance `clientName/employeeClientName + reportedAt DESC` indexes and duty/list indexes.
- Guard-location breadcrumb authorization now reads parent district; earlier mobile connection-audit statements saying the fix/routes were undeployed were corrected.
- Duty state, receipt and slot collections deny direct SDK writes. New explicit denies for server-only collections do not weaken access.
- The emulator's subcollection-list hang remains a limit: breadcrumb point reads and parent-scoped access were tested, but a successful authenticated production breadcrumb list was not demonstrated.

## Inspected component checklist and limits

| Component | Review evidence / outcome |
| --- | --- |
| Attendance independence | Server submit and FO aggregator inspected; no work-order or roster precondition added, no synthetic FO absent rows. A1–A4 expose remaining time-contract defects. |
| TCS classification | Enrollment defaults and curated-category parsing inspected. Adhoc default applies to new TCS enrollment; legacy unclassified employees deliberately require classification. No backfill was executed. |
| Willingness | Server identity/current district/category validation, IST midnight cutoff, CAS receipts, tally eligibility, response DTO and owner/origin-bound mobile queue inspected. Response writes do not reserve roster capacity or restrict attendance. |
| Assignments/rosters | Current site/employee scope, version conflict handling, duplicate slot ownership, cancellation history, notification event writes, web owner-bound batching inspected. No additional confirmed defect beyond A5 in this pass. |
| Notifications | Recipient/role/destination checks, protected workspace routing, transactionally persisted duty events, dispatch leases/retry paths and unread fallback rule shape inspected. Real-device FCM/cold-start delivery not exercised. |
| Employee Directory/navigation | Include-inactive directory versus active assignment callers, filters, profile routing, Home/Attendance/Employees/Duties/More mapping and Reports under More inspected. Existing widget/inset tests ran in full suite. |
| Permissions/device readiness | Manifest, graded permission source, advisory battery/autostart behavior, fallback settings intents, startup cache failure handling inspected. OEM permission and reboot behavior need physical-device validation. |
| Offline/tracking | Willingness ownership guards inspected; tracking spool, batch consumer, session validator and current-pin persistence traced, producing A6/A8. |
| Other new UI/platform changes | Language scope, motion/haptics primitives, address cache/navigation, device identity and release shrinker configuration inspected at component/diff level. Not every aesthetic state was rendered in this audit. |
| Firebase | Live config comparison plus sequential emulator evidence above. No live user data or notifications mutated. |

No phone was connected for this audit. Authenticated role-to-role production workflows, actual check-in/check-out, physical permission prompts, offline reboot/reconnect, OEM autostart and production breadcrumb list behavior remain unverified. The production build and synthetic tests do not prove all of these device behaviors. Final local-fix review results must be appended before claiming these findings closed.

## Local-fix review results (16 October 2026)

Local fixes for **A1–A8**, the muster-roll PDF glyphs and the Guard Home `Absent` column were reviewed in the two isolated worktrees. No commit, push or deploy was performed, and no live data was touched.

### What was verified

| Check | Mobile (`redesign-continuation/CISS-Mobile`) | Backend (`redesign-continuation/CISS`) |
| --- | --- | --- |
| Analyzer / typecheck | `flutter analyze` clean | `npm run typecheck` clean |
| Suite | `flutter test` 540 passed | `npm test` 729 passed, 35 opt-in emulator tests skipped |
| Audit reproduction probes | 3/3 pass (`attendance_contract_probes_test.dart`, `tracking_owner_probe_test.dart`) | 4/4 pass (`duty-list`, `tracking-race`, `break-race`, `tracking-session`) |
| Hygiene | `git diff --check` clean; `dart format --output=none --set-exit-if-changed` reports no remaining changes across the changed files | `git diff --check` clean; the 12 prettier-nonconforming files are the same 12 that are nonconforming at `HEAD`, so no new formatting debt was introduced |

All seven assertions that failed at the audited baseline now pass. A1/A2/A4 are carried by absolute punch timestamps plus persisted shift bounds; A3 by a previous-month-and-current-month read used only by the open-duty card; A5 by isolating a `DutyError` with code `inactive_site` (`src/lib/server/duties/scope.ts:90`) while rethrowing everything else; A6/A7 by moving every decision read into the same transaction as its write and returning a business conflict instead of a stale write; A8 by an owner-and-origin envelope on the mobile spool plus capture-time and session checks in `persistGuardLocationSample`.

### Delegation attempt

Two independent reviewer agents were spawned on the DeepSeek V4.1 Flash route per the project workflow. Neither produced a review: the backend agent never received its brief and asked for a task, and the mobile agent ran against the wrong checkout and asked an unrelated OTP question. Both were discarded. This is the third recorded failure of cross-provider task delivery on this workstream (two Astra sessions died with `stream disconnected before completion`; the earlier fallback never received its task). The review below was therefore performed in this session, and the finding it produced was fixed and re-verified as required.

### Finding and fix

**P2 — a handset clock behind the server lost the breadcrumbs it captured just after checking in.** The A8 corrective work added a session-window check to `persistGuardLocationSample`: a sample whose capture time precedes `attendanceSessions.startedAt` is rejected with 409. But the guard check-in payload (`guard_attendance_screen.dart`) does not send `reportedAtClient`, so `startedAt` is stamped from the **server** clock while samples carry the **handset** clock. Any handset running behind the server therefore lost the first minutes of breadcrumbs after each check-in, and because the batch route answers 200 with `{accepted, rejected}` and the client commits the whole chunk as delivered, those samples were dropped from the spool rather than quarantined.

Reproduced before the fix with a probe against the batch route: the same 90-second-old sample was `accepted: 1` when the session had started two minutes earlier, and `accepted: 0, rejected: 1` when it had started one minute earlier — the only difference being a 30-second gap between the two clocks.

Fixed by allowing a bounded `SESSION_BOUND_SKEW_MS` (5 minutes, matching the existing `futureToleranceMs` convention in `/api/attendance/submit`) on both session bounds, in the pre-check and in the transaction check. The A8 protection is intact: a sample from an earlier session is still rejected by the existing counter-case test (one hour before the session start). Regression test added in `src/app/api/mobile/tracking/batch/route.test.ts` ("tolerates a device clock slightly behind a server-stamped session start"); it failed before the fix and passes after, with the full backend suite and the four audit probes green.

### Residual limits

- The session bounds still depend on the two clocks agreeing to within five minutes. Sending `reportedAtClient` from the guard check-in payload, as the QR and public flows already do, would remove the coupling by expressing the window in the same time domain as the samples; that changes the trusted time source of the stored attendance record, so it is left as a product decision rather than applied here.
- A sample the server rejects on its own merits is still discarded client-side, because `_flushTrackingSamples` commits the whole chunk on any 2xx and the response carries only counts. That is the intended retirement policy for the permanent rejection causes, but the client cannot distinguish a permanent rejection from a transient one; per-sample outcomes in the batch response would close that.
- The concurrency tests (A6/A7) drive a fake Firestore with serialized transactions, so real contention and real Firestore transaction isolation are still unproven by test. The emulator and physical-device gaps recorded above are unchanged.
