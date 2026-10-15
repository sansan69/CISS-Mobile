# Field-workforce parity: permissions, night shift, and the industry baseline

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app as reliable in the field as the sibling CISS-AMS build — complete permission handling, correct night-shift attendance semantics, and the plugin/industry gaps we identified — in four independently testable phases.

**Architecture:** Two new pure-Dart cores (`lib/core/permissions`, `lib/core/attendance` extensions) carry the logic and stay Flutter-free so they can be unit-tested with an injected clock and fake platform sources; Riverpod providers adapt them to the existing screens, and every new string goes through `AppStrings` (en/hi/ml) so the localization work already shipped is preserved.

**Tech Stack:** Flutter 3.29 / Dart 3.7, Riverpod, Hive, permission_handler 12, geolocator, flutter_background_service, geocoding, maps_launcher, flutter_udid, webview_flutter, `pdf`.

**Spec / evidence:** `docs/superpowers/reports/2026-10-15-ciss-ams-deep-analysis.md` (REA Evidence IDs in its ledger), `docs/superpowers/reports/2026-10-15-industry-standard-gaps.md`, `docs/superpowers/reports/2026-10-15-ciss-ams-rea-analysis.md`.

## Global Constraints

- Never write to the backend, commit, push or deploy as part of this plan; the sibling CISS web/backend project is a separate change stream.
- `flutter analyze` clean and the full `flutter test` suite green after every task; UI changes must also pass at 320 dp width and 1.8 text scale.
- Respect `test/mobile_contract_regression_test.dart`: it encodes the tracking contract. Phase 1 deliberately rewrites two of its assertions, with the disclosure copy as the replacement guarantee.
- All user-visible strings go through `AppStrings` in `lib/core/i18n/app_strings.dart` with English, Hindi and Malayalam values.
- Privileged calls (permission prompts, intents, network, settings deep links) sit behind an injectable source so widget tests never touch a platform channel.
- Time-dependent logic takes a `DateTime now` or a `clockProvider`; no `DateTime.now()` inside pure functions.

## Scope check

The four phases are independent subsystems that each produce working software, and the skill's guidance is one plan per subsystem. They are collected here because they share the same parity motive and evidence; execute them in the order below, and split a phase into its own file if review scope grows.

## Phase 1 — Permissions and device readiness

**Why:** onboarding requests only location, camera and notifications (`permission_onboarding_screen.dart:80-130`). The sibling app declares `ACCESS_BACKGROUND_LOCATION`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `RECEIVE_BOOT_COMPLETED` and activity recognition, and it spends UI effort on OEM survival (Huawei "Protected App" dialog, Oppo permission) — evidence `ev_ac973383…`, `ev_a58447ab…`.

**Files:** `lib/core/permissions/device_readiness.dart` (new), `lib/core/permissions/oem_autostart.dart` (new), `lib/features/shared/device_readiness_screen.dart` (new), `lib/features/shared/readiness_banner.dart` (new), `lib/features/auth/presentation/permission_onboarding_screen.dart` (rewrite), `lib/features/shared/tracking_health_card.dart` (rebase on the new provider), `android/app/src/main/AndroidManifest.xml`, `lib/core/i18n/app_strings.dart`, `test/mobile_contract_regression_test.dart`, `test/device_readiness_test.dart` (new), `test/oem_autostart_test.dart` (new).

- [x] **T1.1 Manifest + contract test.** Added `ACCESS_BACKGROUND_LOCATION` with a disclosure comment; `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` deliberately **not** added (Play-restricted — the battery exemption is opened through the native channel's settings intent instead). Rewrote the two "must not contain" assertions to assert presence **and** that the onboarding ships disclosure copy across en/hi/ml. Verified in the merged manifest of a debug build: `ACCESS_BACKGROUND_LOCATION`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `ACTIVITY_RECOGNITION`, `FOREGROUND_SERVICE_LOCATION` present, no `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  - Test: `flutter test test/mobile_contract_regression_test.dart` (red first, then green).
  - Acceptance: manifest contains both permissions; the contract test asserts the disclosure keys exist and are non-empty in all three languages.
- [x] **T1.2 Readiness core.** `lib/core/permissions/device_readiness.dart`: `ReadinessItem` (with `autostart` added), `ReadinessState` (with `notRequested`), `ReadinessSnapshot` (carries the manufacturer so the OEM recipe comes from the same observation, `toStorage`/`fromStorage`), `ReadinessSource` (injectable, returns whether a settings surface opened), `PlatformReadinessSource` (permission_handler + `DeviceCompatService` for the exemption/auto-start, `openAppSettings()` for the exemption), `readinessSourceProvider`, `readinessProvider`, `ReadinessCache`, `buildReadinessSteps`, `readinessStateLabel`, `readinessServiceStartProvider`.
  - Test: unit tests with a fake source — each state transition, permanent denial keeps `blocking` non-empty, `ready` true only when every item is `granted`/`notApplicable`.
  - Acceptance: no platform channel is touched in tests; the provider is read only on demand (never during unrelated navigation — this is what keeps `sol_final_auth_edges_test.dart` green).
- [x] **T1.3 Graded onboarding.** `lib/features/shared/device_readiness_screen.dart` holds the one checklist (`ReadinessChecklist`) that `permission_onboarding_screen.dart` and the in-app `DeviceReadinessScreen` both render: ordered rows notifications → location → background location → camera → activity → battery → auto-start, per-item rationale, "Open settings" for `permanentlyDenied`, the Android 11+ two-step note on the background row, and a non-blocking "Later". "Allow remaining" walks the required permissions in order; battery and auto-start keep their own rows because they leave the app for a settings screen.
  - Test: widget tests for the four states (never asked, denied, permanently denied, all granted) at 1.0 and 1.8 text, 320 dp and 411 dp wide; tapping a CTA calls the fake source exactly once.
  - Acceptance: screen never blocks login; every CTA has a unique semantic label.
- [x] **T1.4 OEM survival guide.** `lib/core/permissions/oem_autostart.dart` carries `OemGuide` (manufacturer/brand/aliases/pathKey/component) plus `oemGuideFor`/`oemGuideForOrGeneric` for Xiaomi-Redmi-POCO (`com.miui.securitycenter`), Oppo-Realme (`com.coloros.safecenter`), OnePlus (`com.oneplus.security`), Vivo-iQOO (`com.vivo.permissionmanager`), Huawei-Honor (`com.huawei.systemmanager`, "Protected app" copy) and Samsung (`com.samsung.android.lool`), with a generic recipe for other vendors. The card is offered from the checklist while the battery exemption is missing; opening still goes through `DeviceCompatService`, which falls back to the app detail screen when the vendor component cannot be resolved.
  - Test: mapping unit tests for each manufacturer string incl. case and unknown vendors; a widget test that the guide is offered only when the exemption is missing.
  - Acceptance: no hard crash when the vendor component cannot be resolved (fallback to `openAppSettings()`).
- [x] **T1.5 One readiness surface.** `lib/core/location/tracking_health.dart` now owns only the foreground-service probe (`TrackingServiceProbe`); `TrackingHealthCard` renders its permission rows from `readinessProvider` and repairs through the same `ReadinessSource`. `lib/features/shared/readiness_banner.dart` renders from `ReadinessCache` (no platform read) on guard Home and both "More" hubs, which also gained a "Device setup" entry into the in-app screen.
  - Test: banner appears for each blocking item and disappears when the fake source reports all-granted; existing tracking-health test still passes.
  - Acceptance: a single provider drives both surfaces; no duplicate permission reads.

**Phase 1 gate:** analyze clean, full suite green, `flutter build apk --debug` succeeds, and — with the Pixel attached — notifications, while-in-use location, background location, activity recognition and the exemption each obtainable through the flow.

**Phase 1 status: implemented, pending the on-device walkthrough.** `flutter analyze` clean; `flutter test` 440 passed (new: `test/device_readiness_test.dart`, `test/oem_autostart_test.dart`, `test/readiness_surface_test.dart`, `test/support/readiness_fixtures.dart`; rewritten: the tracking-health case in `test/ciss_ams_parity_test.dart`); `flutter build apk --debug` succeeds and the merged manifest carries the new permission. The on-device permission walkthrough still needs the phone attached.

## Phase 2 — Night shift and cross-midnight attendance

**Why:** `fetchFieldOfficerGuardAttendance({date})` returns one calendar date (`mobile_repository.dart:1738`) and the muster roll derives "on duty" from `checkIn != null && checkOut == null` within that single day (`field_officer_attendance_screen.dart:156`). A 20:00→06:00 shift therefore vanishes at midnight: the guard reads as not-on-duty, the check-out lands on the next calendar date, and history shows an unpaired punch.

**Files:** `lib/core/attendance/shift_window.dart` (new), `lib/core/attendance/attendance_pairing.dart` (new), `lib/core/network/mobile_repository.dart` (range parameters), `lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart`, `lib/features/guard/presentation/screens/guard_attendance_screen.dart`, `lib/features/field_officer/presentation/pdf/muster_roll_pdf.dart`, `lib/features/guard/presentation/screens/guard_dashboard_screen.dart`, tests `test/shift_window_test.dart`, `test/attendance_pairing_test.dart`, `test/night_shift_surfaces_test.dart` (new).

- [x] **T2.1 Business date + window model.** `lib/core/attendance/shift_window.dart`: `ShiftWindow` (business date, start, end, `crossesMidnight`, `length`, `contains`, `hasEndedBy(grace)`), `shiftWindowFor(...)` and `shiftClockFrom(...)` parsing `20:00-06:00`, `20:00 – 06:00`, `8 PM to 6 AM` and a `night` keyword, with the 12 h-from-check-in default. Pure Dart, no Flutter import, no `DateTime.now()`.
  - Test: table-driven cases for label formats, `crossesMidnight`, and window end on the next day.
  - Acceptance: pure Dart, no Flutter import, no `DateTime.now()`.
- [x] **T2.2 Pairing rules.** `lib/core/attendance/attendance_pairing.dart`: `PunchPairStatus`, `PunchPair` (with `isOnDuty`, `needsCheckOutReview`, `entry`), `pairPunches(rows, {now, grace})`, `groupByBusinessDate`, `parseRowDate`/`parsePunchTime` (ISO, `HH:mm[:ss]`, `H:mm am/pm`, `14 Oct 2026`, `14/10/2026`), `attendanceGuardKey`/`attendanceRowKey`/`mergeAttendanceRows`. A check-out pairs with the latest open check-in regardless of calendar date within `window.length + grace`; a second check-in marks the earlier pair `duplicateCheckIn`; an open punch past `window.end + grace` becomes `missedCheckOut`; a row carrying both clock times past midnight rolls the check-out over. A check-out with no observed check-in is `missedCheckOut` with a null check-in, so it renders but never warns about a missing check-out and never counts as on duty.
  - Test: boundaries — 23:59 in / 00:01 out, 06:00 out, 06:30 late out, double check-in, missing check-out, ordinary day shift unchanged, and a guard with two sites.
  - Acceptance: `open` pairs never exceed one per employee; statuses are total (every row lands in exactly one pair).
- [x] **T2.3 Query strategy.** `MobileRepository.fetchGuardAttendanceForBusinessDate({businessDate, district, lookbackDays = 1})` reads the existing aggregated range endpoint over `businessDate - 1 → businessDate` (one request, no new route) and falls back, only when the range route answers 404, to fetching the two single dates and merging them by row id. `date`-based reads are untouched. The FO live feed and history providers now go through it; history widens its fetch window by one day while still filtering the visible range by business date.
  - Test: repository test with a fake client asserting the query parameters and the merge de-duplication.
  - Acceptance: no behaviour change for day shifts; two calls maximum.
- [x] **T2.4 Surfaces.** The FO live feed pairs punches, keeps an open overnight shift on today's feed with a `since 21:00 (yesterday)` line, and takes its status from the pair; History is grouped under business-date headers with a "carried over from the previous day" chip so a 05:40 check-out sits under the day the shift started; History's summary counts shifts rather than rows; the muster-roll PDF gains a "Carried over from the previous day" section, excludes incomplete shifts from the on-duty count, and never lists a carried-over guard twice; a `clockProvider` (`lib/core/time/clock.dart`) drives every "now" so the surfaces are testable at a fixed instant. The guard side gained `lib/features/guard/application/open_duty_session.dart` and `lib/features/guard/presentation/widgets/open_duty_session_card.dart`: the guard dashboard now shows an open tour across midnight ("On duty since 21:00 (yesterday)") and flags a tour whose window ended without a check-out, both tapping through to the attendance screen where the check-out is recorded and the server's early-check-out reason prompt runs. The card reads the guard's own attendance log directly rather than through a derived provider, because a derived provider re-exposing a scoped provider trips Riverpod's nested-override assertion in the preview harness.
  - Test: widget tests at a fixed clock for each surface, 1.0/1.8 text; PDF byte test asserts the carry-over section only when a carry-over exists.
  - Acceptance: with a fixed 02:00 clock and a 20:00 check-in, the guard reads on-duty everywhere and the pair is closed by a 06:10 check-out without duplication.
- [x] **T2.5 Grace + overnight notice.** The live feed shows "Check-outs to review: N" when any pair on the viewed date ended without a check-out, and tapping it opens a sheet listing exactly those guards (each row opens the guard detail). The Crashlytics non-fatal half stays with the Phase 4 observability task, because Crashlytics wiring lands there.
  - Test: notice appears exactly once and lists the count.
  - Acceptance: no dead-end — the notice opens the affected rows filtered to those guards.

**Backend ask (non-blocking):** return `businessDate` and `shiftEnd` per attendance row and accept an explicit business-date range; the client is correct before that lands because of T2.1–T2.3.

**Phase 2 gate:** analyze clean, suite green, debug APK builds, and with the Pixel attached a manual pair — check in before midnight, check out after — verified on the phone.

**Phase 2 status: implemented; the on-device walkthrough is outstanding.** `flutter analyze` clean and the full suite green (490 tests; new: `test/shift_window_test.dart`, `test/attendance_pairing_test.dart`, `test/mobile_repository_business_date_test.dart`, `test/night_shift_surfaces_test.dart`, `test/guard_open_session_test.dart`). The pairing tests cover 23:59→00:01, a 06:10 check-out, a late check-out inside grace, a check-out far outside the window, a double check-in, an orphan check-out, an unchanged day shift and one guard with two sites; the guard-side tests cover an overnight tour at 02:00, an overdue tour, a superseded check-in and a multi-day log. A pre-existing overflow in the attendance map legend (`_MapLegendItem`) surfaced while testing the live feed at 320 dp and 1.8 text scale and is fixed.

## Review rounds

**Round 2 (Phase 2 logic) — delegated evaluation did not run; self-review findings fixed.** Three attempts to delegate an independent evaluation of the shift logic failed before producing anything: two Astra sessions (`gpt-6-astra`, high effort) died with `stream disconnected before completion`, and the fallback session never received its task at all — twice, including a short retry — the same delivery fault that also blocked the earlier targeted re-review. The findings below are therefore from my own pass over the code, each backed by a test.

7. **High — a night guard who never checked out was invisible to the field officer.** The live feed's relevance filter kept a pair only when it was on duty or belonged to the viewed business date (`field_officer_attendance_screen.dart`, the `relevant` filter and the `review` list built from it), so the morning after an overnight tour the one case the review exists to catch — the tour that never closed — was excluded from both the feed and the "Check-outs to review" notice; its business date is the previous day. The guard's own card still showed it, but the officer who chases it did not. Fixed with `PunchPair.needsReviewWithin(now, lookback: 1 day)` in `attendance_pairing.dart`, wired into the feed, the notice, `_livePairs` (muster roll) and the PDF carry-over section, and covered by `test/night_shift_surfaces_test.dart` ("a night guard who never checked out is visible in the morning").
8. **High — a forgotten check-out followed by a later check-in was filed as a duplicate tap.** `_pairGuard` marked the earlier pair `duplicateCheckIn` whenever a second check-in arrived while one was open, so a morning shift with no check-out followed by an evening check-in silently lost its review flag (`needsCheckOutReview` is false for duplicate pairs). Fixed with `duplicateCheckInTolerance` (one hour, documented as tunable): seconds apart is a retry, hours apart is a check-out that never happened and becomes `missedCheckOut`.
9. **Medium — a row whose date label could not be parsed lost its punches entirely.** `pairPunches` dropped any row whose `dateLabel` did not parse, so one unusual server format made a guard disappear from the feed, the history and the muster roll at once. `pairPunches` now takes `fallbackDate`, the field-officer screen passes the business date it is viewing, and a unit test pins both behaviours.
10. **Low — the muster roll listed a forgotten overnight check-out among the day's own rows,** which have no date column. Anything filed under an earlier business date now goes to the carry-over section.

Judged correct and left alone: at most one open pair per guard; a closed overnight pair staying with the day it started; history grouping agreeing with the live feed; the business-date query's one-day lookback matching exactly what the review window can see; and punch parsing across ISO, `HH:mm[:ss]`, `H:mm am/pm`, `dd/MM/yyyy` and `dd-Mon-yyyy`. Open decisions for the office: the inferred window ("night → 20:00–06:00, otherwise 12 h from check-in") mis-classifies a duty whose real length is 8 or 24 hours; the two-hour grace; the one-hour duplicate tolerance; and whether an overlapping relief hand-over at two duty points should pair by duty point.

**Round 1 (Phase 1) — one independent review, with two route substitutions.** The requested DeepSeek V4.1 Flash route could not carry the session, so the reviewer ran on GPT-6 (high); the sibling GPT-6.1 Sol reviewer never started (`unreadable_encrypted_agent_task` — the sub-agent task is encrypted by the main provider and the target provider cannot decrypt it, a CC Switch aggregation setting). Its report is at `.superpowers/sdd/2026-10-15-permissions-nightshift-and-baseline/phase1-independent-review.md`. Findings and fixes:

1. **Important** — the progress card printed "Nothing needs your action right now" in the branch that means the opposite. Fixed: the outstanding branch now prints the missing-setup line, the idle string is deleted from en/hi/ml, and the superseded assertion is replaced.
2. **Important** — the OEM guide claimed "CISS already has the battery exemption" while being shown *because* the exemption is missing. Fixed in all three languages: the body now instructs rather than asserts state.
3. **Important** — `ready` was true while a required item was `unknown`, so a failed probe read as "everything in place". Fixed: `ready` now requires every required item to be granted or not applicable; a new `unverified` list keeps the fail-open punch behaviour (`blocking` unchanged) and the progress card only claims success when `ready`.
4. **Minor** — a refused settings intent was silent. Fixed at the source: a failed battery-settings intent now falls back to the app detail screen, matching the auto-start path.
5. **Minor** — two test names overstated their assertions. Fixed: both now cover the case their name claims (unknown required item; exemption granted with auto-start outstanding).
6. **Minor** — the error state rendered a raw exception string. Fixed: it renders the localized missing-setup line with a retry action and logs the exception.

## Phase 3 — Plugin adoptions from the sibling build

**Files:** `lib/core/location/address_cache.dart`, `lib/features/shared/navigate_action.dart`, `lib/core/device/device_identity.dart`, `lib/features/shared/policy_webview_screen.dart`, `pubspec.yaml`, plus the call sites listed per task.

- [x] **T3.1 `geocoding`.** `lib/core/location/address_cache.dart`: `AddressResolver.forCoordinates(lat, lng)` over an injectable `ReverseGeocoder` and an injectable `AddressCacheStore` (Hive-backed in the app, in-memory in tests), cached under coordinates rounded to five decimals for six hours, answering `null` — never throwing — when offline or unreadable. `lib/features/shared/resolved_address.dart` renders the address under the coordinates on the guard-detail attendance card. It is deliberately not on the FO attendance history rows: those stay to check-in and check-out only, per the earlier instruction that history shows just the punches.
  - Test: cache hit/miss/TTL with a fake geocoder; a punch card renders the address when resolved and coordinates otherwise.
- [x] **T3.2 `maps_launcher`.** `lib/core/location/navigate_action.dart` (`NavigationLauncher.open`, three tiers: installed maps app → `geo:` intent → Google Maps directions link) with `lib/features/shared/navigate_button.dart` as the affordance, wired to the live-map guard sheet and the guard-detail attendance card. Duty rows are not wired: `GuardDuty` carries no coordinates, so that needs the same class of backend field as `businessDate`.
  - Test: intent selection with a fake launcher, including the no-app fallback chain.
- [x] **T3.3 `flutter_udid`.** `lib/core/device/device_identity.dart` caches `FlutterUdid.consistentUdid` in Hive after the first read (restart-stable, never throws), and `MobileRepository` sends `X-Device-Id` on `/api/attendance/submit` and the duty-willingness POST. The punch payload also carries `deviceId` and `punchDeviceChanged` when the handset differs from the last punch, which is a flag on the record and never a refusal. `lib/features/shared/device_identity_row.dart` shows "This device" and the id on the guard profile and the field-officer hub.
  - Test: header injection via a fake client; a changed id produces a flag on the next punch and never an exception.
- [~] **T3.4 `webview_flutter`.** `lib/features/shared/policy_webview_screen.dart` reads a policy page in-app from either a remote URL or a bundled asset, with JavaScript disabled, a main-frame-only failure state, a retry, and an "Open in browser" escape hatch (absent for a bundled page, which has nothing to hand off). Not yet reachable from a menu: the app has no policy links today, and inventing the office's Terms/PSARA URLs or shipping placeholder legal copy would be worse than leaving the surface ready to plug in.
  - Test: route renders for a local `assets/` fixture; failure state offers the escape hatch.

**Phase 3 status: implemented; the on-device checks are outstanding.** `flutter analyze` clean, the full suite green (513 tests), `flutter build apk --debug` succeeds with the four new plugins registered. New tests: `test/address_cache_test.dart` (key rounding, TTL, offline, missing box, throwing geocoder), `test/device_identity_test.dart` (single read, restart stability, failing platform read, changed-device flag), `test/device_header_test.dart` (header present, absent without an id, and a read failure that still punches), `test/device_actions_test.dart` (navigate tiers and failure snackbar, address shown or silent, policy failure state and escape hatch). Two defects surfaced while writing them and are fixed: an address lookup made the caller wait on a disk write (a widget test that never settled exposed it — the cache store is now write-through and injectable), and the policy failure-state buttons overflowed a narrow screen at large text.

## Phase 4 — Industry baseline from the web research

Ordered by value; 4.1 and 4.4 are mobile-only, 4.3 needs a backend cursor, 4.2 needs the decisions below.

- [ ] **T4.1 Offline correctness.** Outbox rows gain a monotonic sequence, an ack timestamp and a per-entity conflict policy (`server-authoritative` for attendance, `last-write-wins` for willingness); exponential backoff with jitter and a periodic flush; a Sync health surface (pending count, oldest pending, last ack, last failure reason).
  - Test: outbox unit tests for ordering, retry/backoff schedule and conflict outcomes; widget test for the health surface; no duplicate write on replay.
- [ ] **T4.2 Attendance integrity.** `abstract class AttestationSource` + Noop implementation first, Play Integrity implementation behind the compile-time flag once the app is Play-distributed and a backend verify endpoint exists; `freerasp` in **soft-fail** mode feeding `riskFlags` on punches (root, debugger, hook detected) with the punch still recorded and flagged; `screen_protector` FLAG_SECURE on payslip, document and employee-detail screens.
  - Test: risk-flag serialization, soft-fail policy (punch succeeds, flag recorded), and screen-protection toggle assertion per screen.
- [ ] **T4.3 Scale.** Cursor pagination for the employee directory (`after`/`limit`) with lazy list building and a "load more" sentinel; same for guard attendance history where the volume justifies it; keep client-side search as a fallback for already-loaded pages.
  - Test: pagination unit tests with a fake page source; widget test that scrolling triggers exactly one next-page fetch.
- [ ] **T4.4 Observability, accessibility and privacy.** Firebase Analytics events for the attendance funnel (open → readiness → punch attempt → outcome with reason), duty acceptance, sync flush; Crashlytics non-fatals for punch/sync failures with the same reason codes; a TalkBack + 1.8-text + contrast sweep over the new screens; PII access audit (who opened which employee record) and a documented retention window consistent with DPDP.
  - Test: analytics calls asserted through a fake logger; a contrast assertion test for the new surfaces in both themes.
- [ ] **T4.5 Distribution.** Decide Play vs Shorebird; if Play, wire in-app updates, staged rollout, symbol upload for the obfuscated build, and retire the sideload `REQUEST_INSTALL_PACKAGES` gate; if Shorebird, wire the CI sign/track step instead.
  - Test: CI workflow dry-run evidence captured in the ledger; analyzer/suite unaffected.

## Decisions and external dependencies

1. **Permissions (Phase 1, answered by your message):** we are adopting `ACCESS_BACKGROUND_LOCATION` + the battery-exemption flow, with the contract test and the Play-required disclosure copy updated in the same change. If the app is ever published on Play, a background-location justification and a prominent-disclosure screen are required before submission.
2. **Backend (`/api/field-officer/guard-attendance`):** who owns adding `businessDate`, `shiftEnd` and a date-range filter? The plan is correct without it but the backend version removes the double fetch and the heuristics.
3. **Play distribution:** decided in T4.5; it gates Play Integrity (T4.2) and in-app updates.
4. **Regularization / missed-punch appeal:** absent from both apps. It needs a backend endpoint (propose → approve → apply to the pair status), so it is deliberately *not* in this plan; say the word and I will write it as Phase 5 with the API contract spelled out.

## Evidence appendix

| Claim in this plan | Source |
| --- | --- |
| Sibling manifest permission set and OEM survival strings | REA `decode_android_resources` `ev_ac973383…`; ordinary-tool manifest read of the extracted base APK |
| Sibling plugin inventory (geocoding, maps_launcher, flutter_udid, webview_flutter, sqflite, …) | `ev_a58447ab…`, registrant decompile `ev_1f0d4aa4…` |
| Service survival mechanism (START_STICKY + watchdog + wake lock) | `ev_1f0d4aa4…` |
| No Play Integrity / named RASP in the sibling build | bounded negative `ev_12fc5eb1…` |
| Our missing permissions and the single-date attendance query | `permission_onboarding_screen.dart:80-130`, `mobile_repository.dart:1738`, `field_officer_attendance_screen.dart:156` |
| The tracking contract that Phase 1 rewrites | `test/mobile_contract_regression_test.dart:19-37` |
