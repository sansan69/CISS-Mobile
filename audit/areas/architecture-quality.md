# CISS-Mobile — Architecture, State, Navigation, Resilience, UI/A11y, Performance & Test Audit

**Scope / method:** static read of all 155 Dart files under `lib/` (45,973 lines) + all 36 files under `test/` (4,158 lines) at branch `wip/redesign-1.0.21` (5 modified, 16 untracked files — uncommitted redesign work included); `dart analyze` (3 warnings, 0 errors); `flutter test --coverage` (167 tests, all passing) with per-file line coverage parsed from the generated `coverage/lcov.info`; targeted greps for layering, provider topology, a11y semantics, list/image patterns, dead code and stale docs. No product file was modified; `coverage/` is git-ignored, so git state is unchanged. Every line citation below was read, not inferred.

---

## Metrics at a glance

| Metric | Value |
| --- | --- |
| Dart files / lines (`lib/`) | 155 / 45,973 |
| Largest files | `field_officer_reports_screen.dart` 2,797 · `guard_attendance_screen.dart` 2,378 · `mobile_repository.dart` 1,834 · `field_officer_attendance_screen.dart` 1,579 · `qr_attendance_flow.dart` 1,271 |
| Providers declared | ~70, of which **28 are declared inside `presentation/screens/*` files** |
| `autoDispose` providers | **1** (`lib/core/region/region_service.dart:452`) |
| `Navigator.push` vs `context.go` | **53** imperative pushes vs **13** router navigations |
| Routes declared in `app_router.dart` | 10 (none authenticated; `/` renders the whole workspace) |
| `Semantics(...)` widgets in `lib/` | **4** (in 46k lines) |
| `IconButton`s / `Tooltip`s | 45 / **0** |
| `Text('…')` hardcoded literal widgets | 200 (+1 `Text("…")`) |
| Localization delegates / ARB files | **0 / 0** (`intl` is a dependency but never wires locale) |
| `Image.network` / with `cacheWidth` | 13 / **0** |
| `ListView(` (non-lazy) / `ListView.builder|separated` | 27 / 16 |
| TODO + FIXME + HACK in `lib/` + `test/` | **0** (`XXX` only appears inside masked account numbers in `lib/dev/mock_data.dart`) |
| Disabled lints / `// ignore` suppressions | 0 / 0 (`analysis_options.yaml:10` = stock `flutter_lints`, no overrides) |
| Analyzer | 3 warnings, all `unused_import` (`auth_controller.dart:3`, `permission_onboarding_screen.dart:9`, `test/de_clutter_primitives_test.dart:6`) |
| Tests | 167 passing, 36 files, ~15 s wall, 1.6 `expect` per test on average |
| **Line coverage (overall)** | **15.3 %** — 2,742 / 17,911 coverable lines |

> Coverage caveat that matters for reading the table: `flutter test --coverage` only emits records for libraries that were *loaded* during the run. lcov reports **142 of 155** lib files. The 13 files never even imported by a test (1,862 raw lines) are invisible to the metric: `lib/main.dart`, `lib/app/app.dart`, `lib/app/motion.dart`, `lib/app/theme/app_theme.dart`, `lib/core/brand.dart`, `lib/core/cache/skeleton_widgets.dart`, `lib/core/haptics/haptic_event.dart`, `lib/core/network/auth_repository.dart`, `lib/core/qr/qr_parser.dart`, `lib/dev/mock_data.dart`, `lib/dev/preview_harness.dart`, `lib/shared/widgets/offline_badge.dart`, `lib/shared/widgets/surface_card.dart`. True coverage of shipped behaviour is therefore *lower* than 15.3 %.

---

## Findings

| ID | Sev | Title | Evidence | Conf |
| --- | --- | --- | --- | --- |
| AQ-01 | **Critical** | No route-level auth/role guard: the whole authenticated workspace lives inside `/`, so deep links, restore and URL routing cannot exist | `lib/app/router/app_router.dart:76-79`, `:80-185`; `lib/features/auth/presentation/auth_gate_screen.dart:333-337` | High |
| AQ-02 | **High** | App-lock gate is scoped to the `/` route body; 53 pushed routes cover it, so a backgrounded app resumes into an unlocked screen | `lib/features/auth/presentation/auth_gate_screen.dart:60-78`, `:309-324`; `lib/features/guard/presentation/guard_shell.dart:178`; `lib/core/auth/app_lock_lifecycle.dart:24-37` | High |
| AQ-03 | **High** | Read cache is not account-scoped and is never cleared → another account's dashboard/payslips/attendance can be served offline from the previous account | `lib/core/network/mobile_repository.dart:172-178`, `:202-212`; `lib/core/cache/hive_read_cache_store.dart:17-27`; `lib/core/cache/read_cache.dart:116-119` | High |
| AQ-04 | **High** | Offline queue and tracking buffer are global, never cleared on sign-out, and replay under whoever is signed in next | `lib/features/auth/application/auth_controller.dart:481-492`; `lib/core/sync/sync_service.dart:224-229`; `lib/core/offline/offline_queue.dart:59-82` | High |
| AQ-05 | **High** | Queue sync has no periodic/app-resume retry, and backoff sleeps inside the serial loop (head-of-line blocking) — queued attendance can sit unsent indefinitely | `lib/core/sync/sync_service.dart:42-56`, `:100-114`, `:139-141` | High |
| AQ-06 | Medium | Layering is inverted: `core/` imports `features/` (20 imports across 4 files) and `shared/widgets` imports `features/auth`; 28 providers live in screen files | `lib/core/sync/refresh_controller.dart:5-14`; `lib/core/cache/preload_controller.dart:6-11`; `lib/core/fcm/notification_service.dart:12-16`; `lib/shared/widgets/security_settings_card.dart:7-8` | High |
| AQ-07 | Medium | Background refresh/polling load: 15-min invalidate burst across 11 providers with zero autoDispose, plus two 30-s notification pollers that both hit the same endpoint | `lib/core/sync/refresh_controller.dart:41-59`; `lib/features/guard/presentation/guard_shell.dart:76-77`, `:108`; `lib/core/fcm/notification_service.dart:59-75` | High |
| AQ-08 | Medium | Module gating is largely inert: `ModuleGate` has 0 call sites, 5 `moduleEnabled` checks (all guard), 7 of 9 configured route prefixes don't exist, field officer has no gating at all | `lib/core/settings/module_gate.dart:11-37`; `lib/core/settings/route_modules.dart:5-15`; `lib/features/guard/presentation/screens/guard_dashboard_screen.dart:134-157` | High |
| AQ-09 | Medium | Maintenance/update gate fires once from a first-frame `ref.read` of possibly-default config; a maintenance flip after startup never blocks | `lib/core/update/app_update_gate.dart:34-57` | High |
| AQ-10 | Medium | User-facing error text leaks raw exception internals; `CissError.parse` falls through to `error.toString()` | `lib/core/network/ciss_error.dart:70-82`; `lib/core/network/mobile_repository.dart:449`; `lib/features/guard/presentation/screens/guard_duties_screen.dart:177`; `lib/features/guard/presentation/screens/guard_patrol_screen.dart:225` | High |
| AQ-11 | Medium | Accessibility surface is near-absent: 4 `Semantics` in 46k lines, 45 unlabeled `IconButton`s, and the shared tap primitive ignores reduce-motion and exposes no role | `lib/shared/widgets/pressable.dart:43-63`; `lib/app/router/app_router.dart:45-48` (the one place reduce-motion *is* honoured) | High |
| AQ-12 | Medium | Status-chip contrast fails WCAG AA for small text: warning-on-warningSoft 3.76:1, success-on-successSoft 4.22:1, gold accent on white 2.61:1 | `lib/shared/widgets/status_chip.dart:61-72`; `lib/shared/widgets/compliance_tag.dart:28-48`; `lib/app/theme/app_tokens.dart:60-88` | High |
| AQ-13 | Medium | Unbounded/eager list + image work: guard directory rebuilds every row on each keystroke; 13 network images decode at full resolution (incl. 44 px thumbnails) | `lib/features/field_officer/presentation/screens/field_officer_guards_screen.dart:85`, `:92`, `:187`; `lib/features/field_officer/presentation/screens/field_officer_reports_screen.dart:990`; `lib/features/guard/presentation/screens/guard_attendance_screen.dart:1866-1870` | High |
| AQ-14 | Medium | Model parsing cannot distinguish "empty" from "malformed", and shift resolution silently falls back to the wrong shift | `lib/core/models/attendance_models.dart:60`, `:99-104`; 303 silent-default casts across `lib/core/models` | Medium |
| AQ-15 | Medium | Tests: 15.3 % line coverage, 0 % on the highest-risk paths, and part of the 167-test count is source-text greps and self-referential payload assertions | `test/mobile_contract_regression_test.dart:13-60`; `test/attendance_flow_verification_test.dart:11-48`; `test/widget_test.dart:106-143` | High |
| AQ-16 | Low | Dead code, unused deps and stale docs: `qr_parser.dart`, `OfflineBadge`, `OfflineQueue.init()`, unused `json_annotation`/`json_serializable`/`build_runner`; DESIGN/README/Memory.md contradict the code | `lib/core/qr/qr_parser.dart` (52 lines, 0 imports); `lib/shared/widgets/offline_badge.dart:10`; `pubspec.yaml:45`, `:81-82`; `DESIGN.md:87`; `Memory.md:3` | High |

---

### AQ-01 — Critical — The router has no auth or role guard; the entire workspace is one route body

**Impact.** `app_router.dart` declares 10 routes, none of them authenticated. `/` renders `AuthGateScreen`, which *returns* `GuardShell` or `FieldOfficerShell` as its own body (`auth_gate_screen.dart:333-337`). Consequences: (a) no deep link can reach any workspace screen — a notification or QR link cannot open payslips, an incident, or a specific work order; (b) Android process-death restore lands on `/` and rebuilds from scratch; (c) on web/desktop, every screen shares the URL `/`, so back/forward/refresh are meaningless; (d) `redirect` cannot express "must be signed in", so enforcement is delegated entirely to widget state, which is precisely what AQ-02 breaks. The single redirect is module gating only (`:76-79`).

**Evidence.**
- `lib/app/router/app_router.dart:76-79` — `redirect` reads `remoteConfigProvider.modules` and calls `gatedRedirect`; no session read.
- `lib/app/router/app_router.dart:80-185` — 10 `GoRoute`s: `/`, `/region-select`, `/login`, `/login/guard`, `/login/guard/setup`, `/login/field-officer`, `/permissions`, `/qr-attendance`, `/attendance`, `/module-unavailable`.
- `lib/features/auth/presentation/auth_gate_screen.dart:333-337` — role dispatch happens by returning a shell widget from build.
- 53 `Navigator.of(context).push` call sites (e.g. `lib/features/guard/presentation/guard_shell.dart:178`, `:190`, `:202`) vs 13 `context.go`.

**Remediation.** Introduce `StatefulShellRoute`/`GoRoute` entries for `/guard/*` and `/field-officer/*` with a `redirect` that reads `authSessionProvider` + role from `AuthSession` (`refreshListenable` already exists via `remoteConfigProvider`; add a session-backed `Listenable`). Keep `AuthGateScreen` as `/`'s redirector only (no shell rendering). Move the 53 pushes to `context.push('/guard/payslips')`-style paths so each screen has an identity, and add a `DeepLinkService` that maps FCM payloads to those paths.

**Verification.** New router tests: (1) unauthenticated `go('/guard/payslips')` → redirected to `/`; (2) guard session → `/field-officer/work-orders` redirects to `/guard`; (3) `router.routeInformationProvider` exposes the child path for each pushed screen; (4) `flutter test` + manual `adb shell am start -a android.intent.action.VIEW -d "ciss://guard/payslips"` lands on payslips after login.

---

### AQ-02 — High — App-lock gate does not cover pushed routes (lock bypass on resume)

**Impact.** App lock is not a global overlay; it is the body of the `/` route (`_BiometricLockScreen` returned from `AuthGateScreen.build`, `:309-324`). Every workspace screen is pushed *above* that route on the root navigator, so the lock UI renders underneath it. `AppLockLifecycle.consumeLockOnResume` (`core/auth/app_lock_lifecycle.dart:24-37`) is only consumed by `AuthGateScreen.didChangeAppLifecycleState` (`:60-78`), which does `setState(_authenticated = false)` — invisible while a pushed route covers it. Net effect: enable fingerprint app lock, open payslips or a report photo, background the app, hand the phone to someone, bring it back → the pushed screen is still visible and interactive; the biometric prompt appears only after the user pops back. For a workforce app on shared field devices this defeats the feature.

**Evidence.** `lib/features/auth/presentation/auth_gate_screen.dart:66-77` (lock state flipped in a widget-local `setState`), `:309-324` (lock screen is a build sibling of the shell), `:319` (the only way out is `signOut`); `lib/features/guard/presentation/guard_shell.dart:178-300` and 52 other `Navigator.of(context).push` sites; `grep -rn 'AppLockLifecycle' lib` returns only `auth_gate_screen.dart:45` plus the class itself.

**Remediation.** Hoist the lock to the app shell: a `Stack`/`Overlay` in `CissMobileApp.builder` (next to `AppUpdateGate`, `lib/app/app.dart:25-28`) driven by a `appLockProvider` that observes lifecycle and session, rendering an opaque lock over the entire `Navigator` (and `PopScope(canPop:false)` so back cannot dismiss it). Route handlers should not own lock state. Add a `WidgetsBindingObserver` at the app level and keep `AuthGate` purely about session→shell selection.

**Verification.** Widget test: session with app lock enabled, push a dummy route, send `AppLifecycleState.paused` then `resumed`, `pumpAndSettle`, assert the lock copy ("App Locked") is on top and the pushed screen's text is not hittable (`tester.tap` on pushed-screen widget must fail / `find.text('App Locked')` findsOneWidget over it). Repeat for `/permissions` (a `go` destination, same hole).

---

### AQ-03 — High — Read cache is not account-scoped and is never invalidated

**Impact.** `_readCacheKey` = `region|path|query` (`mobile_repository.dart:172-178`) — no uid, no session epoch. `ReadCache.clear()`/`invalidate()` exist (`read_cache.dart:111-119`) but are never called anywhere in `lib/`. Combined with the offline fallback (`:209-212`) that serves *any-age* cached payload when a request fails, a second guard logging in on the same device and losing connectivity immediately sees the first guard's dashboard, payslips, attendance history, evaluations and incident list. The same data sits unencrypted in Hive box `read_cache` (`hive_read_cache_store.dart:17-27` opens it without a cipher, unlike the offline queue in `main.dart:55`).

**Evidence.** `lib/core/network/mobile_repository.dart:172-178` (key composition), `:202-212` (write + stale fallback), `lib/core/cache/hive_read_cache_store.dart:30-46` (plaintext `box.get/put`), `lib/core/cache/read_cache.dart:83-100` (`readJson` ignores `fetchedAt`); `grep -rn '_readCache' lib` shows only `setJson`/`readJson` — no `clear`, no `invalidate`.

**Remediation.** Include identity in the key (`'$region|$uid|$path|$qs'`) or clear on session epoch change: call `readCache.clear()` from `AuthController.signOut` (`auth_controller.dart:481-492`) and from the role-switch path in `RemoteConfigNotifier.build` (`remote_config_provider.dart:59-65`). Bound staleness on the offline fallback (reject entries older than e.g. 24 h) and open the box with the Hive cipher already used for `OfflineQueue` (`main.dart:52-58`).

**Verification.** Unit test on `MobileRepository` with a fake store: write key under uid A, assert `readJson` misses for uid B; assert `signOut()` empties the box (spy on `ReadCacheStore.clear`). Manual: guard A logs in, airplane mode, guard A signs out, guard B logs in offline → must show B's empty/error state, not A's data.

---

### AQ-04 — High — Offline queue and tracking buffer replay across accounts

**Impact.** `OfflineRequest` carries no uid (`offline_request.dart:3-55`) and the queue is never cleared on sign-out (`auth_controller.dart:481-492` only clears topics and tracking service). `SyncService` replays each queued request with `_repository.authHeaders()` — i.e. the *current* Firebase user (`sync_service.dart:224-229`, `_authHeaders` → `_token()` → `_auth.currentUser`). On a shared duty phone: guard A queues an attendance submit offline, signs out (or is signed out by app-lock recovery), guard B signs in; connectivity returns and A's attendance is submitted under B's identity — or rejected with a 403 that increments `retryCount` until the entry is evicted after 20 tries. The same applies to the tracking buffer (up to 5,000 location samples) posted to `/api/mobile/tracking/batch` under whoever is signed in.

**Evidence.** `lib/features/auth/application/auth_controller.dart:481-492`; `lib/core/sync/sync_service.dart:42-56` (start + connectivity listener), `:224-229` (headers), `:148-187` (batch flush uses `_repository.authHeaders()`); `lib/core/sync/providers.dart:14-16` (`TrackingBuffer` global singleton); `lib/features/guard/presentation/screens/guard_attendance_screen.dart:425`, `lib/features/guard/presentation/screens/guard_leave_screen.dart:156`, `:217` (enqueue sites).

**Remediation.** Stamp `uid` on `OfflineRequest` and on buffered tracking samples; on `processQueue`, skip/evict entries whose uid ≠ current uid (log to Crashlytics as a data-integrity event). Clear both stores in `AuthController.signOut` (`clear()` already exists on both classes). Alternatively key the Hive box per uid.

**Verification.** Test: enqueue with uid A, switch session to uid B, run `processQueue` with a fake Dio, assert zero requests fired for A's entry and the entry is evicted with a reason. Manual: airplane-mode attendance as A, sign out, sign in as B, restore connectivity, confirm no A-request hits the network.

---

### AQ-05 — High — Queued writes can starve: no periodic retry, and backoff blocks the queue

**Impact.** `SyncService.processQueue` runs only on (a) `start()` and (b) a `connectivity_plus` change event (`:42-56`). There is no timer, no app-resume hook, and no rollback trigger, so a request that fails while the connection *appears* up (server 5xx, captive portal, 401 after token rotation) waits for the next connectivity flap or a cold start — an attendance punch can sit in the queue for an entire shift. Worse, the exponential backoff is `await Future.delayed` *inside* the serial `for` loop (`:100-107`), up to 64 s per request, so one bad entry delays every later entry; and `_isSyncing` (`:64`) drops any concurrent trigger that arrives during that sleep (including the connectivity-return event that would otherwise have flushed the queue).

**Evidence.** `lib/core/sync/sync_service.dart:20` (only `Connectivity` as a trigger source), `:42-56`, `:63-66` (`_isSyncing` early return), `:100-107` (sleep in loop), `:139-141` (`finally` reset); `grep -n 'Timer' lib/core/sync/sync_service.dart` → no timer.

**Remediation.** (1) Add a low-frequency flush timer (e.g. every 2–5 min while the app is foregrounded) plus a flush on `AppLifecycleState.resumed`, mirroring the refresh controller's lifecycle discipline. (2) Replace the in-loop sleep with a per-entry `nextAttemptAt` timestamp persisted on `OfflineRequest`; skip not-yet-due entries instead of sleeping. (3) Replace the `_isSyncing` bool with a `Completer`/`Future` so a second trigger *awaits* the in-flight pass and then runs again, rather than being dropped. (4) Surface queue age (not just count) in `SyncStatusBadge`.

**Verification.** Unit tests with a fake clock: entry with `retryCount=3` is skipped until `nextAttemptAt`, later entries are still attempted in the same pass; a trigger during an in-flight pass produces a second pass. Manual: queue an attendance, disable server route (return 503), wait 2 min without touching connectivity, confirm a flush attempt occurs.

---

### AQ-06 — Medium — Dependency direction is inverted (`core` → `features`, `shared` → `features`)

**Impact.** The advertised layering (`lib/app`, `core`, `features`, `shared`) does not hold. `core/sync/refresh_controller.dart` imports ten *screen* files purely to reach their providers (`:5-14`); `core/cache/preload_controller.dart` imports six screens (`:6-11`); `core/fcm/notification_service.dart` imports the guard/field-officer tab providers and the auth controller (`:12-16`), and `core/settings/remote_config_provider.dart` imports `features/auth/application/auth_controller.dart` (`:7`). `shared/widgets/security_settings_card.dart` and `biometric_setup_sheet.dart` import `features/auth/application/*` (`:7-8`, `:10`). Because the 28 data providers are declared *inside* presentation screens, every cross-cutting concern (refresh, preload, notifications) must depend on the UI layer; features cannot be extracted or tested in isolation, and any screen rename breaks `core`.

**Evidence.** `grep -rn "import '.*features/" lib/core` → 20 hits in 4 files; `grep` in `lib/shared` → 3 hits; providers declared in presentation files include `fieldOfficerDashboardProvider` (`field_officer_dashboard_screen.dart:20`), `fieldOfficerVisitReportsProvider` (`field_officer_reports_screen.dart:26`), `guardDashboardProvider` (`guard_dashboard_screen.dart`), etc.

**Remediation.** Move each feature's providers into `lib/features/<feature>/application/` (guard/field-officer already have precedent: `guard_tab_provider.dart`). Let `core` expose an abstract "refreshable registry" (`List<Refreshable>`) that features register into at import-time via an adapter in `app/`, so `core` never names a screen. Move `security_settings_card` into `features/auth/presentation/widgets/` or invert it to take callbacks.

**Verification.** Add a layering guard (a Dart test walking `lib/`, or `import_lint`) asserting: no file under `lib/core/**` imports `lib/features/**`; no file under `lib/shared/**` imports `lib/features/**`; no `Provider` declaration under `lib/features/*/presentation/**`. Fail CI on violation.

---

### AQ-07 — Medium — Background refresh/polling load is heavier than the UI needs

**Impact.** Three mechanisms compound. (1) `RefreshController` invalidates 11 feature providers plus remote config every 15 minutes (`refresh_controller.dart:41-59`) — and because `GuardShell` keeps all four tabs alive in an `IndexedStack` (`guard_shell.dart:108`) while watching dashboard and profile at shell level (`:76-77`; FO equivalent `field_officer_shell.dart:76-78`), every tab's providers still have listeners, so the burst refetches ~6 endpoints simultaneously and resets already-loaded screens to skeletons mid-task. (2) There is exactly **one** `autoDispose` provider in the app (`region_service.dart:452`), so every feature list/model graph stays resident for the process lifetime, including the role that is no longer signed in. (3) `NotificationService` runs **two** independent 30-second pollers (`_poll`, `notification_service.dart:57-75`) against the same `/api/mobile/notifications` endpoint — `unreadCountProvider` is permanently watched by both shells and the guard dashboard (`guard_shell.dart:358`, `field_officer_shell.dart:490`, `guard_dashboard_screen.dart:462`), i.e. ~240 requests/hour before any user action, doubled whenever the inbox is open.

**Evidence.** `lib/core/sync/refresh_controller.dart:28-34`, `:41-59`; `lib/features/guard/presentation/guard_shell.dart:76-77`, `:108-110`; `lib/features/field_officer/presentation/field_officer_shell.dart:76-78`, `:109`; `lib/core/fcm/notification_service.dart:39-56`, `:59-75`; `lib/core/region/region_service.dart:452` (the lone `autoDispose`).

**Remediation.** Make feature data providers `autoDispose` (or `.autoDispose.keepAlive()` only for the shell-level dashboards) so off-screen tabs release listeners; replace the blanket `invalidate` list in `RefreshController` with per-provider TTL checks driven by `ReadCache.isFresh`, invalidating only providers that are currently watched; consolidate notification polling into one `StreamProvider` (derive unread count from the same payload, as `fetchUnreadNotificationCount` already falls back to) and stretch the interval, or switch to the existing FCM push to trigger a one-shot refresh instead of polling.

**Verification.** Instrument `ApiClient` with a counter in a debug build and log request counts over a 30-minute idle session before/after; assert ≤ ~1 notification request/5 min and no multi-endpoint burst on the refresh tick. Cross-check with `flutter test` (provider lifecycle tests: reading a tab's provider then disposing the tab should drop the listener under `autoDispose`).

---

### AQ-08 — Medium — Module gating is mostly inert

**Impact.** Server-driven module flags (`ModuleFlags`, 28 keys) visually gate only four guard dashboard tiles plus the Break button: `moduleEnabled` has 5 call sites total, `ModuleGate` has **zero** call sites outside its own file, and there is no gating anywhere in `lib/features/field_officer/**`. The route-level half of the design is dead: `kRouteModules` maps 9 prefixes, but only `/qr-attendance` and `/attendance` correspond to routes that exist in `app_router.dart`; the seven `/guard/*` entries can never match because those screens are `Navigator.push`es, not routes (see AQ-01). Because `route_modules_test.dart` only exercises `/qr-attendance` and `/`, the deadness is invisible to CI. Practical effect: turning off `leave`, `patrol`, `payslips`, `documents`, `incidents`, `training`, `evaluations`, `workOrders` or `reports` server-side hides a dashboard tile but leaves the screen reachable from in-app links and leaves field-officer modules entirely un-gated.

**Evidence.** `lib/core/settings/module_gate.dart:11-37`; `lib/core/settings/route_modules.dart:5-15`; `lib/features/guard/presentation/screens/guard_dashboard_screen.dart:134`, `:140`, `:151`, `:157`; `lib/features/guard/presentation/screens/guard_attendance_screen.dart:1196`; `grep -rn 'moduleEnabled\|ModuleGate' lib/features/field_officer` → no matches; `test/route_modules_test.dart:6-17`.

**Remediation.** Either finish the mechanism (route entries + a `redirect`-level gate as in AQ-01, plus `ModuleGate` wrappers on the seven `/guard/*` screens and the FO surfaces) or delete it: remove the unreachable `kRouteModules` entries and the unused widget so the config surface matches reality. Whichever path, add a test that enumerates every route and asserts each gated prefix resolves.

**Verification.** Table-driven test: for each key in `kRouteModules`, assert the router actually has a matching route (walk `GoRouter.configuration.routes`), and assert `gatedRedirect` blocks it when the flag is off. Then a widget test on the FO shell with `workOrders:false` asserting the work-orders entry is absent.

---

### AQ-09 — Medium — Maintenance/update gate is one-shot and reads possibly-default config

**Impact.** `AppUpdateGate` runs once in `didChangeDependencies` (`app_update_gate.dart:34-40`) and calls `ref.read(remoteConfigProvider)` (`:47`) — at first frame, remote config is almost always the cached/default snapshot because `RemoteConfigNotifier.refresh()` is TTL-gated and network-bound. So a server-declared `app.maintenance` that arrives seconds later is ignored for the whole session, and a maintenance window that starts while the app is open never blocks it. `forceUpdate`/`maintenance` therefore only protect cold starts that begin with a warm cached config.

**Evidence.** `lib/core/update/app_update_gate.dart:34-40`, `:42-57`, `:82-83` (`build` just returns the child); `lib/core/settings/remote_config_provider.dart:106-126` (refresh is TTL/`_inFlight` gated).

**Remediation.** Make the gate reactive: `ref.watch(remoteConfigProvider.select((c) => c.app.maintenance))` and show/tear down the blocking dialog on change (guard against re-entrancy with a flag rather than a one-shot `_checked`). Re-run the update check when the remote config version changes or on `AppLifecycleState.resumed`.

**Verification.** Widget test: pump `AppUpdateGate` with a mutable notifier starting at `maintenance:false`, flip to `true` after the first frame, `pumpAndSettle` → dialog appears; flip back → dialog disappears. Extend `test/app_update_gate_test.dart:29-48` accordingly.

---

### AQ-10 — Medium — Raw exception text reaches users

**Impact.** `CissError.parse` ends with `error.toString().replaceFirst('Exception: ', '')` (`ciss_error.dart:82`), and `MobileRepository` builds every error as `throw Exception(_extractApiError(error))` (`:214`, `:253`, `:278`; `_extractApiError` itself ends the same way at `:449`). Screens then print that string verbatim: `guard_duties_screen.dart:177` (`'Could not send response: ${error...}'`), `guard_patrol_screen.dart:225` (`message: error.toString()`), `guard_leave_screen.dart:236`, `field_officer_reports_screen.dart:1660`. Any `TypeError`/`StateError`/Firebase code (`[firebase_auth/user-not-found]`, `type 'Null' is not a subtype of type 'String'`) reaches a guard's snackbar. It also masks the good branches that *are* mapped (401/403/404/500, timeout, offline) because unmapped `DioException`s and all non-`Dio` errors fall to the catch-all.

**Evidence.** `lib/core/network/ciss_error.dart:34-83` (esp. `:77-82`); `lib/core/network/mobile_repository.dart:449`; `lib/features/guard/presentation/screens/guard_duties_screen.dart:177`; `lib/features/guard/presentation/screens/guard_patrol_screen.dart:225`; `lib/features/guard/presentation/screens/guard_leave_screen.dart:236`; `lib/features/guard/presentation/screens/guard_attendance_screen.dart:1448`.

**Remediation.** Split diagnostics from copy: add a typed `AppFailure` (`kind`, `userMessage`, `debugDetail`, `retryable`) produced at the repository boundary; never interpolate `error` into UI strings — log `debugDetail` to Crashlytics and show `userMessage`. Add a fallback user message ("Something went wrong. Please try again.") for unrecognized errors in `CissError.parse` and delete the `toString()` fallthrough.

**Verification.** Unit tests asserting `CissError.parse`/repository mapping never returns a string containing `Exception`, `TypeError`, `[firebase`, or a stack frame for a matrix of error inputs. Grep gate: `grep -rn "error.toString()" lib/features` returns nothing.

---

### AQ-11 — Medium — Accessibility surface is nearly absent

**Impact.** In 46k lines there are **4** `Semantics(...)` widgets (`login_hub_screen.dart`, `action_row.dart`, `primary_action.dart`, `floating_nav_bar.dart`), **0** `Tooltip`s for **45** `IconButton`s, and 0 `excludeSemantics`/`MergeSemantics`. Icon-only buttons (back, refresh, call, share, camera, filters — e.g. `guard_attendance_screen.dart:2182`) therefore announce as an unlabeled "button", which for a workforce app used outdoors with gloves and on cheap devices is a functional barrier. `PressableScale` — the shared tap primitive introduced by the redesign (`pressable.dart`, used for cards/rows) — wraps `GestureDetector` with no `Semantics(button: true, label: …)` and no `onTap` fallback label, so cards are announced as raw text with no action; and its `AnimatedScale` ignores `MediaQuery.disableAnimations` even though `app_router.dart:45-48` explicitly honours reduce-motion for page transitions. Text scaling is never clamped (good) but there is no `textScaler` testing either.

**Evidence.** `lib/shared/widgets/pressable.dart:43-63`; `lib/app/router/app_router.dart:45-48`; `lib/shared/widgets/action_row.dart:28-31` (the correct pattern, applied once); counts above via `grep -c`.

**Remediation.** (1) Give `PressableScale` `Semantics(button: true, label: label, onTap: onTap, excludeSemantics: true)` and collapse its animation to 0 ms when `MediaQuery.disableAnimationsOf(context)`; the same guard belongs in `AnimatedSwitcher`-based `SyncStatusBadge` (`sync_status_badge.dart:18`). (2) Add `tooltip:` (or `semanticLabel` on the icon) to all 45 `IconButton`s — a lint (`always_provide_tooltip`) or a one-off sweep with a test. (3) Add a golden/semantics test for the guard shell at `textScaler: 2.0`.

**Verification.** `flutter test` with `SemanticsTester`/`expect(tester.getSemantics(find.byIcon(...)), matchesSemantics(label: ..., isButton: true))` for the shell nav, one dashboard card and one icon button; run the app with TalkBack on a device and walk Home → Duty → Activity.

---

### AQ-12 — Medium — Status colours miss WCAG AA for small text

**Impact.** Computed contrast (sRGB, WCAG 2.1): `warning` `#B86618` on `warningSoft` `#FAF0E3` = **3.76:1**; `success` `#1B825E` on `successSoft` `#E3F5EE` = **4.22:1**; `accent` gold `#BD9C55` on white = **2.61:1**. All three are used as *small* foreground text in chips/tags at 12–13 px with `w700` (`status_chip.dart:41-47`, `compliance_tag.dart:60-76`), so they fail the 4.5:1 AA threshold; `accent` also fails the 3:1 large-text/UI threshold when used for iconography. Dark-mode variants are fine (7.9–9.6:1), so this is a light-theme-only defect — which is the default. (`primary`/`danger`/`inkMuted` all pass: 8.85, 6.19, 5.08–5.61.)

**Evidence.** `lib/app/theme/app_tokens.dart:60-88` (token values), `lib/shared/widgets/status_chip.dart:61-72`, `lib/shared/widgets/compliance_tag.dart:28-48`.

**Remediation.** Darken the soft-background foreground pair, e.g. warning `#8A4A0F` (≈5.6:1 on `#FAF0E3`) and success `#14664A` (≈5.4:1), keeping the soft tints; introduce a separate `accentInk` token for gold text on light surfaces and reserve `accent` for fills/icons ≥3:1 contexts. Add a unit test that asserts every `(foreground, background)` pair in `_styleFor`/`ComplianceTag` reaches 4.5:1.

**Verification.** Add `test/contrast_test.dart` computing WCAG ratios for each chip tone; it fails on the current tokens and passes after the change. Spot-check screenshots in light mode at 200 % text scale.

---

### AQ-13 — Medium — Eager lists and full-resolution images

**Impact.** The field-officer guard directory builds **every** guard row eagerly: `ListView(children: [...filtered.map(_GuardDirectoryRow.new)])` (`field_officer_guards_screen.dart:92` with `:187`). `filtered` is computed inside `build` (`:85`) and a `TextField.onChanged` calls bare `setState` (`:161-163`), so **every keystroke rebuilds every row**; the same build also recomputes a `.toSet()` district count over the whole list (`:152`). App-wide there are 27 non-lazy `ListView(...)` call sites. Separately, 13 `Image.network` calls decode the server's original image with no `cacheWidth`/`cacheHeight` and no `memCacheWidth` — a stamped 12 MP report photo decodes at ~48 MB into the raster cache, which is the classic OOM/`jank` path on 2 GB field devices. The 44×44 attendance thumbnail at `guard_attendance_screen.dart:1866-1870` decodes the original instead of a cached thumbnail — the same pattern repeats at `field_officer_reports_screen.dart:990`, `:1013`, `training_report_detail_sheet.dart:492` and `guard_patrol_screen.dart:742`.

**Evidence.** `lib/features/field_officer/presentation/screens/field_officer_guards_screen.dart:85`, `:92`, `:152`, `:161-163`, `:187`; `lib/features/field_officer/presentation/screens/field_officer_reports_screen.dart:990`, `:1013`; `lib/features/guard/presentation/screens/guard_attendance_screen.dart:1858`, `:1866`; `lib/features/guard/presentation/screens/guard_patrol_screen.dart:742`; `grep -c 'Image.network(' = 13`, `grep -c 'cacheWidth|cacheHeight' = 0`.

**Remediation.** Convert the directory (and the other long lists) to `ListView.builder`/`.separated` with `itemCount`; precompute `filtered` outside `build` via a `ValueNotifier`/provider, or memoize per `(query, filter)` key. Wrap every `Image.network` in a shared `RemoteThumb` widget that sets `cacheWidth`/`cacheHeight` from `LayoutBuilder` constraints and supplies `loadingBuilder`/`errorBuilder` placeholders.

**Verification.** Widget test: pump the directory with 500 synthetic guards and assert `find.byType(_GuardDirectoryRow)` builds ≪ 500 (lazy) — will fail today. Profile `flutter run --profile` + DevTools memory while scrolling the reports list on a low-end device; image memory should drop by an order of magnitude.

---

### AQ-14 — Medium (confidence: medium) — Silent-default parsing and wrong-shift fallback

**Impact.** The model layer is deliberately cast-safe (`as String?`, `is Map`, `whereType<...>`), but that converts *schema errors into plausible zeros*: 44 hand-written `fromJson`s with ~303 silent defaults (`''`, `0`, `false`). An error payload or a renamed field yields an "empty dashboard" with zero present-days rather than an error state, so the UI cannot distinguish "no data" from "contract broken". The sharper correctness risk is shift resolution: `resolveActiveShiftTemplate` returns `shifts.first` when *no* shift contains the current time (`attendance_models.dart:60`) — a guard punching at 15:00 with shifts 06:00–14:00 and 22:00–06:00 silently reports against 06:00–14:00; and `resolveAttendanceShiftTemplate` resolves an unknown `lastShiftCode` to `shifts.first` (`:99-104`), so a checkout can be attributed to a shift the guard never worked. That flows into `isEarlyCheckoutForShift` and the attendance payload (`guard_attendance_screen.dart:511-517`).

**Evidence.** `lib/core/models/attendance_models.dart:14-21`, `:60`, `:99-104`; `lib/core/models/mobile_dashboard_models.dart:348-380`; `lib/core/network/mobile_repository.dart:105`, `:946`, `:1307` (`as List<dynamic>? ?? const []` pattern).

**Remediation.** (1) Make shift resolution return `null` (and let the UI ask the guard to pick) instead of `shifts.first`; only fall back when the shift list has exactly one entry. (2) Add a validation layer at the repository boundary: assert required envelope keys per endpoint and throw a typed `SchemaFailure` instead of defaulting silently; keep tolerant parsing only for optional cosmetic fields. (3) If codegen is wanted, adopt `json_serializable` for the envelope (deps are already in `pubspec.yaml:45`, `:81-82`) with explicit `@JsonKey(required: true)` on identity fields.

**Verification.** Unit tests: `resolveActiveShiftTemplate` returns `null` at 15:00 for the two-shift fixture; unknown `lastShiftCode` returns `null`; `fetchGuardDashboard` with `{'success': false}` throws `SchemaFailure` rather than rendering zeros. Existing `test/early_checkout_reason_test.dart` and `test/duty_models_test.dart` should stay green after updating expectations.

---

### AQ-15 — Medium — Test suite: low coverage, weak assertions, untested high-risk paths

**Impact.** 167 tests pass in ~15 s, but line coverage is **15.3 %** and is concentrated where risk is lowest (settings 94 %, models 22 %, auth 70 %); every offline/sync/network/update path sits at 0–10 % and location at 22 %. Part of that pass count is not behavioural: `test/mobile_contract_regression_test.dart` greps source files for literal strings (`File(...).readAsStringSync()` + `contains('/api/guard/tracking/heartbeat')`, `:13-60`) — it asserts formatting, not behaviour, and will pass even if the call is unreachable; `test/attendance_flow_verification_test.dart:11-48` builds a literal payload and asserts the literal equals itself (`expect(payload['employeeId'], dummyEmployeeId)`) — a zero-value test that also commits a real-looking employee ID/phone/DOB. Several `widget_test.dart` cases (`:106-143`) are pure "renders" smoke tests. Determinism is acceptable but noisy: the suite runs without a Firebase app, so `PreloadController` prints `[core/no-app]` failures (`guard_dashboard preload skipped: …`) — i.e. the preload path is exercised only in its error branch, and any future assertion on that path would be environment-dependent.

**Evidence.** Coverage tables below; `test/mobile_contract_regression_test.dart:13-60`; `test/attendance_flow_verification_test.dart:11-48`; `test/widget_test.dart:106-143`; suite output `[core/no-app] No Firebase App '[DEFAULT]' has been created`.

**Remediation.** (1) Convert source-grep contract tests to behavioural tests against a fake `Dio`/adapter (assert the request path actually hit). (2) Delete or rewrite `attendance_flow_verification_test.dart` to drive `GuardAttendanceScreen` with overridden providers. (3) Set coverage thresholds per directory (`--fail-under` style gate) starting with the modules below; add fakes for `MobileRepository` (an interface already exists via `AuthRepository`) so screens can be tested without Firebase. (4) Add a `setUpAll` that initialises a mock Firebase app (`Firebase.initializeApp(options: testOptions)`) or overrides `preloadControllerProvider`, to remove the no-app noise.

**Verification.** `flutter test --coverage && <coverage gate>`; the new behavioural tests should fail if the endpoint string in `SyncService` is changed to an unreachable path (prove by temporarily breaking it locally, then reverting).

---

### AQ-16 — Low — Dead code, unused dependencies, stale documentation

**Impact.** Several mechanisms are present but unwired, which reads as "feature exists" in review while doing nothing:
- `lib/core/qr/qr_parser.dart` (52 lines, a faithful port of the web parser) is imported by **nobody** — `qr_attendance_flow.dart` imports only `core/utils/date_format.dart`; QR parsing is done inline there.
- `lib/shared/widgets/offline_badge.dart` (`OfflineBadge`) has **0** call sites, so there is no online/offline banner anywhere; connectivity is only inferable from a failed submit or the `SyncStatusBadge` "N pending" chip (`sync_status_badge.dart:16`), which appears only after a write has already been queued.
- `OfflineQueue.init()` (`offline_queue.dart:35-38`) is never called — `main.dart:54-58` duplicates the logic, so the class has two incompatible initialisation paths.
- `ReadCache.invalidate()`/`clear()` unused (see AQ-03).
- `Haptics.enabled` (`haptics.dart:26-30`) is only ever set in tests, so the documented "wire this to the OS/app preference" never happened — users cannot turn off the haptic that fires on every `PressableScale` tap.
- `json_annotation`, `json_serializable` (`pubspec.yaml:45`, `:81-82`) and `build_runner` are declared but unused: 0 `part '*.g.dart'` files, 44 hand-written `fromJson`s. `build_runner`/`json_serializable` pinned as `any` also defeats version resolution.
- Debt is untracked: **0** TODO/FIXME/HACK markers in `lib/` or `test/`, so known gaps live only in prose docs.
- Docs are stale: `DESIGN.md:87` lists "leaderboard" as *not yet in mobile*, yet `lib/features/guard/presentation/screens/guard_training_leaderboard_screen.dart` (13 KB, with `test/guard_training_leaderboard_test.dart`) ships; `DESIGN.md:39` bans drop shadows and `:42` bans bare full-page spinners while `metric_card.dart:33-39`/`floating_nav_bar.dart:50-58` add `BoxShadow`s and 51 `CircularProgressIndicator`s exist; `Memory.md:3`'s newest entry is dated 2026-07-05 while the current branch carries October 2026 redesign work; `README.md` (32 lines) documents no architecture, no test command, no coverage story.

**Evidence.** `lib/core/qr/qr_parser.dart:1-52`; `lib/shared/widgets/offline_badge.dart:10`; `lib/core/offline/offline_queue.dart:35-38`; `lib/core/haptics.dart:26-30`; `pubspec.yaml:45`, `:81-82`; `DESIGN.md:39`, `:42`, `:87`; `Memory.md:3`; `README.md:1-32`; `lib/shared/widgets/metric_card.dart:33-39`.

**Remediation.** Either wire or delete each item (`qr_parser` → use it in `qr_attendance_flow` or delete; `OfflineBadge` → mount it in the shell app bars alongside `SyncStatusBadge`; `OfflineQueue.init` → call it from `main` instead of the duplicated block; `Haptics.enabled` → read an `appSettingsController` field). Remove unused deps or start generating. Refresh `DESIGN.md`/`Memory.md` in the same PR that lands the redesign, and add a short architecture section to `README.md` (directory map, provider conventions, test/coverage commands).

**Verification.** `dart analyze` clean; `flutter pub deps --style=compact | grep json_serializable` empty after removal; a doc test that asserts every screen file under `lib/features/*/presentation/screens/` is mentioned in `DESIGN.md`'s feature list (catches the leaderboard class of drift); grep gate for new TODO markers in CI.

---

## Coverage by area

`flutter test --coverage` → 142 lib files reported, 2,742 / 17,911 coverable lines = **15.3 %**.

| Top-level area | Files | Lines hit / found | Line coverage |
| --- | ---: | ---: | ---: |
| `lib/app` (theme, router, app) | 3 | 38 / 172 | 22.1 % |
| `lib/core` | 63 | 756 / 3,599 | **21.0 %** |
| `lib/features` | 50 | 1,337 / 13,125 | **10.2 %** |
| `lib/shared` (widgets) | 25 | 611 / 1,007 | 60.7 % |
| `lib/` root (`main.dart`, `firebase_options.dart`) | 1 | 0 / 8 | 0 % |
| **Total** | **142** | **2,742 / 17,911** | **15.3 %** |

Per-module detail (only rows that matter; all others are in the 0–70 % range):

| Module | Files | Hit / found | Coverage | Read |
| --- | ---: | ---: | ---: | --- |
| `lib/core/settings` (flags, remote config) | 6 | 112 / 119 | 94.1 % | well covered |
| `lib/core/attendance` (shift/session/validation) | 3 | 57 / 58 | 98.3 % | well covered |
| `lib/core/haptics` | 2 | 26 / 28 | 92.9 % | well covered |
| `lib/core/cache` | 3 | 49 / 71 | 69.0 % | read cache tested; Hive store 0 % |
| `lib/core/auth` | 7 | 122 / 203 | 60.1 % | lifecycle covered; saved-accounts/biometric partly |
| `lib/features/auth` | 8 | 1,030 / 1,480 | 69.6 % | best-covered feature |
| `lib/features/region` | 1 | 101 / 130 | 77.7 % | good |
| `lib/shared` | 25 | 611 / 1,007 | 60.7 % | primitives covered, media/list widgets 0 % |
| `lib/core/models` | 12 | 158 / 706 | 22.4 % | `guard_profile`, `patrol_models`, `report_models`, `payslip_models` at **0 %** |
| `lib/core/location` (tracking) | 7 | 108 / 482 | 22.4 % | buffer/sample tested, `background_tracking_service` mostly not |
| `lib/app` | 3 | 38 / 172 | 22.1 % | router built, redirects not exercised |
| `lib/core/update` | 3 | 33 / 314 | 10.5 % | gate dialog only; downloader/installer **0 %** |
| `lib/core/region` (`region_service`) | 1 | 17 / 203 | 8.4 % | activation/region switch almost untested |
| `lib/core/network` (repository/api) | 8 | 48 / 923 | 5.2 % | `api_client` **0 %**, `mobile_repository` trace-level |
| `lib/core/sync` | 3 | 6 / 181 | 3.3 % | only `chunked()` tested; `refresh_controller` **0 %** |
| `lib/core/fcm` | 2 | 5 / 154 | 3.2 % | notification service essentially untested |
| `lib/core/offline` (queue/drafts) | 3 | 2 / 100 | **2.0 %** | `offline_request` **0 %**, enqueue/evict untested |
| `lib/features/guard` (18 screens) | 18 | 184 / 4,235 | **4.3 %** | dashboard/training/leaderboard only |
| `lib/features/field_officer` (19 files) | 19 | 18 / 6,335 | **0.3 %** | effectively untested |
| `lib/features/attendance_public` | 1 | 1 / 278 | 0.4 % | no-login attendance untested |
| `lib/features/attendance_qr` | 1 | 1 / 542 | 0.2 % | QR attendance untested |
| `lib/core/gestures` | 1 | 0 / 31 | 0 % | edge-gesture wrapper never loaded |
| `lib/core/utils` | 1 | 0 / 5 | 0 % | date helper untested |

---

## Explicit list of high-risk untested paths

Ranked by blast radius × absence of coverage. Each path has **no** test exercising its failure mode today.

1. **Offline attendance replay under a different account** — `SyncService._processRequest` + `_flushTrackingSamples` (`core/sync/sync_service.dart:148-339`); queue itself 2.0 %, `offline_request.dart` 0 %. This is AQ-04 + AQ-05: no test proves who a queued punch is attributed to, or that it is ever retried without a connectivity flap.
2. **Queue eviction / retry-decay / cap** — `OfflineQueue.enqueue` eviction at `maxQueueSize` (`offline_queue.dart:59-82`) and `SyncService`'s `retryCount > 20` eviction (`:75-81`) are untested; silent data loss for guards who queue more than 100 writes or fail 21 times.
3. **Read-cache cross-account serve and staleness** — `_getJson` fallback (`mobile_repository.dart:209-212`, network module 5.2 %). Only `read_cache.dart` (38 lines) is covered; `hive_read_cache_store.dart` (0 %) and the account-scoping behaviour are not.
4. **Background location tracking** — `core/location/background_tracking_service.dart` (708 lines) has no direct test; `mobile_contract_regression_test.dart` only greps its source text for endpoint strings. Heartbeat scheduling, restart-from-saved-context, Android 14 notification-permission crash path (`main.dart:98-109`) are unverified by code.
5. **Attendance submit end-to-end (guard)** — `guard_attendance_screen.dart` 2,378 lines, 4.3 % of `lib/features/guard`; `_submitAttendance` (`:462-…`) includes photo encode, geofence distance, shift resolution, validation, enqueue — no widget/integration test drives it.
6. **Field-officer flows (all)** — 19 files / 6,335 lines at 0.3 %: work orders, visit/training reports with photo stamping and offline queue, guards directory, live map, day timeline, guard attendance map. `field_officer_reports_screen.dart` (2,797 lines) is the app's largest and riskiest file with zero coverage.
7. **Public/QR attendance (no-login)** — `attendance_public_screen.dart` 0.4 %, `qr_attendance_flow.dart` 0.2 %; these are unauthenticated entry points that create attendance records and enqueue offline writes with a verification token (`sync_service.dart:208-222`).
8. **App-lock bypass via pushed routes** — `auth_gate_screen.dart` app-lock branches are partially covered (`auth_lifecycle_integration_test.dart`), but there is no test that a pushed route is re-locked on resume (AQ-02), which is exactly the gap.
9. **Maintenance / force-update**, including a flag arriving after startup — `app_update_gate.dart` 2 tests, both cold-start only; `apk_downloader.dart` 0 %.
10. **Refresh/invalidate burst and provider lifecycle** — `refresh_controller.dart` 0 %, no test that a 15-minute tick does not reset visible screens or that off-screen tabs release listeners.
11. **Notification polling & tap routing** — `core/fcm` 3.2 %; deep-link routing into tabs (`notification_service.dart` imports `guard_tab_provider`/`field_officer_tab_provider`) untested.
12. **Region switch / auth graph rebuild** — `region_service.dart` 8.4 %; `regionGraphRevisionProvider` invalidates `firebaseAuthProvider` + `apiClientProvider` mid-session (`core/network/providers.dart:13`, `:18`) — a stale-token/session race with no test.
13. **Public API surface of the repository** — `api_client.dart` 0 % (401 refresh-and-retry-once interceptor, `:35-59`), so the token-refresh loop protection described in `core/network/providers.dart:23-31` is asserted only by comments.

## What is working well (for balance)

- Session/auth logic in `AuthSessionNotifier` (`auth_controller.dart:27-227`) is unusually careful: generation counters, fail-closed paths, identity re-checks after every await, and suppression windows for deliberate sign-in/sign-out. It has the best coverage ratio in the app and reads as genuinely reviewed code.
- Error classification (`ciss_error.dart:8-32`) correctly separates retryable transport failures from validation/authorization errors, which is why the offline queue never swallows 4xx.
- `ModuleFlags` defaults, `RemoteConfig` caching and the `SyncService.chunked` batch cap (200 samples) are all tested and behave as documented.
- The shared widget layer (`lib/shared/widgets`, 60.7 %) is the most consistently structured part of the codebase and is where tokens are actually applied (186 `CissThemeTokens.of(context)` uses).
