# CISS-Mobile — Complete Application Audit

**Audit date:** 2026-10-22  
**Repository:** `/Users/mymac/Documents/CISS-Mobile`  
**Branch / HEAD:** `wip/redesign-1.0.21` / `edfec10` (working tree includes uncommitted 2026 redesign work)  
**App version:** `1.0.22+22` (`co.in.ciss.ciss_mobile`)  
**Platforms in tree:** Android, iOS, web, macOS, Linux, Windows (Android is the only shippable target today; see F-15)  
**Audit type:** full static application audit + build/test verification + emulator smoke test  
**Post-audit remediation:** see [`remediation-2026-10-22.md`](remediation-2026-10-22.md) — 14 findings closed, 11 partial, 9 open as of the same date.  
**Overall risk at audit time:** **HIGH — not ready for a production release of 1.0.22 without the P0 fixes in §9** (see the remediation report for current status)

---

## 0. How to read this report

- **F-xx** are consolidated findings. Each carries a severity, the source evidence, impact, a concrete fix, and a verification step.
- **Verified** means observed directly in source, build output, or a running app. **Inferred** means reasoned from those observations. **Server-side assumption** means the client cannot settle it; the backend or Firestore rules must be checked.
- Line numbers refer to the working tree at audit time. The three specialist reports in [`audit/areas/`](areas/) contain additional per-area detail and are the evidence base for this consolidation:
  - [`platform-and-release.md`](areas/platform-and-release.md) — Android/iOS/release/dependencies
  - [`auth-data-privacy.md`](areas/auth-data-privacy.md) — auth/storage/privacy
  - [`architecture-quality.md`](areas/architecture-quality.md) — architecture/UX/tests
- Severity scale: **Critical** = trivially exploitable, broad compromise; **High** = realistic account/data compromise, release blocker, or systemic control failure; **Medium** = material defect with preconditions or contained blast radius; **Low** = hardening/hygiene; **Info** = observation.

> **Headline:** This is a substantial, carefully built app with unusually good session-state handling, but it has three release-blocking data-protection defects on shared devices (app-lock bypass, cross-account cache disclosure, cross-account offline/GPS replay), a Play-policy blocker (`targetSdk 34`), and a broken release pipeline. None of the defects require a sophisticated attacker; they are normal field conditions — a shared duty phone, patchy connectivity, and a backgrounded app.

---

## 1. Executive summary

### 1.1 Verdict

| Dimension | Rating | Rationale |
|---|---|---|
| Authentication & session state | **Good** | Fail-closed, UID-pinned, race-aware (`AuthSessionNotifier`); no token persistence in app code |
| Local data protection | **Poor** | Cache, queue, GPS spool, drafts and payslip PDFs outlive logout; three stores are not account-scoped |
| App-lock / device privacy | **Poor** | Lock is a widget inside one route; pushed screens stay readable; no `FLAG_SECURE` |
| Transport & server trust | **Fair** | HTTPS + Dio, but cleartext is explicitly allowed for the production domain; remote Firebase/API/update config is unsigned |
| Backend authorization assumptions | **Unverified** | PIN throttling, public-attendance enforcement, Firestore rules, module enforcement are not visible from the client |
| Release engineering | **Poor** | CI gate red, 5 releases outside the signed pipeline, Play target API not met, iOS target non-shippable |
| Reliability / offline behaviour | **Fair** | Queue and spool exist and retry, but can starve, silently evict, and replay across accounts |
| Code quality | **Fair** | Clear structure and design system; but 28 providers in screens, 2.8k-line screens, inverted `core→features` imports, 15.3% coverage |
| Accessibility / UX polish | **Fair–Poor** | 4 `Semantics` in 46k lines, 45 unlabeled icon buttons, light-theme contrast failures |
| Dependency health | **Fair** | Zero known CVEs in 204 locked packages, but Flutter 3.29 (Feb 2025) and 35 packages behind; `hive` unmaintained |

**Findings:** 34 total — **5 High, 2 High (conditional), 18 Medium, 6 Low, 3 Info; no Critical.**

**Release readiness:** The signed universal APK installs, launches, and reaches the login hub cleanly (verified on an API 36 emulator). That is the extent of the good news for shipping. Do **not** put 1.0.22 into field distribution until F-01, F-02, F-03, F-04 (server confirmation), F-05, F-13 and F-14 are closed; F-06 (location/telemetry consent) should ship with the same release if field monitoring is live.

### 1.2 Top ten risks

| # | ID | Severity | Finding | Why it matters now |
|---|---|---|---|---|
| 1 | F-01 | High | Biometric app lock can be bypassed on any pushed screen | Payslips, ID documents, incidents, guard lists remain interactive after background/resume; cancel the prompt and the screen is still there |
| 2 | F-02 | High | Read-through cache is not account-scoped, unencrypted, and served on *any* error | Guard B can see Guard A's payslips/leave/incidents on a shared phone when offline or on a 401/403/500 |
| 3 | F-03 | High | Offline queue, GPS spool and drafts survive logout and are not UID-bound | A's queued punch/GPS/incident draft can be replayed under B's token or restored into B's form |
| 4 | F-04 | High (conditional) | Guard auth is a 4–6 digit PIN on unauthenticated endpoints with no visible throttling | Scriptable PIN brute force / spray; `setup-pin` overwrite risk. Confirm backend controls |
| 5 | F-13 | High | `targetSdk = 34` | Every AAB is rejected by Google Play (API 36 required since 2026-08-31) |
| 6 | F-14 | High | Release pipeline is red and was bypassed for five versions | No provenance from source to distributed APK; live channel serves 1.0.21 while tree is 1.0.22 |
| 7 | F-15 | High (if iOS is a target) | iOS target has no usage strings, background modes, entitlements or Podfile | App Store rejection and immediate crash at the first permission prompt |
| 8 | F-08 | Medium | Server-driven trust chain is unsigned; cleartext allowed for `*.cisskerala.site` | Region Firebase config, API base URL, update URL/hash all come from mutable server data; no pinning or allowlist |
| 9 | F-22 | Medium | Queue sync can starve and silently evict | Attendance queued offline can wait a shift, or be dropped after 20 failed attempts |
| 10 | F-23 | Medium | Offline cold start fails closed; saved region config is never read | Non-Kerala users cannot open the app on a cold start without network, despite an offline-first queue |

### 1.3 What is genuinely working

- **Session lifecycle is the strongest part of the codebase.** `AuthSessionNotifier` uses generation counters, UID pinning, explicit suppression windows for controller-owned sign-in/out, and fail-closed handling when the authoritative `/api/mobile/session` call fails or returns a mismatched UID. Tests cover the denial/mismatch paths.
- **Offline queue encryption:** the queue uses a Hive AES cipher whose key is generated once and stored in platform secure storage (`flutter_secure_storage`), not in the database.
- **Android backup is disabled** (`allowBackup="false"`), and the release keystore has never been committed (checked across all git history).
- **CI was designed correctly:** version/tag equality, five signing secrets, keystore materialisation from secrets, `apksigner` certificate-fingerprint pinning, SHA-256 sums, and artifact upload. The design is good; the execution stopped at v1.0.17.
- **APK update integrity check:** a downloaded update is SHA-256-verified against the manifest before installation, and the manifest's hash/size matched the live 1.0.21 artifact exactly (verified end-to-end by the platform auditor).
- **Dependency CVE posture:** an OSV.dev batch query over all 204 locked pub.dev packages returned **zero advisories**.
- **Tests:** 167 tests pass in ~15 s; settings/attendance/haptics modules are well covered (92–98%), and auth lifecycle behaviour is meaningfully asserted.
- **Design system:** 186 uses of `CissThemeTokens.of(context)`; the shared widget layer has the best structure and coverage (60.7%).

---

## 2. Scope, method, and limitations

### 2.1 Scope

**In scope:** all first-party Dart code under `lib/` (155 files, 45,973 lines), all 36 test files (4,158 lines), Android and iOS platform configuration, Gradle/CI/release configuration, assets and committed configuration, dependency graph, and the client side of every API interaction.

**Out of scope / not available:**
- Backend source, route handlers, rate limits, Firebase Security Rules, Play Console state, and the signing secrets.
- Authenticated runtime testing (no guard/FO credentials were provided or used).
- iOS build (Xcode is not installed; this Mac's active developer directory is CommandLineTools) and CocoaPods (not installed). iOS findings are static/config findings.
- Instrumentation, root/jailbreak testing, traffic interception with a custom CA, fuzzing, and load testing.
- Data-protection legal review; privacy findings are engineering observations, not legal advice.

### 2.2 Method

1. **Full static read** of the source tree by area (platform, auth/data, architecture/quality), with every cited line opened.
2. **`dart analyze` and `flutter analyze`** (the latter is what CI runs; its exit code differs).
3. **`flutter test --coverage`**, then coverage parsed from `coverage/lcov.info`, cross-checked by the Lead.
4. **Release builds:** `flutter build apk --release` and `flutter build appbundle --release`, inspected with `aapt2`, `apksigner`, and `unzip`.
5. **Dependency checks:** `flutter pub outdated` and OSV.dev `/v1/query` for all 204 locked packages.
6. **Runtime smoke test:** installed the signed release APK on a fresh API 36 (`Medium_Phone_API_36.1`) emulator, launched it, walked the unauthenticated entry flow, and captured screenshots/logcat.
7. **Read-only live checks:** fetched the public update manifest and the advertised APK to verify hash/size/signature (no authentication, no writes, no other probing).

### 2.3 Verification results at a glance

| Check | Result | Detail |
|---|---|---|
| `dart analyze` | 0 errors, 3 warnings | Warnings only; exit 0 |
| `flutter analyze` (CI gate) | **Exit 1** | 3 warnings count as failure; CI aborts at `.github/workflows/build-apk.yml:82` |
| `flutter test` | **167/167 pass** | ~15 s, 36 files |
| Line coverage | **15.3%** | 2,742 / 17,911 coverable lines; only 142 of 155 files loaded by tests |
| `flutter build apk --release` | **Success** | 124 s, 86,709,865 bytes (86.7 MB), 4 ABIs |
| `flutter build appbundle --release` | **Success** | 45,311,894 bytes (45.3 MB) |
| APK signature | **Valid** | v2, RSA-2048/SHA-384, cert SHA-256 `e5ee3fd6…29aa`, valid to 2053 |
| APK manifest | `minSdk 24`, `targetSdk 34`, `compileSdk 36`, `versionCode 22` | Play policy blocker (F-13) |
| Dependencies | 204 locked, **0 OSV advisories**, 35 outdated | Flutter 3.29.0 / Dart 3.7.0 (Feb 2025) |
| Emulator launch | **Clean** | No crash; notification prompt → region select → login hub |
| iOS build | Not verifiable | No Xcode/CocoaPods; static config is incomplete (F-15) |

---

## 3. Application overview

### 3.1 Purpose and users

CISS Workforce is a field-operations app for a security-guard workforce. It serves two authenticated roles plus a public attendance path:

- **Guard** — PIN login, duty attendance with geofence/selfie/QR, breaks, patrol checkpoints, incidents, leave, payslips, profile/documents/Aadhaar correction, training (including quizzes and leaderboard), evaluations, notifications, and biometric app lock.
- **Field Officer** — district dashboards, guard directory and live map, guard attendance map/logs/day timeline, work orders, visit and training reports with photo attachments and revisions, patrol activity, tools, notifications.
- **Public / unauthenticated** — region selection, public attendance identification/submission, QR attendance flow, permission onboarding, login hub.

### 3.2 Feature inventory (screen-level)

| Area | Screens / flows | Files (representative) |
|---|---|---|
| Auth & onboarding | Login hub, guard PIN login/setup/forgot, FO email login, permission onboarding, region selector, biometric setup | `features/auth/**`, `features/region/**` |
| Guard core | Dashboard, attendance (check-in/out, breaks, selfie, geofence), duties/willingness, patrol, incidents, leave | `features/guard/presentation/screens/*` |
| Guard records | Profile, documents, Aadhaar correction, payslips, evaluations, training list/detail/quiz/leaderboard | same |
| Field officer | Dashboard, guards directory, guard detail/profile, live map, attendance map/logs/day timeline, work orders, visit/training reports, patrol activity, tools | `features/field_officer/**` |
| Public attendance | Public attendance screen, QR attendance flow | `features/attendance_public/**`, `features/attendance_qr/**` |
| Cross-cutting | Notifications inbox, maintenance/update gate, module-unavailable, app lock, theme mode | `features/shared/**`, `core/fcm`, `core/update`, `core/settings` |

### 3.3 Technology stack

| Layer | Choice |
|---|---|
| UI | Flutter 3.29 / Dart 3.7, Material 3, custom token theme, bundled Inter font |
| State | `flutter_riverpod` 2.6 (`AsyncNotifier`, `StateNotifier`, ~70 providers) |
| Navigation | `go_router` 16, one root route (`/`) plus nine entry routes; workspace screens use imperative `Navigator.push` (53 sites) |
| Networking | Dio 5 with auth/401-retry interceptor; `http` used directly for two public endpoints |
| Backend | `https://cisskerala.site` (live), REST under `/api/**`; multi-region via `/api/public/regions` and `/api/public/region-config/:code` |
| Identity | Firebase Auth (`ciss-workforce` project, plus per-region Firebase apps), custom token for guard PIN login |
| Device data | Hive (encrypted offline queue; unencrypted read cache and drafts), secure storage (keys, saved accounts, region config, tracking descriptor), NDJSON GPS spool, temp PDFs |
| Background | `flutter_background_service` foreground service (`location` type), geolocator heartbeats, activity recognition, battery telemetry |
| Messaging | FCM + local notifications, district topics |
| Observability | Crashlytics fatal/non-fatal hooks; `debugPrint` (no structured logging) |
| Build/release | Gradle 8.x/AGP, `targetSdk 34`, CI on Flutter 3.29, signed APK/AAB |

### 3.4 Architecture map

```
┌──────────────────────────────────────────────────────────────────┐
│ app/  MaterialApp.router → AppUpdateGate → GoRouter              │
│       └── '/' → AuthGateScreen → GuardShell | FieldOfficerShell   │
│           (pushed detail screens are root-Navigator siblings)     │
├──────────────────────────────────────────────────────────────────┤
│ features/*/presentation  (screens + 28 providers declared here)  │
│ features/*/application   (auth controller, tab providers)         │
├──────────────────────────────────────────────────────────────────┤
│ core/  auth · network(MobileRepository/Dio) · cache · offline     │
│        sync · location · fcm · settings · update · region         │
├──────────────────────────────────────────────────────────────────┤
│ services: Firebase Auth/Firestore/Storage/Messaging · Hive ·      │
│           secure storage · background isolate · OS permissions    │
└──────────────────────────────────────────────────────────────────┘
```

**Structural observations.** The intended layering (`app → features → core → services`) is not enforced: `core` imports 20 screen files (refresh/preload/notifications) and `shared` imports `features/auth`, because the data providers live in the screens. There is exactly **one** `autoDispose` provider in the app. The largest files are 2,797 (`field_officer_reports_screen.dart`), 2,378 (`guard_attendance_screen.dart`), and 1,834 (`mobile_repository.dart`) lines. See F-32.

### 3.5 Key data flows

1. **Login (guard):** employee ID/phone + PIN → `POST /api/guard/auth/login` → Firebase custom token → `signInWithCustomToken` → `GET /api/mobile/session` → role/UID cross-check → `AuthSession` → shell. Session is re-resolved on every Firebase UID event; failure signs out.
2. **Attendance:** GPS fix + geofence check + optional selfie/QR → `POST /api/attendance/validate` (when enabled) → `POST /api/attendance/submit` → on retryable transport failure, request (including base64 photo) is encrypted into the Hive offline queue → `SyncService` replays when connectivity returns.
3. **Duty tracking:** check-in starts a `location` foreground service in a background isolate → heartbeats every 2–15 min (`/api/guard/tracking/heartbeat`) with lat/lng, speed, activity, battery, network, mock flag → failures append to a plaintext NDJSON spool (up to 5,000 samples) → main isolate flushes in 200-sample chunks (`/api/mobile/tracking/batch`).
4. **Read path:** allowlisted GETs are written to an unencrypted Hive read cache keyed by region+path+query; any request failure falls back to the cached payload regardless of age or HTTP status.
5. **Update:** `GET /api/public/app-update` → version comparison → download `apkUrl` → SHA-256 check against the same JSON → FileProvider → package installer.

### 3.6 Runtime smoke test (verified)

Installed the signed release APK on a clean API 36 emulator:

| Step | Observed |
|---|---|
| Cold launch | Branded splash, no crash; process alive |
| First prompt | Android notification permission dialog appears **before login** (from `FirebaseMessaging.requestPermission` at startup) |
| Deny notifications | App continues normally |
| Region screen | “Select Your State” with Kerala (`cisskerala.site`) |
| Select Kerala | Login hub: Guard / Field Officer cards, enrol link, © 2026 |
| Logcat | No fatal/Flutter errors in the captured window |

Screenshots: [`audit/evidence/launch2.png`](evidence/launch2.png) (pre-login notification prompt), [`audit/evidence/login_hub.png`](evidence/login_hub.png) (login hub). The pre-login permission prompt is a UX/privacy observation (F-06/F-11); it also confirms the app asks for notifications with no context, before the permission onboarding rationale screen.

---

## 4. Findings — Security & privacy

### F-01 — High — The biometric app lock is bypassed on every pushed screen

**Area:** auth / device privacy · **Confidence:** high (code path verified; not dynamically re-proven with biometrics)

**Evidence.**
- `AuthGateScreen` is the page for `/` only (`lib/app/router/app_router.dart:81-90`) and returns `GuardShell`/`FieldOfficerShell` from its own `build` (`lib/features/auth/presentation/auth_gate_screen.dart:333-337`).
- The lock is widget-local state: `didChangeAppLifecycleState` flips `_authenticated=false` (`:59-78`) and `build` returns `_BiometricLockScreen` (`:309-324`). There is no overlay above the navigator and no lock route.
- Workspace screens are pushed as root-navigator siblings, e.g. `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GuardPayslipsScreen()))` (`lib/features/guard/presentation/guard_shell.dart:178-205, 248-300`; FO equivalent `field_officer_shell.dart:221-310`). 53 such pushes exist.
- The only lock lifecycle observer in the app is `AuthGateScreen`; `AppLockLifecycle` is consumed nowhere else (`lib/core/auth/app_lock_lifecycle.dart:24-37`).

**Impact.** A user enables the app lock, opens payslips/documents/incidents/a guard detail, and backgrounds the app. On resume the gate may raise a biometric prompt from the offstage route, but the lock UI renders **underneath** the pushed screen. Cancelling/failing the prompt — or biometrics being unavailable, which only sets an error message (`auth_gate_screen.dart:105-128`) — leaves the sensitive screen visible and interactive. Back navigation reaches the locked gate, but the data has already been read. Recents thumbnails compound it (F-09). On shared duty phones this defeats the feature's purpose.

**Remediation.** Move the lock above the navigator, not inside a route:
```dart
// lib/app/app.dart
builder: (context, child) => AppLockOverlay(
  enabled: ref.watch(appLockArmedProvider),
  onUnlock: () => ref.read(appLockControllerProvider).unlock(),
  child: AppUpdateGate(child: child ?? const SizedBox.shrink()),
),
```
`AppLockOverlay` observes `AppLifecycleState` at app level, covers the whole child with an opaque lock screen and `PopScope(canPop: false)`, and only then runs `authenticateFingerprint`. Keep `AuthGate` for session→shell selection only. Add `FLAG_SECURE` while locked (and for sensitive screens) via a small platform channel.

**Verification.** Widget test: pump the app with a lock-enabled session, push a marker route, send `paused`/`resumed`, complete biometrics as `failed`, assert `find.text(marker)` is not hittable and “App Locked” is on top. Repeat for a `go('/permissions')` destination. Manual: device test on Android 14+ with biometrics enrolled.

---

### F-02 — High — Read-through cache discloses another account's data (and is unencrypted)

**Area:** local data / authorization · **Confidence:** high

**Evidence.**
- Fourteen authenticated endpoints are allowlisted, including payslips, leave, incidents, dashboard, FO guards/sites/work orders/reports (`lib/core/network/mobile_repository.dart:66-81`).
- The cache key omits identity: `return '$region|$path|$qs';` (`:172-178`).
- On **any** error, the cached payload is returned before error typing (`:202-215`); `_authHeaders()` throwing `StateError('Not authenticated')` is inside the same `try` (`:303-309`).
- The store opens Hive box `read_cache` **without a cipher** (`lib/core/cache/hive_read_cache_store.dart:17-27`), unlike the offline queue (`lib/main.dart:52-58`).
- `ReadCache.clear()`/`invalidate()` exist (`read_cache.dart:111-119`) but have **no caller** in `lib/`; logout does not purge the box (`auth_controller.dart:481-502`).
- The offline fallback ignores age (`read_cache.dart:84-100`); TTL is only advisory to callers that ask.

**Impact.** On a shared device, Guard A loads payslips/leave/incidents; A logs out; Guard B logs in. When B is offline, or any request returns 401/403/500, `_getJson` returns A's cached JSON and B's UI renders A's salary, leave balance, incidents, and dashboard under B's session. A revoked/disabled account can likewise keep seeing stale cached data because the cache shadows 401/403. The same data sits unencrypted on disk.

**Remediation.**
1. Scope the key: `'$region|${_auth.currentUser?.uid ?? 'anonymous'}|$path|$qs'`.
2. Only serve cache for **transport** failures: `if (_isOfflineDioError(error)) return cached;` and never for 401/403/`Not authenticated`.
3. Enforce a maximum age (e.g. 24 h) and show a “showing offline data” badge.
4. Encrypt the box with the existing Hive cipher, or store it in the encrypted queue box namespace.
5. Call `readCache.clear()` on sign-out and on any session/role/UID change; add a “clear local data” action.

**Verification.** Two-user repository test sharing one store: A writes, B's request fails 401, assert no payload is returned; assert B's key contains B's UID. Manual: A → payslips → logout → B login → airplane mode → B must see an error/empty state, not A's payslips.

---

### F-03 — High — Offline queue, GPS spool, drafts and downloads survive logout and are not account-bound

**Area:** local data / cross-account integrity · **Confidence:** high

**Evidence.**
- `OfflineRequest` has no UID (`lib/core/offline/offline_request.dart:3-55`); the queue is a global provider (`lib/core/sync/providers.dart:8-10`) and is never cleared.
- `SyncService` replays each request with `_repository.authHeaders()`, i.e. whoever is signed in now (`lib/core/sync/sync_service.dart:224-229`); the GPS batch flush does the same (`:148-187`).
- `TrackingBuffer` is a plaintext NDJSON spool in the app documents directory, holds up to 5,000 samples, and has no UID field (`lib/core/location/tracking_buffer.dart:47-55, 150-156`); `clear()` has no caller.
- Drafts are explicitly unencrypted and use **global** keys: `guard_incident_draft` (`lib/features/guard/presentation/screens/guard_incidents_screen.dart:48-71`) and `field_officer_report_<tab>` (`field_officer_reports_screen.dart:1081-1140`); both auto-restore in `initState`.
- Normal logout only fires notification-topic and tracking cleanup (`lib/features/auth/application/auth_controller.dart:481-502`); the fail-closed path (`:120-133`) runs no cleanup at all. The tracking stop clears only the secure session descriptor, not the spool (`background_tracking_service.dart:101-104`).
- Payslip PDFs are written to the temp directory and never deleted (`lib/features/guard/presentation/screens/guard_payslips_screen.dart:36-47`).
- If secure storage is unavailable/corrupt, `OfflineQueue.getEncryptionCipher()` catches the error, logs, and returns `null`; `main.dart` then opens the queue **unencrypted** (`offline_queue.dart:16-34`; `main.dart:51-55`). The AES layer fails open silently.

**Impact.** Guard A queues an attendance punch (with photo) or writes an incident/visit draft offline, then signs out or is reassigned the phone. Guard B signs in; connectivity returns and A's queue is submitted **under B's token** (the server may reject it, but the attempt is made and the entry is then silently evicted after repeated failures — see F-22). A's GPS samples upload as B's location. A's draft text auto-populates B's incident/report form. Salary PDFs remain in temp storage. If the keystore-backed key is unavailable, the queue's payloads (including photos and leave reasons) are stored in plaintext. This is a data-integrity and privacy defect, not just retention hygiene.

**Remediation.** Implement a single `purgeLocalAccountData()` and call it from **both** logout paths and on UID/role change:
```dart
await readCache.clear();
await offlineQueue.clear();
await trackingBuffer.clear();
await Hive.box<Map>('draft_box').clear();
await trackingSessionStore.clear();
await FirebaseMessaging.instance.deleteToken();
for (final f in tempDir.listSync()) { if (f.path.contains('payslip-')) f.deleteSync(); }
```
Then stamp ownership so a purge failure cannot leak: add `uid` to `OfflineRequest` and to each spooled sample; skip/evict entries whose UID ≠ the current UID; scope draft keys as `'${role}:${uid}:incident'`. Make tracking stop awaited and idempotent, and call the same cleanup from `_failClosed`. If the cipher cannot be created, fail closed (in-memory queue or explicit error), never open the box unencrypted.

**Verification.** Integration test: as UID A, enqueue an attendance request, write a draft, add a GPS sample; sign out; sign in as UID B; assert all stores are empty (or A's entries are unreadable/unreplayable) and no `/api/mobile/tracking/batch` request carries A's samples. Repeat for the fail-closed path.

---

### F-04 — High (conditional) — Guard authentication is a low-entropy PIN on unauthenticated endpoints

**Area:** authentication · **Confidence:** high for client facts; server controls unknown

**Evidence.**
- PIN policy is only `RegExp(r'^\d{4,6}$')` at both entry points (`role_login_screen.dart:215-217`, `guard_pin_setup_screen.dart:81-85`). Four digits is accepted.
- Login posts employee ID/phone + PIN to `/api/guard/auth/login` and exchanges the returned Firebase custom token (`mobile_repository.dart:776-806`); PIN setup posts employee ID + phone + DOB + new PIN to `/api/guard/auth/setup-pin` (`:682-702`). Neither request carries an existing CISS session.
- There is no client attempt counter, cooldown, CAPTCHA, or lockout; `too-many-requests` mapping exists only for FO email/password (`:613-630, 652-669`).
- Error text is neutralised to avoid enumeration (`:704-742`), which is good but not a control.

**Impact (server-side assumption).** If `/api/guard/auth/login` does not rate-limit/lock out per employee and per IP, a 4-digit space (10,000) is scriptable, and employee IDs follow a predictable format. A hit yields a Firebase custom token — full account access (attendance fraud, payslips/profile, location visibility). If `/api/guard/auth/setup-pin` permits overwriting an existing PIN for an employee, knowing a phone number and DOB is enough for takeover. If the backend already enforces strict lockout and setup refuses overwrite, downgrade this to Low.

**Remediation.**
- **Server (authoritative):** per-employee and per-IP exponential lockout on login; refuse `setup-pin` when a PIN already exists (409) and require an OTP/QR/device-bound enrolment step; enforce ≥6 digits and a weak-PIN deny list; audit-log attempts.
- **Client (defence in depth):** require 6 digits, reject sequential/repeated PINs, add a persisted attempt counter with increasing delay, map 429 to a clear “try later”, and avoid revealing whether the employee exists.

**Verification.** Backend test: 20 wrong PINs → 429/lockout and no token; `setup-pin` for an existing PIN → 409/no change. Client test: after N failures the action disables and the cooldown survives restart. Confirm lockout is identity-based, not only IP-based (guard-room NAT).

---

### F-05 — Medium — Session payload, UID and precise GPS are written to release logs

**Area:** privacy / logging · **Confidence:** high

**Evidence.**
- `debugPrint('_resolveSessionFromBackend: received data=$data, user.uid=${user.uid}')` logs the whole session payload — display name, email, primary ID, employee doc ID, districts, client name (`lib/core/network/mobile_repository.dart:358`). `:353` logs the null-user path.
- Tracking logs include coordinate context (`lib/core/location/background_tracking_service.dart:585-590`).
- There is no structured logger, log-level gate, or redaction; `debugPrint` is not stripped from release builds.

**Impact.** On a device with `adb`/root access, or via crash/log harvesting, PII and location history are exposed. It also violates data-minimisation expectations for a workforce-monitoring app.

**Remediation.** Remove payload/UID/coordinate logging. Log request ID, endpoint, status, duration, and a hashed UID at most. Add a lint/grep gate (`data=`, `uid=`, `latitude`) and route diagnostics through a logger that is disabled in release. Crashlytics non-fatals should carry an error code, not request bodies.

**Verification.** `grep -rnE "data=|user\.uid=|latitude|longitude" lib` returns no release logging; inspect `adb logcat` on a release build during login/tracking and confirm no PII.

---

### F-06 — Medium — No privacy notice or consent for continuous location and device telemetry

**Area:** privacy / compliance engineering · **Confidence:** high for absence; legal applicability requires counsel

**Evidence.**
- Permission onboarding explains only “site attendance and geofencing during duty hours” for location, plus camera/notifications (`permission_onboarding_screen.dart:78-143`).
- After clock-in, the app automatically starts a foreground location service (`guard_attendance_screen.dart:601-625`) and uploads coordinates, speed, heading, altitude, activity, mock flag, GPS/Wi-Fi state, battery percentage, and network type (`background_tracking_service.dart:294-361`).
- There is **no** in-app privacy notice, retention statement, recipient list, or withdrawal path. The only consent UI is the Aadhaar-upload consent (`guard_document_upload_screen.dart:33-34`) — a different purpose.
- Tracking starts on check-in, not as an explicit, separate consent step.

**Impact.** Continuous employee monitoring without an in-app notice/consent record is a material governance gap under India's DPDP-style expectations and most enterprise procurement reviews. It also weakens the “during duty hours” promise, because the service can run until stopped.

**Remediation.** Add a pre-tracking consent/notice screen (purpose, fields, frequency, retention, recipients, withdrawal, contact), store consent version/time per UID, link it from profile/settings, and gate `BackgroundTrackingService.start` on acceptance. Publish a retention policy (e.g. 90 days) and make it match the server. Do not bundle location consent with notification permission.

**Verification.** Product/legal review of copy; UI test that tracking cannot start without consent; server test that withdrawal stops collection and purges buffered samples.

---

### F-07 — Medium — Unauthenticated attendance endpoints expose guard PII and accept anonymous submissions

**Area:** API privacy / abuse · **Confidence:** high for client behaviour; server enforcement unknown

**Evidence.**
- `fetchAttendanceSites()` calls `GET /api/public/attendance` unauthenticated (`mobile_repository.dart:1013-1019`).
- `fetchAttendanceEmployee()` / `fetchAttendanceEmployeeByQr()` call `POST /api/public/attendance/identify` unauthenticated with employee ID, phone, or QR and parse a guard record (`:1021-1066`).
- Public attendance submit/upload-token endpoints exist and the client sends GPS and employee identifiers without an authenticated session (`:1102-1161, 1205-1215`; `features/attendance_public/public_attendance_screen.dart:239-240`).
- The QR/public flows are registered as unauthenticated routes (`app_router.dart:155-174`). No in-app link or external deep link currently reaches them, so the exposure is dormant; it becomes live the moment a QR/deep-link entry or notification route is added.

**Impact (server-side assumption).** If the identify endpoint returns names/photos/phone/site for any employee ID, it is an unauthenticated PII enumeration oracle; if submit accepts client-supplied GPS without token binding, mock-location detection, geofence enforcement, or rate limiting, attendance fraud is possible. The client also never sends an `isMock` signal on this path, so the server cannot rely on it.

**Remediation.** Server: return the minimum fields needed, bind the identify response to a short-lived signed token, require OTP/QR possession, enforce geofence and mock-location checks server-side, rate-limit per IP/employee, and never expose full profiles. Client: don't cache identify responses, don't log them, and surface a clear failure if token binding is rejected.

**Verification.** Backend tests for enumeration, replay, mock location, and rate limits; client test that identify is not persisted.

---

### F-08 — Medium — The server-driven trust chain is unsigned, and cleartext is allowed for the production domain

**Area:** transport / supply chain · **Confidence:** high for absence of validation; exploitability conditional

**Evidence.**
- Region config returns Firebase options and an arbitrary `apiUrl` from `https://cisskerala.site/api/public/region-config/:code` (`lib/core/region/region_service.dart:142-235`); `activeApiUrl` uses that server-provided URL for API and update calls (`:375-386`).
- `activateRegion` initialises a Firebase app from those remote options (`:288-310`) — a malicious config points authentication at an attacker-controlled Firebase project.
- The update manifest supplies both `apkUrl` and `sha256` (`app_update_service.dart:101-133`); the downloader accepts any URL (`apk_downloader.dart:69-76`) and the browser fallback launches an unvalidated URL (`app_update_gate.dart:85-94`).
- `network_security_config.xml:3-5` sets `cleartextTrafficPermitted="true"` for `cisskerala.site` **and all subdomains**, covering API, region, and APK hosts (`AndroidManifest.xml:45`).
- No certificate/public-key pinning anywhere; `url_launcher` call sites (payslips, documents, maps, support) do not validate scheme/host.

**Impact.** HTTPS protects the channel today, but a compromised/misconfigured API, a poisoned region record, or a downgrade to an `http://` update URL places authentication config, API destination, and installable APK under remote control. The SHA-256 check only proves the APK matches the same response — not who produced it. Android's install-time signature check blocks replacing the package, but coercion, metered-data abuse, phishing via launched URLs, and “App not installed” confusion remain. The cleartext exception is latent (no `http://` URLs in Dart today) but removes the safety net.

**Remediation.** Remove the cleartext exception (or scope it to a debug-only network config). Validate every server-provided URL: `https` only, host allowlist (`cisskerala.site` and explicit regional hosts), expected path prefix. Verify the downloaded APK's package name and signing certificate digest before install (via `PackageManager`/`apksigner` equivalent). Pin the API/update certificate or public key, or sign the region/update manifests and verify offline. Treat region config as untrusted input and fail closed on invalid/incomplete config.

**Verification.** Unit tests for URL validation (reject `http`, other hosts, `intent://`); integration test that a modified APK with a valid self-hash is rejected on signer mismatch; `grep cleartextTrafficPermitted` returns no production exception.

---

### F-09 — Low — No `FLAG_SECURE` or recents protection for sensitive screens

**Area:** device privacy · **Confidence:** high

**Evidence.** No `FLAG_SECURE`, `setSecure`, or screenshot-protection call exists in `android/` or `lib/`. Payslips, ID documents, guard profiles, and incidents are all regular Flutter surfaces. The app-lock screen does not mask the recents thumbnail.

**Impact.** The Android recents snapshot can show payslip amounts, Aadhaar document names, or incident text after the app is backgrounded. Screen recording/mirroring is unrestricted. This compounds F-01.

**Remediation.** Add a platform channel to set `WindowManager.LayoutParams.FLAG_SECURE` while locked and on sensitive screens (payslips, documents, profile, incidents); clear it elsewhere. Consider a branded recents mask.

**Verification.** Background the app on a sensitive screen and inspect recents; attempt `adb shell screencap` and confirm it is blocked while secured.

---

### F-10 — Low — A fresh PIN/password login silently disables an existing app lock

**Area:** auth policy · **Confidence:** high

**Evidence.** `_resolveAppLockPreference` clears the UID-bound `biometricEnabled` flag when `requested == false` (`auth_controller.dart:399-431`); the login checkbox defaults off (`role_login_screen.dart:69, 160, 184`). The next successful login therefore removes the lock unless the user re-ticks it — by design as lock recovery, but it is silent.

**Impact.** A user who enabled the lock can lose it after a credential login without noticing. An attacker who knows the PIN can also disable the lock. This is arguably acceptable recovery behaviour, but it should be explicit.

**Remediation.** On login, if the account previously had the lock, show a one-time “App lock is off — re-enable?” prompt and keep the durable flag until the user declines. Audit-log the change.

**Verification.** Widget test: enable lock, sign out, log in without ticking, assert the prompt appears and the flag is retained until declined.

---

### F-11 — Low — FCM token is not unregistered on logout; notification content can appear on the lock screen

**Area:** notifications / privacy · **Confidence:** high for token; medium for display

**Evidence.** `FirebaseMessaging.instance.deleteToken()` is never called; logout only unsubscribes topics (`auth_controller.dart:481-502`; `notification_service.dart:194-201`). The Android channel uses `Importance.high`/`Priority.high` with default visibility (`notification_service.dart:209-225`), so message bodies can render on the lock screen. Notification tap routing is safe (it always returns to `/`).

**Impact.** A signed-out or reassigned device can keep receiving the previous user's notifications until the server token record is replaced/expired. Sensitive content may be visible on the lock screen.

**Remediation.** Call `deleteToken()` and, where supported, `setAutoInitEnabled(false)` on logout; re-register on login. Set `visibility: NotificationVisibility.private` for sensitive channels; keep the tracking channel low-importance.

**Verification.** Logout → confirm the token is deleted and the backend record is cleared; send a test push and confirm no delivery to the signed-out device; lock-screen inspection.

---

### F-12 — Info — Secrets scan is clean; committed Firebase keys are public identifiers

**Area:** secrets · **Confidence:** high

**Evidence.** No PIN/password/session token is persisted by app code (saved accounts store role/login ID/display name/UID only). `android/key.properties` and `android/app/ciss-release.keystore` are present locally but **never committed** (`git log --all` is empty for both) and are git-ignored. `mobile.env`, `google-services.json`, `GoogleService-Info.plist`, and `lib/firebase_options.dart` are tracked; Firebase API keys/app IDs are public client identifiers, not credentials. `mobile.env` also contains `NEXT_PUBLIC_SUPER_ADMIN_EMAIL=admin@cisskerala.app`, and its `NEXT_PUBLIC_*` values are unused by the Flutter app (only `CISS_*` values are read).

**Impact.** No immediate secret compromise. The admin email exposure is minor; the dead `NEXT_PUBLIC_*` block invites confusion.

**Remediation.** Remove the unused `NEXT_PUBLIC_*` block and admin email from `mobile.env`, or document it as web-only. Keep the keystore offline and inject it only through CI; move to Play App Signing so the upload key is not the app-signing key.

**Verification.** `git ls-files | grep -E 'keystore|key.properties'` is empty; `git log --all -- android/key.properties` is empty; `mobile.env` contains only the `CISS_*` keys actually read by `lib/`.

---

## 5. Findings — Release & platform

### F-13 — High — `targetSdk 34` blocks Google Play distribution

**Area:** Android release · **Confidence:** config verified; Play policy inferred from published requirements

**Evidence.**
- `android/app/build.gradle.kts:44` — `targetSdk = 34`; `compileSdk = 36`; `minSdk = 24`.
- Built APK confirms: `aapt2 dump badging` → `targetSdkVersion:'34'`, `compileSdkVersion='36'`, `versionCode='22'`.
- Google Play requires new apps and updates to target Android 16 (API 36) for submissions after **2026-08-31** ([Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878), [target-sdk policy](https://developer.android.com/google/play/requirements/target-sdk)); a short extension to 2026-11-01 has been offered in some cases. As of this audit (2026-10-22), every AAB from this repo is rejectable.
- No Play publishing step exists in CI, so nothing would catch the deadline (`.github/workflows/build-apk.yml`).

**Impact.** The Play channel is closed; the team is pushed onto sideload distribution, which is exactly what the release evidence shows (F-14). On Android 15/16 devices the app also misses platform-enforced hardening and displays the “built for an older version of Android” compatibility warning.

**Remediation.** Set `targetSdk = 36` and re-verify the behaviours that change:
- Foreground-service start restrictions: the location service is started while an activity is visible (`autoStart: false`, `background_tracking_service.dart:41-49`; init is permission-gated in `main.dart:103-105`), so this should hold.
- Edge-to-edge enforcement: `main.dart:44` already requests it; check `android/app/src/main/res/values/styles.xml` for legacy opt-outs.
- Notification/FGS permission behaviour on API 35/36.
Add a CI assertion `targetSdk >= 36` and a Play-track dry run. Keep `minSdk 24`.

**Verification.** `flutter build appbundle --release`; `bundletool dump manifest --bundle … | grep targetSdk` → 36; device pass on API 34 and API 36 (tracking survives screen lock, notification denial does not crash).

---

### F-14 — High — The signed-release pipeline is red and has been bypassed for five versions

**Area:** release provenance · **Confidence:** verified

**Evidence.**
- `flutter analyze` exits **1** on three unused-import warnings. CI runs `- run: flutter analyze` at `.github/workflows/build-apk.yml:82`, so the only signed, certificate-pinned pipeline aborts before building.
- Tags and GitHub releases stop at **v1.0.17** (2026-07-30) while the tree is `1.0.22+22`; `git log --oneline v1.0.17..HEAD` is 33 commits. Versions 1.0.18–1.0.22 were therefore built/distributed outside CI.
- The live `/api/public/app-update` endpoint still advertises **1.0.21** (2026-08-10), with `sha256`/`sizeBytes` matching the served APK exactly and the APK signed by the same production certificate as a local build. Integrity of that artifact is good; provenance is not.
- CI's controls are otherwise solid: version/tag equality, five signing secrets, keystore from secrets, certificate-fingerprint pinning, `SHA256SUMS.txt`, artifact upload.

**Impact.** There is no auditable chain from source commit to distributed binary for five releases. The version advertised to users lags the tree; the SHA-256 and signature checks protect against corruption/substitution but cannot prove which source produced the build. A compromised developer machine could publish an APK that passes every current control.

**Remediation.**
1. Delete the three unused imports so the gate is green.
2. Tag `v1.0.22` on the shipping commit; let CI produce the AAB/APK/SHA256SUMS/certificate.
3. Publish the update manifest from CI (`SHA256SUMS.txt`), never by hand; add a job step that fails if the live manifest doesn't match the tag.
4. Move to Play App Signing; keep the upload keystore only in CI secrets and an offline backup.
5. Add branch protection requiring the release workflow to pass before tagging.

**Verification.** `flutter analyze; echo $?` → 0; workflow run for `v1.0.22` green; artifact certificate digest equals `ANDROID_SIGNING_CERT_SHA256`; live manifest `latestVersionCode`/`sha256` match the artifact; installed 1.0.21 device updates to 1.0.22.

---

### F-15 — High (conditional) — The iOS target cannot be built or shipped as committed

**Area:** iOS platform · **Confidence:** high (static); iOS build not verifiable on this machine

> If iOS is **not** a supported product target, downgrade this to Low and delete the iOS scaffolding/claims so the repo stops implying support. If iOS **is** planned, treat it as a release blocker.

**Evidence.**
- `ios/Runner/Info.plist:4-48` contains **zero** `NS*UsageDescription` keys. Any call into geolocator, camera, image_picker, local_auth, or notifications terminates the process or returns denied; App Store Connect rejects with ITMS-90683.
- No `UIBackgroundModes` → background location tracking (the core function) dies when backgrounded. No `aps-environment` entitlement → no APNs/FCM token. No `CFBundleURLTypes`/associated domains → no deep links.
- No `Podfile`, no `Podfile.lock`, no `*.entitlements` anywhere in `ios/`; 20+ federated iOS plugins are therefore unpinned and unintegrated.
- `IPHONEOS_DEPLOYMENT_TARGET = 13.0`, `PRODUCT_BUNDLE_IDENTIFIER = co.in.ciss.cissMobile`, no `DEVELOPMENT_TEAM`; display name “Ciss Mobile” vs “CISS Workforce” on Android.
- `flutter build ios --no-codesign` reports “Application not configured for iOS”; Xcode/CocoaPods are absent from the audit machine.

**Impact (if iOS is a target).** The iOS app cannot pass review, cannot receive push, cannot track in the background, and will crash at the first permission prompt. The repo's platform matrix overstates support.

**Remediation (if keeping iOS).** Add the seven usage strings, `UIBackgroundModes: location/fetch/remote-notification`, an entitlements file with `aps-environment`, a committed `Podfile` + `Podfile.lock`, a `DEVELOPMENT_TEAM`, and the Xcode capabilities. Keep ATS secure (no `NSAllowsArbitraryLoads`). Then build/archive on a Mac with Xcode and run a device test. If not keeping iOS, delete `ios/` and remove iOS claims from docs.

**Verification.** `grep -c UsageDescription ios/Runner/Info.plist` ≥ 7; `plutil -lint`; `pod install` produces a lockfile; device run shows the location/camera prompts and background samples continue.

---

### F-16 — Medium — The updater hashes an 86 MB file in RAM, ignores expected size, and serves a fat APK

**Area:** update reliability · **Confidence:** high

**Evidence.**
- `ApkDownloader.downloadWithProgress` streams to disk, then calls `file.readAsBytes()` and SHA-256s the whole file in memory (`apk_downloader.dart:100-107`). A universal 86.7 MB APK needs ~87 MB free RAM (plus copies) on devices that may have 2 GB total.
- `expectedSizeBytes` is only used for progress; the download is not bounded by it, and the declared `ApkDiskFullError` is never thrown (dead path).
- The self-update artifact is the fat universal APK (86.7 MB, 4 ABIs) even though 1.0.12–1.0.16 shipped per-ABI APKs; the AAB is 45.3 MB.
- `ApkInstallerPlugin` copies the file again into cache, doubling disk use.

**Impact.** Low-RAM/field devices can OOM or run out of disk during an update; the user sees a crash or a failed install. Every update costs ~87 MB of metered data.

**Remediation.** Compute SHA-256 incrementally while streaming (`crypto` `DigestSink`/`AccumulatorSink`), abort when `received > expectedSizeBytes * 1.05`, pre-flight free disk space (`disk_space` or platform channel) and throw `ApkDiskFullError`, and publish per-ABI APKs (arm64-v8a for the fleet) or use Play In-App Updates. Delete the temporary file after install.

**Verification.** Unit test with a fake stream: hash matches a known digest, oversized stream is aborted, low-disk fake throws. Profile memory during an update on a 2 GB device.

---

### F-17 — Medium — `allowBackup=false` alone does not stop Android 12+ device-to-device transfer

**Area:** local data · **Confidence:** config verified; OS behaviour inferred

**Evidence.** Manifest sets `android:allowBackup="false"` (`AndroidManifest.xml:41`) but declares no `android:dataExtractionRules` (API 31+) or `android:fullBackupContent`. Drafts and read cache are unencrypted (F-02, F-03). D2D migration can still copy app data on some OEMs/OS versions despite `allowBackup=false`.

**Impact.** A phone migration/replacement can carry another guard's drafts, cached payslips, and queue contents to a new device, bypassing the backup prohibition.

**Remediation.** Add `res/xml/data_extraction_rules.xml` excluding the Hive boxes, spool directory, temp PDFs, and secure-storage-backed files from cloud backup and D2D; reference it via `android:dataExtractionRules` (and `fullBackupContent` for API ≤ 30). Encrypt the remaining boxes.

**Verification.** `adb shell bmgr backupnow <pkg>` shows no app data; D2D test on API 33+; XML lint.

---

### F-18 — Medium — R8 mapping is discarded, symbols are not uploaded, and Dart is unobfuscated

**Area:** release hardening · **Confidence:** high

**Evidence.** R8/resource shrinking is enabled by the Flutter Gradle plugin (a 55.9 MB `mapping.txt` is produced), but there is no `proguard-rules.pro`, no `mappingFile` retention/upload, no Crashlytics Gradle plugin, and no `--obfuscate --split-debug-info`. `main.dart` initialises Crashlytics only from Dart.

**Impact.** Native stack traces from release builds are unsymbolicated, making crash triage slow. Dart AOT symbols remain readable, lowering the reverse-engineering bar for a security-sensitive workforce app. `mapping.txt` is deleted with `build/`, so even manual symbolication is impossible after the fact.

**Remediation.** Archive `mapping.txt` and Dart symbols as CI artifacts (or upload via the Crashlytics Gradle plugin). Add a minimal `proguard-rules.pro` for reflection-using plugins. Consider `--obfuscate --split-debug-info=build/symbols` for release builds and retain the symbols securely.

**Verification.** Trigger a crash in a release build; symbolicate with the uploaded mapping; `flutter build apk --release --obfuscate` succeeds and symbols are archived.

---

### F-19 — Low — Plugin manifests add exported receivers and sensitive permissions

**Area:** Android hardening · **Confidence:** high (verified in built APK)

**Evidence.**
- Merged manifest contains `id.flutter.flutter_background_service.WatchdogReceiver` and `.BootReceiver`, both `android:exported="true"` with no permission guard. Any app can send the relevant broadcasts to poke the tracking service.
- The merged release manifest requests **22 permission entries vs 15 declared**, including `RECORD_AUDIO` (camera/mobile_scanner), `READ_EXTERNAL_STORAGE`/`WRITE_EXTERNAL_STORAGE (maxSdk 28)`, and `RECEIVE_BOOT_COMPLETED`.
- `REQUEST_INSTALL_PACKAGES` is present (needed for the updater), which Play scrutinises.

**Impact.** Unnecessary permissions expand the privacy surface and Play Data Safety declarations; exported receivers allow nuisance/DoS pokes at the background service. `RECORD_AUDIO` is not used by any product flow, so its presence is misleading.

**Remediation.** Add `tools:node="remove"` for `RECORD_AUDIO` and legacy storage permissions if the plugins do not need them; narrow or guard the two exported receivers with a signature permission; document `REQUEST_INSTALL_PACKAGES` in the Play declaration. Re-check the merged manifest after every plugin upgrade.

**Verification.** `aapt2 dump badging` shows only the intended permissions; `dumpsys package` shows the receivers not externally actionable; Play pre-launch report clean.

---

### F-20 — Low — Repository and release hygiene gaps

**Area:** repo hygiene · **Confidence:** high

**Evidence.**
- `.gitignore:33` misses `android/build/`, which is present untracked in the tree; `.gitnexus/lbug` (≈21.5 MB) and 69 emulator screenshots under `tooling/` are tracked in a public repo. Screenshots show guard names/IDs/phones (seed data pattern, but still PII-shaped).
- `mobile.env` is tracked with a super-admin email and unused `NEXT_PUBLIC_*` keys (F-12).
- `AGENTS.md` is untracked; redesign specs/plans are untracked; documentation (`DESIGN.md`, `Memory.md`) is stale relative to the October work.
- `android/app/ciss-release.keystore` and `android/key.properties` are local-only (good) but the keystore is the production key (same cert as published APK), held on a developer machine with plaintext passwords.

**Impact.** Repo bloat, accidental data exposure, onboarding confusion, and key-custody risk. None is a direct runtime defect.

**Remediation.** Ignore `android/build/`, `*.png` under `tooling/` (or move to an internal artifact store), purge large historical blobs if the repo is public (`git filter-repo`), remove the unused env block, commit the redesign docs, and move signing to Play App Signing + CI-only secrets.

**Verification.** `git ls-files | wc -l`, `du -sh .git`, secret/PII scan on the public history, and a fresh-clone build.

---

### F-21 — Info — Dependency staleness is high, but the CVE posture is clean

**Area:** dependencies · **Confidence:** high

**Evidence.** Flutter 3.29.0 / Dart 3.7.0 (Feb 2025) is pinned locally and in CI (`.github/workflows/build-apk.yml:42`). `flutter pub outdated` reports 35 outdated direct/transitive packages: `firebase_core 3.15.2 → 5.0.0`, `firebase_auth 5.7.0 → 7.0.0`, `cloud_firestore 5.6.12 → 7.0.0`, `flutter_riverpod 2.6.1 → 3.4.3`, `go_router 16.3.0 → 18.1.1`, `file_picker 8.3.7 → 13.1.0`, `flutter_local_notifications 18.0.1 → 22.3.2`, `local_auth 2.3.0 → 3.0.2`. `hive`/`hive_flutter` are effectively unmaintained (last releases 2022/2023). `build_resolvers`/`build_runner_core` are discontinued (test-only, transitive). An OSV.dev batch query across all **204** locked pub.dev packages returned **zero advisories** as of 2026-10-22.

**Impact.** No known vulnerability today, but the app is ~20 months behind the framework and cannot adopt security fixes or new Play requirements without a migration. The long tail of major-version gaps makes the eventual upgrade expensive.

**Remediation.** Plan a framework upgrade (current stable Flutter, Dart 3.x) on a branch, then upgrade Firebase/Riverpod/go_router majors with regression tests; replace Hive with an actively maintained store (or isolate it behind the existing `ReadCacheStore`/queue interfaces); remove unused `json_serializable`/`build_runner`. Re-run the OSV query in CI monthly.

**Verification.** `flutter pub outdated` shrinks; `flutter test`/analyze green; release build on the new toolchain; OSV query in CI.

---

## 6. Findings — Reliability & correctness

### F-22 — Medium — Queue sync can starve, block, and silently discard data

**Area:** offline reliability · **Confidence:** high

**Evidence.**
- `SyncService.processQueue` runs only on `start()` and a `connectivity_plus` change (`sync_service.dart:42-56`). There is no timer and no app-resume trigger.
- Exponential backoff is `await Future.delayed` **inside** the serial loop (`:100-107`), up to 64 s per entry, so one bad entry delays all later entries; `_isSyncing` drops any trigger that arrives during the pass (`:63-66`).
- A failed pass increments `retryCount` (`:333-338`); entries with `retryCount > 20` are removed (`:75-81`), and the oldest is removed when the queue hits 100 (`offline_queue.dart:59-66`) — both with only a `debugPrint`, never a user-visible warning.
- Because `SyncService` starts at boot and `_authHeaders()` throws when no user is signed in, a logged-out app can accrue retry counts and evict queued work before the right user logs back in.

**Impact.** A guard's offline attendance/leave/incident can sit for a whole shift despite connectivity returning; after repeated failures (including “not authenticated” attempts at boot), it can be silently deleted. That is lost payroll evidence with no user recourse.

**Remediation.**
1. Add a foreground flush timer (2–5 min) plus `AppLifecycleState.resumed`.
2. Persist `nextAttemptAt` per entry and skip not-yet-due entries instead of sleeping in the loop.
3. Replace `_isSyncing` with a `Future` that coalesces triggers and runs one more pass afterwards.
4. Don't process the queue when there is no authenticated user; don't count “not authenticated” as a retry.
5. Surface queue age/count and never evict without a visible “could not send” state + support export.

**Verification.** Fake-clock tests: later entries still attempt while an early one is backed off; a trigger during a pass causes a second pass; a signed-out queue is untouched; eviction requires explicit user action. Manual: 503 route + 2-minute wait → retry without a connectivity flap.

---

### F-23 — Medium — Offline cold start fails closed, and the saved region config is never read

**Area:** offline availability / multi-region · **Confidence:** high

**Evidence.**
- On startup, if a saved non-Kerala region exists, `main.dart` re-fetches `/api/public/region-config/:code`; on failure it throws and falls back to default Firebase (`main.dart:79-99`). `saveRegionPreference` writes `ciss_selected_region_config` (`region_service.dart:174-181`), but **nothing ever reads that key** — only writes/deletes (`grep` confirms).
- `AuthSessionNotifier.build` resolves the session via `GET /api/mobile/session`; any failure (including transport) calls `_failClosed`, clears the session, and signs Firebase out (`auth_controller.dart:91-133`; `mobile_repository.dart:311-345`). There is no offline grace window or cached-session path.
- Non-Kerala `activeApiUrl`/`activeAuth` throw when `_activeRegion` is null (`region_service.dart:359-386`).

**Impact.** A non-Kerala guard opening the app after a reboot with no connectivity cannot reach the login/workspace; a Kerala guard in a dead zone is signed out on every cold start. This directly contradicts the offline-first queue and is a field-usability defect. It also makes the app fragile during backend outages.

**Remediation.**
- Read and validate the persisted region config on startup, initialise regional Firebase from it, and refresh in the background; only fail closed when the saved config is missing/corrupt.
- Distinguish transport failure from 401/403 in session resolution: for transport failures, keep a bounded offline session (e.g. 24 h) with a prominent “offline — last verified …” banner; only sign out on an authoritative denial/identity mismatch.
- Cache the last-good session snapshot (encrypted, UID-bound) for offline display, and require revalidation before any write.

**Verification.** Tests: region config fetch fails but cached config is used; `/api/mobile/session` times out → session retained with offline flag; 401 → signed out. Manual: airplane mode after a warm login, cold start, confirm workspace opens and queued writes remain pending.

---

### F-24 — Medium — Server-driven module gating is largely inert

**Area:** feature flags / authorization · **Confidence:** high

**Evidence.**
- `moduleEnabled` has 5 call sites, all guard dashboard/break (`guard_dashboard_screen.dart:134,140,151,157`; `guard_attendance_screen.dart:1196`); `ModuleGate` has **zero** call sites outside its own file.
- `kRouteModules` maps 9 prefixes, but 7 of them (`/guard/leave`, `/guard/patrol`, `/guard/documents`, `/guard/payslips`, `/guard/incidents`, `/guard/training`, `/guard/evaluations`) match **no route** — those screens are `Navigator.push`es, not routes. Only `/qr-attendance` and `/attendance` can be gated.
- There is no gating anywhere under `lib/features/field_officer/**`.

**Impact.** Turning a module off server-side hides a dashboard tile but does not stop the screen being reached from an in-app link (e.g. a record card or notification), and FO modules cannot be disabled at all. If module flags are used for entitlement/compliance (e.g. disabling payslips in a region), the client does not enforce them. Server-side enforcement is unknown; the client must not be the only control.

**Remediation.** Either finish the mechanism — route-level gates (after F-27) + `ModuleGate` on each entry point + FO gating — or delete `kRouteModules`/`ModuleGate` so the config surface stops lying. Regardless, enforce entitlement server-side and return 403; the client `403` hook (`api_client.dart:63-70`) is a good place to refresh flags.

**Verification.** Table-driven test enumerating every route/entry point against each flag; FO work-orders off → entry absent and direct route blocked; API returns 403 when called anyway.

---

### F-25 — Medium — The maintenance/force-update gate is one-shot and reads possibly-default config

**Area:** availability / release control · **Confidence:** high

**Evidence.** `AppUpdateGate` runs once from `didChangeDependencies` (`app_update_gate.dart:34-40`), uses `ref.read(remoteConfigProvider)` (`:47`), and `build` just returns the child (`:82-83`). `RemoteConfigNotifier.refresh()` is TTL/`_inFlight`-gated (`remote_config_provider.dart:106-126`). At first frame the config is usually cached/default, so a maintenance flag that arrives seconds later is ignored for the session; a maintenance window starting while the app is open never blocks.

**Impact.** The kill switch is unreliable. A bad release or active incident cannot be contained for users who already have the app open, which matters for a payroll/attendance system.

**Remediation.** Make the gate reactive: `ref.watch(remoteConfigProvider.select((c) => c.app.maintenance))`, show/tear down the blocking dialog on change, re-check on `AppLifecycleState.resumed`, and re-run the update check when the config version changes. Keep a re-entrancy guard.

**Verification.** Widget test: start `maintenance:false`, flip to `true` after first frame → dialog appears; flip back → disappears; background/resume re-checks.

---

### F-26 — Medium — Raw exception text is shown to users

**Area:** UX / information disclosure · **Confidence:** high

**Evidence.** `CissError.parse` ends with `error.toString().replaceFirst('Exception: ', '')` (`ciss_error.dart:82`); `MobileRepository` wraps errors as `throw Exception(_extractApiError(error))` (`:214, :253, :278, :449`). Screens interpolate the string directly, e.g. `guard_duties_screen.dart:177`, `guard_patrol_screen.dart:225`, `guard_leave_screen.dart:236`, `field_officer_reports_screen.dart:1660`, `guard_attendance_screen.dart:1448`.

**Impact.** Guards see `TypeError`, `StateError`, Firebase codes, or parser internals in snackbars; this is confusing, leaks implementation detail, and masks the well-mapped 401/403/404/500 branches. Support cannot triage from a screenshot.

**Remediation.** Introduce a typed `AppFailure { kind, userMessage, debugDetail, retryable }` at the repository boundary; show only `userMessage`; log `debugDetail` without PII. Add a final fallback (“Something went wrong. Please try again.”) and delete the `toString()` fallthrough. Add a grep gate for `error.toString()` in `lib/features`.

**Verification.** Matrix test over error types asserts the user string never contains `Exception`, `TypeError`, `[firebase`, or a stack frame; manual review of snackbars.

---

### F-27 — Medium — No route-level auth/role guard and no deep-link surface

**Area:** navigation architecture · **Confidence:** high

**Severity note.** The specialist architecture review rated this **Critical**; this consolidated report rates it **Medium** because no unauthenticated data path is reachable today — `GuardShell`/`FieldOfficerShell` are only rendered after a verified session — but it is the architectural root of F-01 and the reason the app cannot support deep links or restore.

**Evidence.** `app_router.dart` declares 10 routes; `redirect` only evaluates module flags (`:76-79`). `/` renders `AuthGateScreen`, which returns the role shell as its body (`auth_gate_screen.dart:333-337`). There are 53 `Navigator.push` call sites for workspace/detail screens (`guard_shell.dart:178-205`, `field_officer_shell.dart:221-310`, etc.) rather than router destinations.

**Impact.** This is not currently an unauthenticated data path — the shell is only rendered after a verified session — but it is the architectural root of F-01: there is no route identity on which to enforce auth, role, or a global lock. It also means no deep links (a notification cannot open a specific work order/payslip), no Android process-death restore to the current screen, and no meaningful web/desktop URLs.

**Remediation.** Move the workspace into `/guard/*` and `/field-officer/*` `StatefulShellRoute` branches with a `redirect` that reads `authSessionProvider` and role; keep `/` as a redirector only. Migrate the 53 `Navigator.push` calls to `context.push('/guard/payslips')` etc., and map FCM payloads to those paths. This also gives the module gate real route prefixes and lets the lock overlay (F-01) be route-aware.

**Verification.** Router tests: unauthenticated `/guard/payslips` → `/`; guard → `/field-officer/*` denied; role-correct path renders; process-death restore returns to the same path; notification opens the right destination.

---

## 7. Findings — Quality, UX & maintainability

### F-28 — Medium — Accessibility is largely unaddressed

**Area:** accessibility · **Confidence:** high

**Evidence.**
- **4** `Semantics(...)` widgets in 45,973 lines; **45** `IconButton`s and **0** `Tooltip`s.
- `PressableScale`, the shared tap primitive used for cards/rows, wraps `GestureDetector` with no `Semantics(button: true, label: …)` and no reduce-motion handling (`lib/shared/widgets/pressable.dart:43-63`), even though page transitions do honour `MediaQuery.disableAnimationsOf` (`app_router.dart:45-48`).
- No `MergeSemantics`/`excludeSemantics`; no text-scale tests; icon-only actions (back, refresh, call, share, camera, filters) announce as unlabeled buttons.
- Hardcoded English strings (~200 `Text('…')` literals), no ARB/localization delegates, despite a Malayalam-speaking workforce.

**Impact.** Screen-reader users cannot identify icon actions or card taps; outdoor/gloved use and low-end devices are the primary context. Localization is a product gap, not just a11y.

**Remediation.** Add `Semantics(button: true, label: …, onTap: …)` to `PressableScale`; add tooltips/semantic labels to all icon buttons (lint or sweep); honour reduce-motion in shared animations; add semantics tests for the shell, dashboard card, and icon button at `textScaler: 2.0`; extract strings to ARB and add `ms`/`en` locales (start with the guard flows).

**Verification.** `flutter test` semantics assertions; TalkBack walk-through Home → Duty → Activity; `flutter build` with `--dart-define` locale; no overflow at 200% text.

---

### F-29 — Medium — Light-theme status colours fail WCAG AA

**Area:** visual accessibility · **Confidence:** high (contrast computed in sRGB/WCAG 2.1)

**Evidence.** `warning #B86618` on `warningSoft #FAF0E3` = **3.76:1**; `success #1B825E` on `successSoft #E3F5EE` = **4.22:1**; `accent #BD9C55` on white = **2.61:1** (`lib/app/theme/app_tokens.dart:76-80`). All three are used as 12–13 px bold text in chips/tags (`status_chip.dart:61-72`, `compliance_tag.dart:28-48`). Dark variants pass (7.9–9.6:1). `primary` (8.85), `danger` (6.19), and `inkMuted` (5.61) pass.

**Impact.** Status (“warning”, “approved”, “gold”) is hard to read in sunlight — exactly the field condition — and fails AA for small text. Gold-on-white iconography also fails the 3:1 UI threshold.

**Remediation.** Darken the light-theme pairs (e.g. warning `#8A4A0F`, success `#14664A` against the existing soft tints), add an `accentInk` token for text, reserve `accent` for fills/icons with sufficient contrast. Add a `contrast_test.dart` asserting every foreground/background pair ≥ 4.5:1.

**Verification.** Contrast test fails on current tokens and passes after; screenshot review in light mode at 200% text.

---

### F-30 — Medium — Eager lists, full-resolution images, and heavy polling/refresh

**Area:** performance · **Confidence:** high

**Evidence.**
- The FO guard directory builds every row eagerly: `ListView(children: [...filtered.map(_GuardDirectoryRow.new)])` (`field_officer_guards_screen.dart:92`); `filtered` is computed in `build` (`:85`) and `TextField.onChanged` calls bare `setState` (`:161-163`), rebuilding every row per keystroke. 27 non-lazy `ListView(...)` sites app-wide.
- 13 `Image.network` calls with **0** `cacheWidth`/`cacheHeight`; a 12 MP report photo can decode to ~48 MB in the raster cache; the 44×44 attendance thumbnail decodes the original (`guard_attendance_screen.dart:1866-1870`; also `field_officer_reports_screen.dart:990`, `:1013`, `training_report_detail_sheet.dart:492`, `guard_patrol_screen.dart:742`).
- `RefreshController` invalidates 11 providers + remote config every 15 min (`refresh_controller.dart:41-59`); shells keep all tabs alive in an `IndexedStack` while watching dashboard/profile, so off-screen tabs still refetch and reset to skeletons.
- Exactly **one** `autoDispose` provider in the app (`region_service.dart:452`).
- `NotificationService` runs **two** independent 30-second pollers against the same `/api/mobile/notifications` endpoint (`notification_service.dart:57-75`), permanently watched by both shells and the guard dashboard — ~240 requests/hour before any interaction.

**Impact.** Jank and OOM risk on 2 GB field devices; battery/data drain (especially with GPS already running); visible loading churn every 15 min during duty.

**Remediation.** Convert directories/long lists to `ListView.builder`/`.separated`; precompute filters off `build`; wrap images in a shared `RemoteThumb` with `cacheWidth`/`cacheHeight` and placeholders; make off-screen providers `autoDispose` (keep only shell dashboards alive); replace the blanket invalidate with TTL-aware invalidation; consolidate notification polling into one stream (derive unread count from the payload) or trigger a one-shot refresh from FCM.

**Verification.** Widget test: 500 synthetic guards → built rows ≪ 500. DevTools memory while scrolling reports (image memory drops by an order of magnitude). Request counter over 30 idle minutes before/after.

---

### F-31 — Medium — Test coverage is 15.3%, and the highest-risk paths are untested

**Area:** test assurance · **Confidence:** high

**Evidence.**
- 167 tests pass in ~15 s; `flutter test --coverage` reports **2,742 / 17,911** coverable lines = **15.3%**. Only 142 of 155 `lib/` files are loaded; 13 files (1,862 lines) are never imported, so true behavioural coverage is lower.
- By area: `shared` 60.7%, `app` 22.1%, `core` 21.0%, `features` **10.2%**. Core detail: settings 94.1%, attendance 98.3%, haptics 92.9%, cache 69.0%, auth 60.1%, models 22.4%, location 22.4%, update 10.5%, region 8.4%, **network 5.2%**, **sync 3.3%**, **fcm 3.2%**, **offline 2.0%**. Features: auth 69.6%, region 77.7%, guard **4.3%**, attendance_public 0.4%, **field_officer 0.3%**, attendance_qr 0.2%.
- Some of the 167 are not behavioural: `mobile_contract_regression_test.dart:13-60` greps source text for endpoint strings; `attendance_flow_verification_test.dart:11-48` builds a payload and asserts it equals itself (and commits a real-looking employee ID/phone/DOB); several `widget_test.dart:106-143` cases are render smoke tests.
- The suite runs without a Firebase app, so preload paths are exercised only in their `[core/no-app]` error branch.

**Impact.** The defects this audit found — cache scoping, queue ownership, lock bypass, offline replay — are exactly the paths with 0–5% coverage. Regressions in attendance, sync, and field-officer flows will not be caught.

**Remediation.** Set per-directory coverage gates starting with `core/network`, `core/offline`, `core/sync`, `core/location`, `features/guard`, `features/field_officer`; introduce a `MobileRepository` interface/fake so screens can be tested without Firebase; convert source-grep tests to fake-Dio behavioural tests; add integration tests for login → attendance submit → offline queue → replay, app-lock on a pushed route, cache isolation, and maintenance flip; initialise a mock Firebase app to remove the no-app noise; delete or rewrite the zero-value payload test.

**Verification.** CI reports coverage and fails below thresholds; the new tests fail if the endpoint/UID logic is broken (prove by temporarily breaking and reverting).

---

### F-32 — Medium — Layering inversion, provider sprawl, and very large screens

**Area:** maintainability · **Confidence:** high

**Evidence.**
- `lib/core` imports `lib/features` 20 times across 4 files (`refresh_controller.dart:5-14`, `preload_controller.dart:6-11`, `notification_service.dart:12-16`, `remote_config_provider.dart:7`); `lib/shared` imports `features/auth` (`security_settings_card.dart:7-8`, `biometric_setup_sheet.dart`).
- 28 providers are declared inside `presentation/screens/*` files, so cross-cutting services must depend on UI files to reach data.
- Largest files: `field_officer_reports_screen.dart` 2,797; `guard_attendance_screen.dart` 2,378; `mobile_repository.dart` 1,834; `field_officer_attendance_screen.dart` 1,579; `qr_attendance_flow.dart` 1,271.
- 44 hand-written `fromJson`s with ~303 silent default casts; shift resolution falls back to `shifts.first` when no shift matches and when `lastShiftCode` is unknown (`attendance_models.dart:60, 99-104`), which can attribute a checkout to the wrong shift.
- The framework is 20 months old and 35 dependencies behind (F-21).

**Impact.** Features cannot be tested or extracted in isolation; a screen rename breaks `core`; onboarding is slow; wrong-shift attribution can affect pay/early-checkout logic. None of this is a security defect, but it slows every fix in §9.

**Remediation.** Enforce the intended layering with a test/import lint (no `core → features`, no providers in `presentation`); move providers to `features/<x>/application` and expose a refresh registry from `app/`; split the three largest screens into controller + sections; make shift resolution return `null` (and prompt) rather than guessing; add envelope validation at the repository boundary; upgrade Flutter/Firebase/Riverpod on a branch.

**Verification.** Layering test fails on current imports; `flutter test` green after moves; shift unit tests for the 15:00/unknown-code cases; `flutter pub outdated` shrinks.

---

### F-33 — Low — Dead code, unused dependencies, and stale documentation

**Area:** code hygiene · **Confidence:** high

**Evidence.** `lib/core/qr/qr_parser.dart` (52 lines) has no importer (QR parsing is inline in the flow); `OfflineBadge` has 0 call sites; `OfflineQueue.init()` is never called (`main.dart:54-58` duplicates it); `ReadCache.invalidate()/clear()` unused (F-02); `Haptics.enabled` is only set in tests; `json_annotation`/`json_serializable`/`build_runner` are declared but unused (0 `.g.dart` files); `build_runner`/`json_serializable` are pinned `any`. Docs drift: `DESIGN.md:87` says leaderboard is not in mobile although it ships; `Memory.md` is dated 2026-07-05; `README.md` has no architecture/test/coverage section. There are **0** TODO/FIXME markers, so known gaps live only in prose.

**Impact.** Reviewers cannot tell what is wired; dead flags imply capabilities that don't exist; unused codegen deps add resolution risk.

**Remediation.** Wire or delete each item (use `qr_parser` or remove it; mount `OfflineBadge` or delete; call `OfflineQueue.init` from `main` or remove it; read `Haptics.enabled` from settings; remove unused codegen deps). Refresh `DESIGN.md`/`Memory.md`/`README.md` in the release PR and add a short architecture/test section.

**Verification.** `dart analyze` clean; grep for 0 call sites; `flutter pub deps | grep json_serializable` empty after removal; docs reviewed against the screen inventory.

---

### F-34 — Info — Analyzer is clean apart from three unused imports; lint configuration is stock

**Area:** static analysis · **Confidence:** high

**Evidence.** `dart analyze` → 0 errors, 3 warnings: `auth_controller.dart:3` (unused `foundation`), `permission_onboarding_screen.dart:9` (unused `brand_banner`), `test/de_clutter_primitives_test.dart:6` (unused `haptic_event`). `analysis_options.yaml:10` includes stock `flutter_lints` with no extra rules or strict modes; 0 `// ignore` suppressions; 0 TODO/FIXME in `lib/`.

**Impact.** The three warnings make `flutter analyze` exit 1 and break CI (F-14). The stock lint set does not catch unawaited futures, missing `use_build_context_synchronously` discipline, or provider-lifecycle issues.

**Remediation.** Delete the three imports. Add targeted lints (`unawaited_futures`, `use_build_context_synchronously`, `avoid_print`, `prefer_const_constructors` selectively) and enable `strict-casts`/`strict-raw-types` in a staged branch.

**Verification.** `flutter analyze; echo $?` → 0; CI green; no new warnings in the PR.

---

## 8. Threat model and attack paths

| # | Scenario | Preconditions | Path | Rating |
|---|---|---|---|---|
| T1 | **Shared/reassigned duty phone** | Two guards/FOs use one device; app lock enabled; patchy network | Open payslips/docs → background → resume on pushed screen without lock (F-01) → or sign out/in as B and read A's cache offline (F-02) → or B sees A's draft/queue (F-03) | **High** |
| T2 | **PIN brute force / account takeover** | Know/guess employee ID or phone; backend lacks lockout | Script `/api/guard/auth/login` over 4-digit space (F-04); possibly overwrite PIN via setup | **High if unthrottled** |
| T3 | **Compromised/misconfigured backend or region record** | Control of API/region config, or a downgrade to http | Swap Firebase project/API URL (F-08) → harvest credentials; or serve update JSON with attacker APK+hash → prompt install | **Medium–High** (bounded by APK signature) |
| T4 | **Lost/stolen unlocked device** | Device unlocked or biometrics unavailable; app lock optional | Read cached payslips/drafts; recents thumbnail; no `FLAG_SECURE` (F-09) | **Medium** |
| T5 | **On-device malicious app** | Malicious app installed | Poke exported tracking receivers (F-19); read world-readable temp PDFs (none by default); no root detection | **Low** |
| T6 | **Attendance fraud** | Employee colludes or spoofs GPS | Public/QR submission with client GPS; mock-location flag not sent on that path (F-07); server enforcement unknown | **Medium** |
| T7 | **Insider data access** | FO account | Cache/drafts persist after role change; wide FO directory data (F-02/F-03) | **Medium** |

**Most likely real-world loss:** T1. Field workforces commonly share handsets across shifts, and the app's own offline-first design (queue, drafts, cache) assumes that usage. The three T1 findings should be fixed as one coherent “account data lifecycle” change, not as three independent patches.

---

## 9. Remediation roadmap

### P0 — before any 1.0.22 distribution (target: 3–5 working days)

| Order | Finding | Action | Effort |
|---|---|---|---|
| 1 | F-01 | Move app lock to an app-level overlay; add `FLAG_SECURE` while locked | M |
| 2 | F-02 + F-03 | Purge and UID-scope cache, queue, spool, drafts, payslip temp files, FCM token; single purge on both logout paths | M |
| 3 | F-13 | `targetSdk = 36`; regression-test tracking/notifications on API 35/36 | S–M |
| 4 | F-14 | Remove 3 unused imports (CI green); tag v1.0.22; publish manifest from CI | S |
| 5 | F-04 | Confirm backend lockout/`setup-pin` overwrite; add client 6-digit policy + cooldown | S (confirm) / M (implement) |
| 6 | F-15 | Decide iOS: fix Info.plist/Podfile/entitlements or remove iOS target and claims | S (remove) / L (fix) |
| 7 | F-22 | Stop evicting queued work silently; don't replay while signed out; add resume/timer flush | M |
| 8 | F-05 | Remove session/UID/GPS logging from release paths | S |

**P0 exit criteria:** app lock cannot be dismissed on a pushed screen; two-account shared-device test shows no cross-account cache/draft/queue/GPS data; `flutter analyze` exit 0 and a green tagged release; Play internal-track upload accepted; backend PIN controls confirmed in writing.

### P1 — next 2–4 weeks

| Finding | Action | Effort |
|---|---|---|
| F-05 | Remove PII logging; structured, release-safe logger | S |
| F-06 | Location/telemetry consent + privacy notice + retention/withdrawal | M |
| F-07 | Server-side token binding/enumeration/mock checks; client stops caching identify | M–L |
| F-08 | URL allowlist + https-only; remove cleartext exception; verify APK signer; pin/sign config | M |
| F-16 | Streaming hash + size/disk guards; ship per-ABI APKs | M |
| F-23 | Offline session grace + cached region config read | M |
| F-17 | `dataExtractionRules`/`fullBackupContent` | S |
| F-18 | Upload/retain R8 mapping and Dart symbols; add `proguard-rules.pro` | S |
| F-11 | `deleteToken()` on logout; private notification visibility | S |
| F-09 | `FLAG_SECURE` for sensitive screens | S |

### P2 — quarter

| Finding | Action | Effort |
|---|---|---|
| F-27 | Route-level auth/role guard, `/guard/*` + `/field-officer/*`, deep links | L |
| F-24 | Finish or delete module gating; enforce server-side | M |
| F-25 | Reactive maintenance gate | S |
| F-26 | Typed `AppFailure` and safe user copy | M |
| F-28 | Accessibility sweep + semantics tests + localization plan | M |
| F-29 | Contrast token fixes + test | S |
| F-30 | Lazy lists, image sizing, poll consolidation, `autoDispose` | M |
| F-31 | Coverage gates + behavioural/integration tests | L |
| F-32 | Layering enforcement, provider moves, screen decomposition, framework upgrade | L–XL |
| F-21 | Upgrade Flutter/Firebase/Riverpod/go_router; replace Hive | XL |

### P3 — backlog

F-19 (permission/receiver cleanup), F-20 (repo hygiene/key custody), F-33 (dead code/docs), F-34 (lints), Play App Signing, SBOM + monthly OSV scan, crash-symbol upload automation, load testing of the heartbeat/batch endpoints.

---

## 10. Verification evidence

### 10.1 Builds

| Artifact | Result | Size | Notes |
|---|---|---|---|
| `flutter build apk --release` | Success (124.1 s) | 86,709,865 B (86.7 MB) | Universal APK, 4 ABIs; v2 signature; cert SHA-256 `e5ee3fd603d258abe3bcf0364589dc13c2e8afcc3c063d33edbb68cf1b5c29aa` |
| `flutter build appbundle --release` | Success | 45,311,894 B (45.3 MB) | Play artifact |
| Installed APK | Success | — | API 36 emulator; clean launch |

R8/resource shrinking **is** active in the release build (the Flutter Gradle plugin default), producing `build/app/outputs/mapping/release/mapping.txt` (55.9 MB). The defect is that the mapping is not retained/uploaded and Dart is not obfuscated (F-18).

### 10.2 Coverage by area

| Area | Files | Lines hit / found | Coverage |
|---|---:|---:|---:|
| `lib/app` | 3 | 38 / 172 | 22.1% |
| `lib/core` | 63 | 756 / 3,599 | 21.0% |
| `lib/features` | 50 | 1,337 / 13,125 | 10.2% |
| `lib/shared` | 25 | 611 / 1,007 | 60.7% |
| `lib/` root | 1 | 0 / 8 | 0% |
| **Total** | **142** | **2,742 / 17,911** | **15.3%** |

Highest-risk untested paths: offline queue replay/attribution, cache scoping/staleness, background tracking, guard attendance submit, all field-officer flows, public/QR attendance, app-lock on pushed routes, maintenance flip, refresh burst, notification routing, region switch, and the 401-refresh interceptor.

### 10.3 Dependency and policy checks

- `flutter pub outdated`: 35 packages constrained behind resolvable/latest versions; Flutter 3.29.0 (2025-02-10) / Dart 3.7.0.
- OSV.dev batch query: **0 advisories** across 204 locked pub.dev packages (2026-10-22).
- Play target API: `targetSdk 34` vs API 36 requirement (2026-08-31). Confirm any extension in Play Console.
- Live update manifest: 1.0.21, SHA-256 `98194875…304f`, 85,945,160 B; downloaded artifact matched hash/size and production certificate (read-only check).
- iOS: no Xcode/CocoaPods on the audit machine; static config incomplete (F-15).

### 10.4 Runtime evidence

| File | What it shows |
|---|---|
| [`evidence/launch2.png`](evidence/launch2.png) | Android notification permission prompt **before login** |
| [`evidence/launch3.png`](evidence/launch3.png) | Region selector, Kerala |
| [`evidence/login_hub.png`](evidence/login_hub.png) | Login hub, Guard / Field Officer, © 2026 |

No authenticated flows were exercised (no credentials). The pre-login prompt and clean startup are the only runtime claims.

---

## 11. Open questions for backend / ops

These determine whether several findings stay at their current severity:

1. **Guard PIN:** Does `/api/guard/auth/login` apply per-employee and per-IP rate limiting/lockout? Does `/api/guard/auth/setup-pin` refuse to overwrite an existing PIN, and what identity proof does it require? (F-04)
2. **Public attendance:** What do `/api/public/attendance`, `/api/public/attendance/identify`, `/upload-token`, and `/submit` return and enforce for an unauthenticated caller — token binding, geofence, mock-location/Play Integrity, rate limits? (F-07)
3. **Firestore rules:** Can clients read `notifications`, `fcmTokens`, `guardLocations` directly? Are reads scoped to the authenticated UID/role? (F-11, F-06)
4. **Server-driven config:** Are region config and the update manifest signed or otherwise authenticated upstream? Are all region `apiUrl` values https-only? (F-08)
5. **Module flags and roles:** Are disabled modules enforced server-side (403), or is the client the only gate? (F-24)
6. **Retention:** What is the server-side retention for tracking samples, incident photos, and drafts? Does it match the notice you will publish? (F-06)
7. **Play Console:** Is there an existing listing/track, a target-API extension, and a decision on Play App Signing? (F-13/F-14)
8. **Deployment reality:** Are devices actually shared across guards/shifts? This sets the likelihood (not the validity) of F-01/F-02/F-03.
9. **iOS intent:** Is iOS a committed target, a future target, or leftover scaffolding? (F-15)
10. **Key custody:** Who holds the production keystore and its passwords, and is there an offline backup/rotation plan? (F-12/F-14)

---

## 12. Appendices

### A. Finding index and source mapping

| ID | Severity | Area | Source IDs |
|---|---|---|---|
| F-01 | High | App lock | ADP-01, AQ-02 |
| F-02 | High | Read cache | ADP-02, AQ-03 |
| F-03 | High | Offline/GPS/drafts | ADP-04, AQ-04 |
| F-04 | High (conditional) | Guard PIN | ADP-03 |
| F-05 | Medium | PII logs | ADP-08 |
| F-06 | Medium | Privacy consent | ADP-05 |
| F-07 | Medium | Public attendance | ADP-07 |
| F-08 | Medium | Server trust / cleartext | ADP-06, P-04, P-07 |
| F-09 | Low | FLAG_SECURE | ADP-11 |
| F-10 | Low | Lock default off | ADP-10 |
| F-11 | Low | FCM token/lockscreen | ADP-09 |
| F-12 | Info | Secrets | ADP-12 |
| F-13 | High | targetSdk 34 | P-02 |
| F-14 | High | Release provenance | P-03 |
| F-15 | High (conditional) | iOS | P-01 |
| F-16 | Medium | Updater memory/size | P-05, P-06 |
| F-17 | Medium | Backup/D2D | P-08 |
| F-18 | Medium | R8/symbols | P-09 |
| F-19 | Low | Receivers/permissions | P-10, P-11 |
| F-20 | Low | Repo hygiene | P-13 |
| F-21 | Info | Dependencies/CVEs | P-12 |
| F-22 | Medium | Sync starvation/eviction | AQ-05 |
| F-23 | Medium | Offline cold start/region | Lead + AQ (region) |
| F-24 | Medium | Module gating | AQ-08 |
| F-25 | Medium | Maintenance gate | AQ-09 |
| F-26 | Medium | Error leakage | AQ-10 |
| F-27 | Medium | Route guard/deep links | AQ-01 |
| F-28 | Medium | Accessibility | AQ-11 |
| F-29 | Medium | Contrast | AQ-12 |
| F-30 | Medium | Performance | AQ-07, AQ-13 |
| F-31 | Medium | Test coverage | AQ-15 |
| F-32 | Medium | Maintainability | AQ-06, AQ-14, P-12 |
| F-33 | Low | Dead code/docs | AQ-16 |
| F-34 | Info | Analyzer/lints | AQ baseline |

### B. Commands used (reproducible)

```bash
# Static analysis
dart analyze
flutter analyze

# Tests + coverage
flutter test --reporter compact
flutter test --coverage
awk -F: '/^LF:/{lf+=$2} /^LH:/{lh+=$2} END{printf "LF=%d LH=%d pct=%.1f%%\n", lf, lh, lh*100/lf}' coverage/lcov.info

# Builds
flutter build apk --release
flutter build appbundle --release

# Artifact inspection
BT="$HOME/Library/Android/sdk/build-tools/36.1.0"
"$BT/aapt2" dump badging build/app/outputs/flutter-apk/app-release.apk
"$BT/apksigner" verify --print-certs build/app/outputs/flutter-apk/app-release.apk
"$BT/aapt2" dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-release.apk

# Dependencies
flutter pub outdated

# Runtime (API 36 emulator)
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s emulator-5554 shell am start -n co.in.ciss.ciss_mobile/.MainActivity
```

The OSV query was a `POST https://api.osv.dev/v1/querybatch` over all packages in `pubspec.lock` at their locked versions; the live update check was a read-only `GET https://cisskerala.site/api/public/app-update`.

### C. What was not reviewed

- Backend code, database schema, Firestore rules, and server-side authorization.
- Native Android/iOS code beyond `MainActivity`, `ApkInstallerPlugin`, `DeviceCompatPlugin`, `CissMobileApplication`, and the manifests.
- CI secrets, Play Console, and the production keystore itself.
- Third-party SDK internals (Firebase, geolocator, mobile_scanner, flutter_background_service).
- Runtime with authenticated accounts, biometric hardware, real GPS, or poor networks; no interception/proxy testing.
- iOS build (no Xcode/CocoaPods).
- Legal/compliance review of privacy copy.

### D. Audit artifacts

| Path | Contents |
|---|---|
| `audit/CISS-Mobile-audit-2026-10-22.md` | This report |
| `audit/areas/platform-and-release.md` | Platform/release/dependency detail (13 findings) |
| `audit/areas/auth-data-privacy.md` | Auth/data/privacy detail (12 findings) |
| `audit/areas/architecture-quality.md` | Architecture/UX/test detail (16 findings) |
| `audit/evidence/launch2.png` | Pre-login notification permission prompt |
| `audit/evidence/launch3.png` | Region selector |
| `audit/evidence/login_hub.png` | Login hub |

---

## 13. Conclusion

CISS-Mobile is not a prototype: it has a real design system, a broad feature set, a careful session layer, encrypted offline writes, a working signed build, and 167 green tests. The audit did not find a remote-code-execution or credential-exfiltration flaw in the client. What it found is a **data-lifecycle problem concentrated on shared devices** and a **release-engineering problem concentrated in CI**:

- The app lock protects one route, not the app.
- The cache, queue, GPS spool, and drafts are not owned by an account and are not purged at logout.
- The guard's only secret is a 4–6 digit PIN on endpoints whose throttling the client cannot see.
- The one signed pipeline is red, five releases bypassed it, the Play target API is two levels behind, and iOS cannot ship at all.

Fixing the P0 set is a focused, roughly one-week change: move the lock above the navigator, bind and purge local stores by UID, raise `targetSdk`, delete three imports and tag a release, confirm the PIN backend controls, and make the iOS decision. That would remove every High finding except the conditional PIN/backend risk. The P1/P2 work then turns the offline-first design into something that is both resilient and accountable, and gives the app the route/deep-link, accessibility, and test foundations it needs for the next redesign cycle.

*Report prepared 2026-10-22. Findings are based on the working tree at `edfec10` plus uncommitted redesign changes; re-verify line numbers after the next commit.*
