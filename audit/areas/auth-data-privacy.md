# Auth, Data Protection & Privacy Audit — CISS-Mobile

**Scope / method.** Read-only, evidence-first review of `lib/features/auth/**`, `lib/core/auth/**`, `lib/core/network/{api_client,api_config,auth_repository,guard_pin_verification_adapter,mobile_repository}.dart`, `lib/core/{cache,offline,location,settings,region,update,sync,fcm}/**`, the public/QR attendance flows, `lib/app/router/app_router.dart`, `lib/app/app.dart`, `lib/main.dart`, and the prior security tests (`test/auth_*`, `test/biometric_*`, `test/guard_pin_verification_adapter_test.dart`, `test/auth_lifecycle_integration_test.dart`). No product code, config, or git state was modified. I took the stated baseline (167 passing tests; `dart analyze` clean except three unused imports) as given, re-read the auth/security tests to understand the guarantees they encode, and did not re-run the suite or drive a device/emulator; findings are from source inspection, with behaviour verified by tracing call paths and reading those tests. Line numbers refer to the working tree as found (base commit `edfec10` plus uncommitted teammate edits in `app_router.dart`, `haptics.dart`, `mobile_repository.dart`, `guard_dashboard_screen.dart`; none of those edits change the auth/lock/cache structure below). Anything that can only be settled by the backend is marked **server-side assumption**.

**Baseline considered.** The session layer is deliberately fail-closed: a missing/denied/malformed/mismatched `/api/mobile/session` response signs the Firebase identity out (`lib/core/network/mobile_repository.dart:311-345`), backend-vs-Firebase UID mismatch throws (`lib/core/network/mobile_repository.dart:632-650`), and there is no claims fallback (`lib/core/network/mobile_repository.dart:346-348`). Tests cover those paths plus UID-bound app-lock metadata. The findings below are the gaps those guarantees do not cover.

## Findings summary

| ID | Severity | Title | Evidence (file:line) | Confidence |
|---|---|---|---|---|
| ADP-01 | High | App lock is drawn only by the root `AuthGate`; pushed screens stay visible and interactive after resume | `lib/features/auth/presentation/auth_gate_screen.dart:60-78, 309-324`; `lib/features/guard/presentation/guard_shell.dart:178-205, 248-300` | High (code path); not dynamically re-proven |
| ADP-02 | High | Durable read cache is not uid-scoped, not encrypted, and is served on *any* error — cross-account PII/payslip disclosure | `lib/core/network/mobile_repository.dart:66-81, 172-215, 303-309`; `lib/core/cache/hive_read_cache_store.dart:17-27`; `lib/core/cache/read_cache.dart:84-100, 116-119` | High |
| ADP-03 | High | Guard authentication is a 4–6 digit PIN with no client-side throttling on unauthenticated login/PIN-setup endpoints | `lib/features/auth/presentation/role_login_screen.dart:215-217, 280-313`; `lib/core/network/mobile_repository.dart:682-702, 776-806`; `lib/features/auth/presentation/guard_pin_setup_screen.dart:81-85` | High for client facts; server rate limiting unknown |
| ADP-04 | Medium | Sign-out (and fail-closed sign-out) does not purge local PII; drafts/spool/queue can resurface or upload under the next account | `lib/features/auth/application/auth_controller.dart:120-133, 481-502`; `lib/core/location/tracking_buffer.dart:47-55, 150-156`; `lib/core/sync/sync_service.dart:148-187`; `lib/core/offline/draft_service.dart:8-11`; `lib/features/guard/presentation/screens/guard_incidents_screen.dart:48-71` | High for retention; Medium for cross-account replay |
| ADP-05 | Medium | No privacy notice or consent for continuous background location + device telemetry; collection starts automatically at clock-in | `lib/features/auth/presentation/permission_onboarding_screen.dart:78-100, 102-143`; `lib/features/guard/presentation/screens/guard_attendance_screen.dart:601-625`; `lib/core/location/background_tracking_service.dart:294-318, 324-361` | High |
| ADP-06 | Medium | Unsigned server-driven trust: region Firebase config, API base URL, and update APK metadata are accepted without pinning/allowlisting | `lib/core/region/region_service.dart:142-170, 215-235, 288-310, 375-386`; `lib/core/update/app_update_service.dart:101-133`; `lib/core/update/apk_downloader.dart:100-107`; `lib/core/network/api_config.dart:4-7` | High for absence of validation; impact conditional on HQ/TLS compromise |
| ADP-07 | Medium | Unauthenticated attendance endpoints return guard PII/site catalogue and accept anonymous submissions with client-supplied GPS and no mock-location signal | `lib/core/network/mobile_repository.dart:1014-1016, 1049-1066, 1102-1161, 1205-1215`; `lib/features/attendance_qr/qr_attendance_flow.dart:837-894`; `lib/app/router/app_router.dart:155-174` | High for client behaviour; server enforcement unknown |
| ADP-08 | Medium | Full session payload, Firebase uid, and precise GPS coordinates are written to `debugPrint` logs in release code paths | `lib/core/network/mobile_repository.dart:324-325, 353-358`; `lib/core/location/background_tracking_service.dart:585-590` | High |
| ADP-09 | Low | FCM device token is never unregistered on sign-out; notification content is left to OS defaults and can appear on the lock screen | `lib/core/fcm/notification_service.dart:82-147, 194-201, 205-225`; `lib/core/network/mobile_repository.dart:87-99, 467-483` | Medium (dispatch is server-side) |
| ADP-10 | Low | Each fresh PIN/password login silently disables an existing app lock unless the user re-ticks the checkbox (default off) | `lib/features/auth/presentation/role_login_screen.dart:69, 160, 184`; `lib/features/auth/application/auth_controller.dart:399-431, 441-462` | High |
| ADP-11 | Info | App lock is a UI gate with no cryptographic/credential binding, no `FLAG_SECURE`, and no idle timeout | `lib/core/auth/biometric_service.dart:199-233`; no `FLAG_SECURE` in `android/app/src/main` (native scope: platform auditor) | High |
| ADP-12 | Info | Secrets scan: no PIN/password/session token is persisted by app code; committed Firebase keys are public identifiers; one admin email is committed in `mobile.env` | `lib/main.dart:51-58`; `lib/core/auth/saved_accounts_service.dart:17-20`; `lib/firebase_options.dart:22-48`; `mobile.env` | High |

Severity note: ADP-03 is graded High **if** the backend has no per-identity/IP throttling or lockout on `/api/guard/auth/login` and `/api/guard/auth/setup-pin`; if it does, this drops to Low. ADP-07's live impact is likewise backend-dependent, and both public attendance screens are currently unreachable in-app (see the finding).

---

## ADP-01 — App lock is bypassed on any pushed screen

**Impact.** A user who has enabled the biometric app lock retains protection only while the router is showing `/`. Every detail screen opened with `Navigator.push` (payslips, profile with documents, incidents, leave, patrol, training, evaluations, notification inbox, FO work orders/reports) is a separate route above `AuthGate`. Locking/relocking is a `setState` inside `AuthGate`, so on background→resume the locked state rebuilds only underneath the pushed route. Sensitive content (salary slips, ID documents, incident text, guard lists) remains on screen without a successful biometric check.

**Evidence.**
- `AuthGate` is the page builder for `/` only (`lib/app/router/app_router.dart:81-90`); the guard/FO shells are returned *inside* its `build` (`lib/features/auth/presentation/auth_gate_screen.dart:333-337`).
- Relock is local state on resume: `didChangeAppLifecycleState` only does `setState(() { _authenticated = false; ... })` (`lib/features/auth/presentation/auth_gate_screen.dart:59-78`), and the lock widget is returned from `AuthGate.build` (`:309-324`). There is no overlay above the `Navigator`, no `popUntil('/')`, and no lock route.
- Sub-screens are pushed as siblings into the root navigator, e.g. `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GuardPayslipsScreen()))` and the other `GuardRecordCard` handlers (`lib/features/guard/presentation/guard_shell.dart:178-205, 248-300`); same pattern in `lib/features/field_officer/presentation/field_officer_shell.dart:221-310, 504`.
- The only lock observer in the app is `AuthGateScreen` (`grep AppLifecycleState` → `auth_gate_screen.dart`, `qr_attendance_flow.dart`, `app_lock_lifecycle.dart`).
- Existing tests only exercise the gate as the visible `home:` widget, so they cannot catch this (`test/auth_lifecycle_integration_test.dart:725-763, 766-817`).

**Attack / failure scenario.** Guard enables the app lock, clocks in, opens *Salary Payslips* (pushed route), then hands the phone over / leaves it. Attacker backgrounds and resumes the app. `AuthGate` arms the lock and may raise a biometric prompt, but cancelling or failing that prompt (or simply having biometrics become unavailable — the "not enrolled / locked out" branches at `auth_gate_screen.dart:105-128` only set an error message) leaves the payslip route on top and interactive. Back navigation reaches the locked gate, but the data was already readable. The same applies to an FO viewing a guard-detail/report screen. Recents-snapshot exposure compounds it (ADP-11).

**Remediation.** Enforce the lock above the entire navigator, not inside one page: wrap the router (`MaterialApp.router.builder`, alongside `AppUpdateGate`) or the root `Navigator` with a lock overlay driven by a uid-scoped lock provider; when the lock arms, `push` a full-screen lock route or `popUntil` the root before rendering any child. Alternatively, make every full-screen destination a gate-aware route. Add `FLAG_SECURE` while the lock is armed and after any timeout. Add a widget test that pushes a route on top of `AuthGate`, backgrounds/resumes, and asserts the secret text is not reachable/visible.

**Verification.** Reproduce with a widget test: pump `MaterialApp` with `AuthGateScreen` as `/`, push `MaterialPageRoute` showing marker text, send `paused` then `resumed`, complete the fake biometric with `failed`; current code still finds the pushed marker (the pushed route is in the same navigator with `maintainState: true`). After the fix, the marker must be covered/pop'd and only the lock screen reachable.

**Uncertainty.** The biometric prompt itself is raised from the offstage gate's post-frame callback, so a system dialog may appear over the pushed route. That does not protect the screen: the dialog is dismissible, and when biometrics are unavailable the code path sets a message instead of covering the route.

---

## ADP-02 — Read-through cache: cross-account disclosure of payslips, incidents, guard lists

**Impact.** Fourteen authenticated read endpoints are cached to an unencrypted Hive box. The cache key is `region|path|query` — no uid or role — the cache is never cleared on sign-out, and it is returned for **every** failure, not just offline. On a shared device, guard B can be shown guard A's salary, leave, incident and dashboard data; field officer B can see field officer A's district guard list (names/phones). Because the fallback runs before error typing, a 401/403/500 or even "not authenticated" also serves the stale payload, which undermines the app's otherwise fail-closed session handling.

**Evidence.**
- Allowlist includes `/api/guard/payslips`, `/api/guard/leave`, `/api/guard/incidents`, `/api/guard/dashboard`, `/api/field-officer/guards`, `/api/field-officer/sites`, `/api/field-officer/incidents`, `/api/field-officer/dashboard`, `/api/field-officer/work-orders`, `/api/field-officer/visit-reports`, `/api/field-officer/training-reports` (`lib/core/network/mobile_repository.dart:66-81`).
- Key omits uid/role: `final region = _regionService.activeRegion?.code ?? 'KL'; return '$region|$path|$qs';` (`lib/core/network/mobile_repository.dart:172-178`).
- On error the cache is read and returned before any error-type decision; `_authHeaders()` throwing `StateError('Not authenticated')` is inside the same `try` (`lib/core/network/mobile_repository.dart:188-215, 303-309`).
- Persisted store opens the box with **no cipher**, unlike the offline queue/settings boxes (`lib/core/cache/hive_read_cache_store.dart:17-27` vs `lib/main.dart:52-59`).
- `ReadCache.clear()` exists (`lib/core/cache/read_cache.dart:116-119`) but has no caller anywhere in `lib/` (verified by grep); logout cleanup only touches notifications and tracking (`lib/features/auth/application/auth_controller.dart:481-502`).
- Read fallback ignores age (`readJson`, `lib/core/cache/read_cache.dart:84-100`); TTL is never enforced on the fallback path.
- Payslip summaries contain net pay (`lib/core/models/payslip_models.dart:5-19`).

**Attack / failure scenario.** A guard phone is shared across shifts. Guard A views payslips/dashboard online (cache written). A signs out; the Hive box survives. Guard B signs in (network required), then loses connectivity (normal in field conditions) or one request returns 401/403/500; `_getJson` returns A's cached JSON and B's UI renders A's salary/leave/incidents. Even without a second account, a revoked/disabled account keeps seeing stale data because cached payloads shadow 401/403/500.

**Remediation.** Include `role:uid` (or a per-account cache namespace with a rotating uuid) in the key; clear or re-key the cache on every session change and on sign-out; only serve cache for genuine transport failures (connection/timeout/5xx-queueable), never for 401/403/`Not authenticated`; encrypt the box with the same cipher as the offline queue; enforce a max age on fallback; add a "purge local data" step to logout.

**Verification.** Unit test with two `MobileRepository` instances sharing one Hive store: write user A's payload, make the API fail for user B with 401, assert no data is returned (and, separately, that the key contains B's uid). Test sign-out calls the purge hook.

---

## ADP-03 — Guard PIN entropy and unauthenticated PIN endpoints

**Impact.** The guard's only secret is a 4–6 digit PIN (10 000–1 000 000 space; 4 is allowed and is the UI's implicit minimum). Login requires no CISS session: the client posts employee ID/phone + PIN to the backend and receives a Firebase custom token in return. There is no client attempt counter, cooldown, CAPTCHA, or lockout, and the PIN-setup endpoint is also unauthenticated and takes employee ID + phone + date of birth + new PIN. If the server does not throttle per identity/IP — and nothing in the client assumes or surfaces such a limit except Firebase's own `too-many-requests` mapping for FO email/password — an attacker with a predictable employee ID (`CISS/TCS/2025-26/871` format) can brute force or spray PINs, and potentially reset a PIN via setup if the server does not refuse to overwrite an existing one.

**Evidence.**
- PIN policy is only `RegExp(r'^\d{4,6}$')` at both entries (`lib/features/auth/presentation/role_login_screen.dart:215-217`; `lib/features/auth/presentation/guard_pin_setup_screen.dart:81-85`).
- Login posts the PIN to `/api/guard/auth/login` and receives a custom token; no lockout state (`lib/core/network/mobile_repository.dart:776-806`). The biometric-enable re-verification uses the same endpoint (`:874-909`).
- Setup posts employee ID/phone/DOB/PIN to `/api/guard/auth/setup-pin` (`lib/core/network/mobile_repository.dart:682-702`). The client only neutralises error text to prevent identity enumeration (`:704-742`), which is good but not a control.
- No client-side attempt/cooldown logic in `lib/features/auth/**`, `lib/core/auth/**`, or `lib/core/network/**` (verified by grep for attempt/throttle/cooldown/lockout).
- Firebase-side `too-many-requests` handling exists only for FO email/password and reset (`lib/core/network/mobile_repository.dart:613-630, 652-669`), not for guard PIN login.

**Attack / failure scenario.** Attacker knows or guesses a guard's employee ID (printed on uniforms/QR codes, sequential) or phone number. They script `/api/guard/auth/login` across the 4-digit space. A hit yields a Firebase custom token, i.e. full guard account access (attendance fraud, payslips/profile, tracking visibility). Separately, if `/api/guard/auth/setup-pin` permits overwriting a PIN for an existing employee, knowing a phone number + DOB (often obtainable from HR documents/social engineering) is enough for takeover.

**Remediation (client side, defence in depth).** Raise the PIN minimum to 6 digits with a weak-PIN deny list, add a client-side attempt counter/backoff (per login ID, persisted) that delays submissions and surfaces "try later", add screenshot/emulator/tamper hints where feasible, and require a device-bound step for PIN setup. The authoritative fix is server-side: strict per-employee and per-IP rate limiting with exponential lockout, PIN-format enforcement (≥6 digits, no sequential/repeated PINs), and `setup-pin` refusing to overwrite an existing PIN.

**Verification.** Backend test: 20 wrong PINs → 429/lockout, no token issued; `setup-pin` for an employee with an existing PIN → 409 and no change. Client test: after N failures the button disables and a cooldown is persisted. Check the server's lockout is identity-based, not only IP-based (shared guard-room NAT).

**Server-side assumption.** Whether `/api/guard/auth/login` and `/api/guard/auth/setup-pin` implement rate limiting/lockout and whether setup can overwrite an existing PIN is not visible from the client. This finding is High under the "no throttling" hypothesis and Low if the backend is already strict.

---

## ADP-04 — Sign-out leaves local PII behind and allows cross-account replay

**Impact.** Logout is treated as an authentication action only. The local read cache (ADP-02), the offline request queue (which includes base64 attendance photos and full attendance payloads with names/phones/GPS), unencrypted form drafts, the GPS spool file, and downloaded payslip PDFs all survive sign-out. Worse, several of them are not account-scoped: drafts are stored under global keys and auto-restored into the next user's form, and the sync loop flushes the previous guard's buffered GPS samples using whatever session is current. Separately, the fail-closed sign-out path (authoritative session failure) does not stop background tracking or clear FCM topics at all.

**Evidence.**
- Normal logout starts with `beginSignOut` then Firebase sign-out and fires two best-effort cleanups with a 3 s timeout, swallowing failures (`lib/features/auth/application/auth_controller.dart:481-502`). Nothing purges cache/queue/draft/spool or deletes the FCM token.
- Fail-closed sign-out only calls `authRepository.signOut()` (`lib/features/auth/application/auth_controller.dart:120-133`); it never invokes the tracking/topic cleanup used by `AuthController.signOut`.
- Tracking stop is fire-and-forget and only clears the secure session descriptor; the spool is untouched (`lib/core/location/background_tracking_service.dart:101-104`; `lib/core/location/tracking_buffer.dart:47-55, 150-156`). `TrackingBuffer.clear()` has no caller.
- Sync flushes the spool with the **current** repository token: `Options(headers: await _repository.authHeaders())` to `/api/mobile/tracking/batch` (`lib/core/sync/sync_service.dart:148-187`); the queue is replayed the same way (`:224-229`).
- The offline queue stores full request bodies, including `photoDataUrl`, and exposes `clear()` with no caller (`lib/core/offline/offline_queue.dart:15-38, 59-81, 108-111`).
- Drafts are explicitly unencrypted and use global keys: `guard_incident_draft` (`lib/features/guard/presentation/screens/guard_incidents_screen.dart:48-71`) and `field_officer_report_<tab>` (`lib/features/field_officer/presentation/screens/field_officer_reports_screen.dart:1081-1140`); both auto-restore in `initState` for whoever opens the screen.
- Downloaded payslip PDFs are written to the cache directory and never deleted (`lib/features/guard/presentation/screens/guard_payslips_screen.dart:36-47`).

**Attack / failure scenario.** Guard A writes an incident draft (e.g. description of a theft/safety issue and location) and the app is signed out or the phone is reassigned. Guard B opens *Incident Reports*: A's text is pre-filled into B's form and saved under B's session if B edits. A's offline attendance/GPS samples left on disk can be uploaded by B's sync loop under B's token once B is online, mixing identities on the server (or getting rejected, in which case A's location history stays on the device indefinitely). If the tracking-stop invocation is lost after logout, the foreground service keeps sending heartbeats with the previous token until it expires.

**Remediation.** Add `purgeLocalAccountData()` to the single sign-out path (both controller and fail-closed) covering `ReadCache.clear()`, `OfflineQueue.clear()`, `TrackingBuffer.clear()`, draft-box clear, secure tracking session, payslip temp files, and `FirebaseMessaging.instance.deleteToken()`; scope draft keys and spool samples by `role:uid`; make tracking stop awaited and idempotent (and fail-closed sign-out call the same cleanup); optionally keep the queue per-uid and refuse to replay across uids.

**Verification.** Integration test: enqueue an attendance request and write a draft as uid A, sign out, sign in as uid B; assert the queue/draft/spool are empty (or B cannot see/claim them) and that no `/api/mobile/tracking/batch` call carries A's samples under B's token. Unit-test the fail-closed path calls the same cleanup.

---

## ADP-05 — No privacy notice/consent for continuous location and telemetry

**Impact.** After clock-in the app silently starts a foreground location service that uploads the guard's precise coordinates, speed, heading, altitude, activity (still/walking/in-vehicle/bicycle), mocked-location flag, GPS state, battery level, Wi-Fi state and network type every 2–15 minutes, plus attendance photos and geofence data. The only in-app explanation is a one-line permission rationale ("Required for site attendance and geofencing during duty hours") plus a battery-optimization card. There is no consent step, no privacy notice/policy link anywhere in `lib/` (grep for `privacy`/`terms`/`policy` returns nothing relevant), and no information about retention, recipients, or withdrawal. That is a material gap for a workforce-monitoring app under Indian DPDP-style obligations, independent of the security findings.

**Evidence.**
- Permission screen requests only foreground location, camera and notifications, with the short descriptions above (`lib/features/auth/presentation/permission_onboarding_screen.dart:78-100, 102-143`). The background-running card explains *why it must keep running* (`:332-348`) but not the collection itself.
- Tracking starts automatically on check-in, best-effort, with no consent/notice gate (`lib/features/guard/presentation/screens/guard_attendance_screen.dart:601-625`).
- Payload fields per heartbeat (`lib/core/location/background_tracking_service.dart:294-318, 324-361`), uploaded with the guard's Firebase token (`:482-533`) and retried/buffered.
- Exact coordinates are also written to the local spool (ADP-04) and to logs (ADP-08).

**Attack / failure scenario.** Not an attacker scenario: a guard (or a regulator/works council) cannot determine from the app what is collected in the background, for how long it is retained, who sees it (FO live map/`guardLocations`), or how to object. The OS foreground-service notification ("CISS Active Duty — Location monitoring active") is the only ongoing signal. Collection begins automatically on the next clock-in even if the guard never revisited the permission screen.

**Remediation.** Add a first-run (and per-account) consent screen that enumerates: continuous background location, activity recognition, battery/network telemetry, attendance photos, and mock-location detection; link to a privacy policy and retention statement; record consent version/timestamp server-side; require explicit acceptance before the first tracking start (and before attendance submission); provide a visible "tracking active" indicator and an in-app explanation of who can view location. The Aadhaar upload already models this kind of explicit consent (`lib/features/guard/presentation/screens/guard_document_upload_screen.dart:33-34, 418-462`) — reuse that pattern.

**Verification.** UI test asserting tracking does not start until consent is recorded; manual review of the consent text against actual payload fields (list derived from `TrackingSample.toJson`).

**Server-side assumption.** Server-side retention periods and downstream sharing (FO live map, client dashboards) are not visible from the client; the local review can only verify what the client collects and displays.

---

## ADP-06 — Unsigned server-driven trust: region config, API URL, update APK

**Impact.** The client treats HQ responses as fully trusted for security-relevant decisions. `/api/public/regions` and `/api/public/region-config/{code}` supply the Firebase project (apiKey/appId/projectId/storageBucket) the app then initializes, and the API base URL it sends credentials, PINs, attendance photos, and GPS to. There is no signature, pinning, project allowlist, or URL scheme/host validation. The in-app updater downloads an APK from a server-supplied URL and verifies it against a SHA-256 supplied in the *same* response, then installs it (the app holds `REQUEST_INSTALL_PACKAGES`). Anyone who can alter HQ responses (server compromise, DNS/TLS compromise, or an admin panel bug) can point the app at an attacker Firebase project/API and push a matching APK. Module flags/maintenance gates are also unsigned and default to "on" (`gatedRedirect` uses `fallback: true`), so they are advisory UI only.

**Evidence.**
- Region list/config fetched over plain `http.get` with no signature/allowlist (`lib/core/region/region_service.dart:142-170, 215-235`); only a non-empty/complete check exists (`:287-310`), and `apiUrl` is whatever the server sent (`:375-386`).
- That URL becomes the API base for authenticated traffic (`lib/core/network/providers.dart:17-40` via `apiClientProvider`), for PIN login and for heartbeats (`lib/core/location/background_tracking_service.dart:92-94, 482-516`).
- No certificate pinning anywhere (no `badCertificateCallback`; only the badCertificate→non-retryable classification in `lib/core/network/mobile_repository.dart:282-301`). The Android network-security config additionally permits cleartext for `cisskerala.site` and subdomains (`android/app/src/main/res/xml/network_security_config.xml:3-5`) — native scope belongs to the platform auditor; noted here because it is the transport that carries these unvalidated URLs.
- Update metadata comes from `GET {activeApiUrl}/api/public/app-update`; `apkUrl` and `sha256` are both taken from the response and never pinned to a host or signing identity (`lib/core/update/app_update_service.dart:101-133`; `lib/core/update/apk_downloader.dart:52-115`; download/install `lib/core/update/app_update_gate.dart:267-290, 386-399`; browser fallback `:85-92`).
- Module gates fail open when a flag is absent (`lib/core/settings/module_gate.dart:11-12`; `lib/core/settings/route_modules.dart:27-32`); the flags come from an authenticated but unsigned `/api/mobile/settings` (`lib/core/network/mobile_repository.dart:1294-1298`).
- On a non-KL region, background heartbeats fall back to the *default* Firebase auth if regional init fails (`lib/core/location/background_tracking_service.dart:655-684`), sending a Kerala-project token to the regional API host.

**Attack / failure scenario.** If the HQ control plane or `/api/public/region-config/*` is compromised (or TLS is stripped for a subdomain where cleartext is permitted), the next region selection/activation persists an attacker project + API URL in secure storage; the guard then enters their employee ID and PIN into the attacker API (plaintext server-side), and a "force update" response installs an attacker APK whose SHA matches. Module/maintenance flags can also be flipped to hide features or block the app, though hiding is cosmetic.

**Remediation.** Treat region config as data, not authority: pin the regional Firebase project IDs and API hosts to a build-time allowlist, require `https` and reject any other scheme, sign region/update payloads (offline signature verified with an embedded public key) or serve them through a pinning/hardening layer, pin the APK signing certificate (verify `PackageInfo.signingInfo`/signature digest, not just a server-provided hash), and make module gates fail closed (or clearly label them as UX-only). Fix the background-region fallback to refuse to send a token to a host it was not minted for.

**Verification.** Inject malformed/malicious region config and update responses in tests: non-https `apiUrl`, unknown projectId, and a valid hash for an APK signed by a different certificate must all be rejected. Inspect the installed APK's signature through `PackageInfo`.

**Server-side assumption.** Whether HQ/region-config is authenticated or signed out-of-band, and whether an independent channel verifies APK signatures, is not visible from the client. The finding is about the client's missing validation, not a claim that HQ is compromised today.

---

## ADP-07 — Public attendance endpoints: PII lookup, site catalogue, anonymous submission

**Impact.** The client contains fully-implemented unauthenticated attendance flows. It calls `/api/public/attendance` with no auth and parses a site catalogue (site/client names, coordinates, duty points, geofence radius, shift templates); it calls `/api/public/attendance/identify` with an employee ID, phone, resource ID, or raw QR value and parses name, phone, client, last-attendance hint, and a `verificationToken`. Photo upload token + upload and `/api/attendance/submit` are then called anonymously with that token. The client is built to expect all of this without a session. Submission carries client-supplied GPS (`locationCoords`, distance to site, accuracy) but no `isMocked` signal, unlike the tracking heartbeat. If the backend returns the same data to unauthenticated callers and does not independently enforce geofence/IP/mock-location/verification-token binding, the public endpoints permit guard enumeration and attendance fraud. The site-catalogue call is live (guard attendance and incident screens read it through `attendanceSitesProvider`), while the identify/upload/anonymous-submit path is currently reachable only from the unroutable `/qr-attendance` and `/attendance` screens. Mitigating fact: both screens are currently unreachable — no `go`/`push` call targets them and the Android manifest registers no deep-link intent filter (only MAIN/LAUNCHER, `android/app/src/main/AndroidManifest.xml:66-83`) — so the identify/upload/anonymous-submit capability is latent client code plus live backend surface, not a reachable in-app path today.

**Evidence.**
- Site catalogue fetched anonymously (`lib/core/network/mobile_repository.dart:1014-1016`), including coordinates parsed into `SiteOptionModel`; this is the production path for the guard attendance and incident screens (`lib/features/guard/presentation/screens/guard_attendance_screen.dart:102, 722, 1383`; `lib/features/guard/presentation/screens/guard_incidents_screen.dart:203`).
- Identify by employee ID / phone / resource ID / QR, anonymous (`lib/core/network/mobile_repository.dart:1023-1066`), parsed into name/phone/client/verificationToken (`:1068-1100`).
- Photo upload token and upload both skip auth with `kSkipApiAuth` (`lib/core/network/mobile_repository.dart:1124-1155`).
- `submitAttendance` drops authentication whenever a `verificationToken` is present (`lib/core/network/mobile_repository.dart:1205-1215`).
- QR flow builds the submission with employee name/phone/client, raw GPS and `attendanceVerificationToken`, then uploads and submits anonymously (`lib/features/attendance_qr/qr_attendance_flow.dart:837-894`); offline replay refreshes the token and uses skip-auth (`lib/core/sync/sync_service.dart:194-229`).
- The payload contains no mock-location flag; only the tracking heartbeat has `isMock` (`lib/core/location/tracking_sample.dart:24-58`).
- Routes exist but are unreachable: `lib/app/router/app_router.dart:155-174`; no route push to them anywhere in `lib/` (grep) and no VIEW intent filter in the manifest.

**Attack / failure scenario.** With a scripted client: enumerate employee IDs/phones against `identify` to harvest guard names and phone numbers, then submit a clock-in for a chosen guard from any location using a mock-GPS device, a photo, and the returned verification token. Whether this succeeds depends on server-side token binding, geofence/IP checks, and mock-location detection. The same endpoints let anyone pull the client site/geofence list if they are truly public.

**Remediation.** Remove the unused public screens/routes or wire them behind authentication; on the server, bind verification tokens to employee + site + short expiry + single use, rate-limit `identify`, require a second factor for public submissions (site kiosk device credential / OTP), return the minimum PII needed (mask phone), reject `isMocked` positions, and enforce geofence server-side. If the public attendance capability is intentional, document the anonymous threat model and keep the client payload rich enough for server-side anti-spoofing (include `isMocked`, location timestamp, accuracy, sensor/source, and Play Integrity attestation).

**Verification.** Backend tests: unauthenticated `identify` rate limit, token cannot be reused across employee/site, submission from 10 km away/mock location rejected. Client test asserting the QR flow is not routable (or is auth-gated) in release.

**Server-side assumption.** Server-side authorization and integrity checks for the public attendance endpoints are not visible in this repository.

---

## ADP-08 — PII and coordinates in release-build logs

**Impact.** Two unconditional `debugPrint` calls leak sensitive data to the platform log in every build (Flutter `debugPrint`/`print` are not stripped in release):
1. the entire authoritative session JSON (displayName, primaryId, email, employeeDocId, assigned districts, district, clientName, stateCode) plus the Firebase uid;
2. precise GPS coordinates (5 decimal places ≈ 1 m) with geofence status on every heartbeat, in the background service.

On Android, logcat is readable by the device shell/bug-report tooling and any process with `READ_LOGS`/root; on iOS, device console logs are accessible in diagnostic profiles. Combined with stack traces logged at `mobile_repository.dart:324-325`, this exposes identifiers and location to whoever collects logs.

**Evidence.**
- `debugPrint('_resolveSessionFromBackend: received data=$data, user.uid=${user.uid}')` (`lib/core/network/mobile_repository.dart:353-358`).
- `debugPrint('Tracking [$locationSource]: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)} ...')` (`lib/core/location/background_tracking_service.dart:585-590`).
- Session-resolution errors + stack trace (`lib/core/network/mobile_repository.dart:324-325`), sign-out failure with error context (`:334-345`).
- No `kDebugMode`/`kReleaseMode` guard on these calls (grep of `debugPrint` usages; only business/error messages elsewhere).
- Related telemetry: Crashlytics installs global Flutter/platform error handlers (`lib/main.dart:27-41`) and the background isolate forwards fatal isolate errors (`lib/core/location/background_tracking_service.dart:249-260`); no `setUserIdentifier`/custom keys are used, so reports are not directly attributed, but uncaught exception messages can carry server error text. This is secondary to the explicit logs above.

**Attack / failure scenario.** A field-support engineer captures a bug report/logcat from a guard's device for an unrelated crash; the log contains the guard's name, employee doc ID, email, district and a trail of GPS fixes. Logs shared in a ticket/chat then become a location-history disclosure. On rooted/compromised devices or MDM log collection this is direct.

**Remediation.** Delete the session payload log; log at most a role + hashed uid behind `kDebugMode`. Remove or redact coordinate logging (log distance/zone booleans only, and only in debug). Add a lint/review rule against logging response bodies and coordinates; strip verbose logging in release builds (`kReleaseMode` guards).

**Verification.** Build release, run the login and a heartbeat, `adb logcat | grep -i ciss` — no email/uid/coordinates should appear.

---

## ADP-09 — FCM token and notification content survive sign-out

**Impact.** Sign-out unsubscribes the topics known to the current process but never calls `FirebaseMessaging.instance.deleteToken()` or deletes the server-side `fcmTokens/{uid}_mobile` record. The device's push token stays bound to the previous account, so on a shared/reassigned device the previous guard's personalised pushes (leave status, payslip, attendance reminders, district broadcasts) can still arrive after logout or under a new user. Foreground notifications are posted without an explicit Android visibility (`AndroidNotificationDetails.visibility` is left null), so on lock screens configured to show notification content the full title/body — guard names, site, leave status — appears even while the CISS app lock is armed.

**Evidence.**
- Token is written to the API with a direct-Firestore fallback at `fcmTokens/{user.uid}_mobile` (`lib/core/network/mobile_repository.dart:87-99, 467-483`; token refresh `lib/core/fcm/notification_service.dart:110-112`).
- `clearTopicSubscriptions()` only unsubscribes locally tracked topics (`lib/core/fcm/notification_service.dart:194-201`); no `deleteToken`/server delete exists (grep).
- Sign-out cleanup fires it best-effort and swallows failures (`lib/features/auth/application/auth_controller.dart:481-502`).
- Foreground messages are re-posted locally with the server-provided title/body and no visibility/redaction settings (`lib/core/fcm/notification_service.dart:205-225`); the background handler only logs the message id (`:348-351`), so server `notification` payloads are what the OS displays.

**Attack / failure scenario.** Guard A logs out and hands the phone to Guard B. A's FCM token document still points at this device. A leave-rejection or payslip notification arrives with A's name/status on the lock screen; B taps it, the app opens at the gate (notification taps always `go('/')`, `:292-309`), but the content is already disclosed. If B's session is active, taps only move tabs — but the notification itself is the leak.

**Remediation.** On sign-out call `FirebaseMessaging.instance.deleteToken()` and delete/mark the server-side token record before clearing the session (or make the backend invalidate token↔uid bindings on logout); set Android notification `visibility: NotificationVisibility.private` and `DarwinNotificationDetails` with generic content when the app is locked; suppress local notification display while the app lock is armed.

**Verification.** Device test: log in as A, sign out, send an A-targeted push; no notification should arrive. Repeat with B signed in; B must not receive A's pushes. Lock the app and send an FO push; the lock screen must not show guard names/details.

**Server-side assumption.** Whether the backend re-validates the token's owning uid at send time (e.g. by deleting tokens on logout or checking a session record) is not visible from the client.

---

## ADP-10 — App lock silently disabled by the next login

**Impact.** The login screen's "Use biometrics to unlock this account" checkbox defaults to unchecked on every visit. `_prepareAccountForSession` treats a fresh credential login as recovery and clears the stored app-lock flag when `requested == false` (`auth_controller.dart:451-461`). So a user who enabled the lock, signed out, and signs back in without noticing the unchecked box loses the lock without any warning — the protection silently weakens exactly for users who rely on it. This is a control-durability issue, not a bypass of an enabled lock.

**Evidence.**
- `_enableBiometric` initialised `false` (`lib/features/auth/presentation/role_login_screen.dart:69`) and passed as `saveForBiometric` on both login paths (`:160, :184`).
- On login with `requested == false`, an existing enabled flag is durably set to false (`lib/features/auth/application/auth_controller.dart:441-462`), then saved into the account record (`:399-431`). The UI never shows the prior state or asks to confirm disabling.

**Attack / failure scenario.** Guard enables the lock; later signs out to hand the phone to a supervisor for a call, signs back in, and pockets the phone assuming the lock is still active. The phone is now readable without biometrics. Also, if `checkFingerprintSupport()`/`authenticateFingerprint()` throws while the user *did* request the lock, the catch returns `existing ?? false` (`auth_controller.dart:476-478`) and the login proceeds with the lock off.

**Remediation.** Persist the per-uid app-lock preference and pre-check the box with a clear "App lock is on — keep it?" state; when a user unchecks it, confirm the disable explicitly; never silently flip the durable flag. On verification failure, keep the existing lock state rather than falling back to `false`.

**Verification.** Widget test: enable lock, sign out, log in again with the box untouched; assert the lock remains enabled or the user is explicitly asked. Test the throwing-biometrics path preserves the prior flag.

---

## ADP-11 — App lock has no cryptographic binding, recents protection, or idle timeout (Info)

**Impact.** The biometric app lock is a local boolean gate around a live Firebase session; it is not bound to a key or credential. Any biometric enrolled on the device — including one added later by someone who knows the device PIN — unlocks it; there is no `CryptoObject`/key-invalidation on enrolment change and no server re-verification on unlock (by design). There is no `FLAG_SECURE`, so Android's recents thumbnail and screenshots of payslips/documents are allowed, and there is no idle timeout, so a foregrounded device stays unlocked indefinitely. This is a hardening/limitations note rather than a defect: the lock is documented as an app lock, not an authentication factor.

**Evidence.**
- App-lock prompt uses `authenticateFingerprint` with `biometricOnly: true` (`lib/core/auth/biometric_service.dart:199-233`), which is the right choice for the lock. The unused `authenticate()` helper allows device-credential fallback (`:120-171`) — it is currently called nowhere; if ever wired into the lock it would weaken the policy.
- Lock state is a uid-bound secure-storage flag (`lib/core/auth/saved_accounts_service.dart:17-20, 187-216`), no key material.
- No `FLAG_SECURE`/secure-window call anywhere under `android/app/src/main` (verified by grep; native ownership: platform auditor). No idle-timer logic exists in `app_lock_lifecycle.dart` (`:1-38`) — only background→resume.

**Remediation.** Document the threat model in the UI; optionally gate app-lock secrets with `AndroidOptions.biometric`/`KeychainAccessibility.when_unlocked_this_device` and invalidate the lock when enrolment changes; set `FLAG_SECURE` while sensitive screens or the lock are shown; add an optional idle timeout; remove the unused device-credential fallback helper to prevent future misuse.

**Verification.** Enrol a new fingerprint while the app is locked, then unlock with the new finger — current behaviour succeeds; decide whether that is acceptable and document it. Take a recents screenshot of the payslip screen — content is visible.

---

## ADP-12 — Secrets/storage scan result (Info)

**Impact.** No app code persists a PIN, password, or Firebase ID token in plaintext. The offline queue's AES key is a generated 256-bit key kept in `flutter_secure_storage` (`lib/core/offline/offline_queue.dart:13-38`), the queue and settings boxes use it, and `flutter_secure_storage 10.0.0`'s default `AndroidOptions()` encrypts with a KeyStore-wrapped AES key (RSA-OAEP key wrapping / AES-GCM). Saved-account metadata (login ID, display name, uid, lock flag) is in Keychain/secure storage with `first_unlock` accessibility (acceptable; data is not credential material). Committed `lib/firebase_options.dart` and `android/app/google-services.json` contain Firebase API keys/app IDs, which are public identifiers by design. One real but low-severity hygiene issue: `mobile.env` is tracked in git and includes `NEXT_PUBLIC_SUPER_ADMIN_EMAIL` (a personal/admin email), plus the public Firebase web config. No keystore/key.properties is committed (`git ls-files`).

**Evidence.** `lib/main.dart:51-58` (cipher creation/reuse, boxes), `lib/core/offline/offline_queue.dart:13-38`, `lib/core/auth/saved_accounts_service.dart:17-20`, `lib/core/location/tracking_session_store.dart:9-14`, `lib/firebase_options.dart:22-48`, `mobile.env` (tracked; 13 lines), `android/app/src/main/AndroidManifest.xml:41` (`allowBackup="false"`).

**Remediation.** Move `mobile.env` out of VCS (and rotate/avoid embedding admin email), keep `allowBackup=false` and the backup exclusion rules, and leave the public Firebase identifiers as-is (they are not secrets; the corresponding security rules are the control).

**Verification.** `git ls-files | grep -i env` and secret scanning in CI; confirm no keystore or key.properties is tracked.

---

## Already-verified safeguards (not findings)

- **Fail-closed session resolution.** Any missing/denied/malformed authoritative session, or backend-vs-Firebase uid mismatch, clears UI state and signs Firebase out; claims fallback is permanently disabled (`lib/core/network/mobile_repository.dart:311-345, 350-421, 632-650`); covered by `test/auth_security_regression_test.dart` and `test/auth_lifecycle_integration_test.dart`.
- **App-lock metadata is uid-bound** and legacy no-uid records cannot enable a lock; legacy reusable PIN/password keys are purged from secure storage at startup and on account removal (`lib/core/auth/saved_accounts_service.dart:96-98, 203-216`; `lib/core/auth/legacy_biometric_credential_cleanup.dart`; covered by `test/biometric_app_lock_test.dart`, `test/auth_biometric_security_test.dart`).
- **No PIN/password persistence** for the biometric feature — only the boolean flag (`lib/features/auth/application/biometric_setup_controller.dart:52-56, 105-187`).
- **Guard PIN re-verification is identity-pinned:** a disposable, uniquely named Firebase app signs in with the fresh custom token, compares the resulting uid to the active session uid, then signs out and deletes the app; the primary session is never replaced (`lib/core/network/guard_pin_verification_adapter.dart:53-84`; covered by `test/guard_pin_verification_adapter_test.dart`).
- **Role enforcement** on both login paths plus sign-out on mismatch (`lib/core/network/mobile_repository.dart:796-829`; `lib/features/auth/application/auth_controller.dart:307, 358, 433-439`).
- **PIN-setup and login errors are neutralised** to prevent employee/phone enumeration (`lib/core/network/mobile_repository.dart:704-742`; `role_login_screen.dart:164-172`); FO password-reset results are neutral (`:652-669`).
- **401 handling is bounded** (force-refresh + one retry, marker prevents loops) and **403** triggers a settings refresh without altering the error; no request-body/header logging interceptor exists (`lib/core/network/api_client.dart:21-72`).
- **Sensitive identity endpoints are never cached** (`/api/mobile/session` is outside the allowlist, `lib/core/network/mobile_repository.dart:62-81`).
- **No cleartext hardcoded URLs** in Dart; base URL defaults to `https://cisskerala.site` (`lib/core/network/api_config.dart:4-7`).
- **Notification taps cannot route into protected screens** — every tap resolves to `go('/')` or a tab index (`lib/core/fcm/notification_service.dart:246-309`).
- **No native deep links**: the manifest has only MAIN/LAUNCHER (no VIEW filter), and `allowBackup="false"` (`android/app/src/main/AndroidManifest.xml:41, 66-83`). This is why the dead QR/public routes are not currently exploitable in-app.

## Server-side assumptions and open questions

1. **Guard PIN endpoints:** does `/api/guard/auth/login` rate-limit/lock out per employee **and** per IP, and does `/api/guard/auth/setup-pin` refuse to overwrite an existing PIN? Also, is the PIN stored with a memory-hard hash?
2. **Public attendance:** what exactly does unauthenticated `/api/public/attendance/identify` return, are `verificationToken`s bound to employee+site+expiry+single-use, and does `/api/attendance/submit` enforce geofence/IP/mock-location (Play Integrity or equivalent) server-side? Are the `/api/public/*` endpoints rate-limited?
3. **Push/notification data:** does the backend delete or re-validate `fcmTokens/{uid}_mobile` on sign-out/session revoke, and what do Firestore rules allow for `notifications`, `fcmTokens`, and `guardLocations` (the client performs direct Firestore reads for notifications and FO live location)? A weak rule set would let a modified client read other users' records.
4. **Server-driven trust:** is `/api/public/region-config/*` or `/api/public/app-update` signed/authenticated upstream, and is there an independent APK-signature check? Does any region legally return an `http://` `apiUrl` (relevant given the cleartext allowance for `cisskerala.site`)?
5. **Retention:** how long are heartbeats, attendance photos, and session records retained server-side, and are they deleted on employee exit/account closure? (Client-side retention gaps are ADP-04; server-side retention is not visible.)
6. **Module gating:** is the backend authoritative for disabled modules on every request, or is the client's fail-open `fallback: true` the only gate? (Client-side, module flags are cosmetic; `403` already triggers a settings refresh.)
