# CISS-Mobile — Audit Remediation Report

**Date:** 2026-10-22  
**Base audit:** [`CISS-Mobile-audit-2026-10-22.md`](CISS-Mobile-audit-2026-10-22.md)  
**Branch / HEAD:** `wip/redesign-1.0.21` / `edfec10` + working-tree remediation  
**Target:** `1.0.22+22` (`co.in.ciss.ciss_mobile`)  
**Status:** all client-side High findings closed; most coupled Medium findings fixed; remaining items are backend/legal/Xcode/release-ops or larger architecture work. No commit or push was made.

---

## 1. Result at a glance

| Metric | Before | After |
|---|---:|---:|
| `flutter analyze` | exit 1 (3 unused-import warnings) | **exit 0 — No issues found** |
| Tests | 167 passing | **316 passing, 0 failing** |
| Line coverage | 15.3% (2,742 / 17,911) | **18.7% (3,526 / 18,866)** |
| `targetSdk` | 34 | **36** |
| Release APK | 86.7 MB, target 34 | **87.1 MB, target 36** |
| Release AAB | 45.3 MB | **45.5 MB** |
| Cleartext for production host | allowed | **denied** |
| `RECORD_AUDIO` permission | merged into APK | **removed** |
| App lock coverage | `/` route only | **every route (app-level overlay)** |
| Offline cold start | signed out | **restored 24 h session + Offline badge (device-verified)** |

**Finding status:** 14 fixed, 11 partially fixed, 9 open. All **High** findings are closed on the client/config side; the remaining High-adjacent items are server confirmation (F-04), release tagging/publishing (F-14), and Xcode signing (F-15).

---

## 2. What was fixed

### 2.1 App lock and device privacy — F-01, F-09

- New `lib/core/auth/app_lock_controller.dart`: UID-bound lock state machine. It reads `SavedAccountsService.isBiometricAppLockEnabledFor(session)` once per UID, fails closed by signing out when the preference cannot be read, and keeps the lock in sync with `appLockPreferencesProvider`.
- New `lib/core/auth/app_lock_overlay.dart`: `AppLockOverlay` is mounted in `MaterialApp.router.builder`, **above** the Navigator and above `AppUpdateGate`. It covers pushed detail screens, is opaque, consumes all pointer input, and claims/back-stops Android back. The Stack shape is constant, so the navigator stack and screen state survive underneath.
- `AuthGateScreen` is now session→shell/permission routing only (removed 323 lines of lock UI/state).
- `AppLockScreen` preserves the previous credential-recovery copy: retry biometrics, or sign out to use PIN/password. It prompts once per background→resume; `authenticating` suppresses double-arming.
- Only real backgrounding (`paused`/`detached`) arms the lock; transient `inactive` (permission dialog, biometric prompt, shade) does not.
- New `lib/core/security/screen_security.dart`: ref-counted `ScreenSecurity` + `SecureScreen`. `MainActivity.kt` now exposes `co.in.ciss.ciss_mobile/secure_window` and sets/clears `FLAG_SECURE` on the UI thread. Payslips, document upload, and guard profile are wrapped; overlapping screens do not clear the flag early.

### 2.2 Local data lifecycle — F-02, F-03, F-05

- **Read cache:** key is now `region|uid|path|query`; only true transport failures are eligible for fallback (never 401/403/4xx/5xx/`Not authenticated`); fallback is capped at 24 h; timestamps are persisted; the Hive `read_cache` box is opened with the queue's AES cipher; legacy plaintext cache boxes are discarded and recreated encrypted.
- **Offline queue:** `OfflineRequest` carries a nullable `uid`; `OfflineQueue` has `setOwner`/`detachOwner`/`purgeForeignRequests`; enqueue stamps the owner; replay filters by current UID; mismatched/legacy entries are purged, not replayed. Secure-storage failure now fails closed (typed `OfflineQueueUnavailableError`) instead of opening plaintext.
- **Drafts:** UID-namespaced (`uid::formKey`), owner changes purge foreign drafts, ownerless writes are not persisted, and the box is now **encrypted** via `DraftService.openEncrypted` in `main.dart` (legacy plaintext drafts are discarded rather than migrated). Draft writes degrade to a no-op if storage is unavailable instead of throwing from text listeners.
- **Tracking spool:** owner marker (`tracking_spool.owner`); samples cannot be flushed under a different UID; `clear()` removes spool, segments, temp and marker files.
- **Purger:** new `lib/core/privacy/local_data_purger.dart` clears cache, queue, drafts, spool + tracking session, FCM token, and temp `payslip-*.pdf` files. Wired into normal sign-out, fail-closed sign-out, and A→B account changes. Each step is independently timed out and logged without PII.
- **Logs:** removed the full session-payload/UID `debugPrint` and the precise GPS coordinates/geofence distance log. New `PrivacyLog` provides the redaction seam.

### 2.3 Credential hardening — F-04 (client side)

- New `lib/core/auth/pin_policy.dart`: new PINs must be exactly **6 digits** and must not be repeated, sequential, patterned, or common (`123456`, `654321`, `121212`, `520131`, …). Existing 4–6-digit PINs still sign in, so there is no forced reset/lockout.
- New `lib/core/auth/pin_attempt_guard.dart`: per-login-ID (hashed, not stored in clear) attempt counter with escalating cooldowns — 5th failure 30 s, 6th 1 min, 7th 5 min, 8th 15 min, 9+ 30 min. Successful sign-in resets it. Network failures and server 429s do not consume the budget. Storage failures fail open (server remains authoritative).
- `RoleLoginScreen` checks the cooldown before submitting and records only credential failures. Setup screen enforces the 6-digit policy with digits-only/length formatters and updated copy.

### 2.4 Release and platform — F-08, F-13, F-15, F-16, F-17, F-18, F-25

- `targetSdk = 36` (minSdk 24, compileSdk 36); built APK verified as `targetSdkVersion:'36'`.
- Cleartext removed from `network_security_config.xml` (`base-config cleartextTrafficPermitted="false"`, system trust anchors only).
- New `res/xml/data_extraction_rules.xml`: excludes every backup domain from cloud backup and device transfer; manifest adds `dataExtractionRules` and `fullBackupContent="false"`.
- `RECORD_AUDIO` removed from the merged manifest with `tools:node="remove"` (camera/mobile_scanner transitive permission); verified absent from the release APK.
- **iOS:** `Info.plist` now has nine purpose strings (location when-in-use/always, camera, photo read/add, Face ID, motion, microphone), `UIBackgroundModes` location/fetch/remote-notification, portrait-only iPhone, display name “CISS Workforce”; added `ios/Podfile` (iOS 13) and `Runner/Runner.entitlements` (`aps-environment = $(APS_ENVIRONMENT)`) wired via `CODE_SIGN_ENTITLEMENTS`; no ATS exception.
- **Updater:** new `UpdateUrlPolicy` (https only, `cisskerala.site`/subdomains, `/downloads/`, no userinfo/port/dot-segments) applied to download and browser fallback. `ApkDownloader` streams and hashes incrementally, enforces `expectedSizeBytes` with a 5% hard cap, maps ENOSPC to `ApkDiskFullError`, deletes partial files, and prunes stale update APKs. `ApkInstallerPlugin.kt` gained `verifyApk(path, package, signerSha256)` using `PackageManager` and the production certificate `e5ee3fd6…c29aa`; `AppUpdateService.installUpdate` refuses a package/signature mismatch. The manifest SHA-256 remains an integrity check, not authenticity.
- **Gate:** `AppUpdateGate` is now reactive — watches maintenance/forceUpdate, tears the blocking overlay down when flags clear, and re-checks on resume. It renders an in-tree full-screen overlay (it sits above the Navigator, so `showDialog` could not work there).
- **CI:** release workflow retains/uploads `mapping.txt` and Dart symbols (`--split-debug-info`), and fails if they are missing. Analyze/test/signing gates unchanged.

### 2.5 Offline sync and cold start — F-22, F-23

- `OfflineRequest` now persists `nextAttemptAt` and `blocked`; `SyncService` uses per-entry exponential backoff (30 s → 15 min, jitter), skips not-yet-due entries and continues with later ones, and **never deletes** after 20 failures — it marks them blocked and keeps them on disk.
- No in-loop `Future.delayed`; triggers coalesce (`_rerunRequested`), so a connectivity/resume event during a pass causes one additional pass instead of being dropped.
- 3-minute foreground timer + `AppLifecycleState.resumed` flush; connectivity listener kept.
- The pass returns immediately when no user is authenticated and re-checks before every mutation, so a signed-out app cannot consume or replay another account’s queue.
- `OfflineQueue` exposes pending/blocked/evicted counts; `SyncStatusBadge` shows `N pending · M blocked · K dropped` and an “Offline” state, with danger styling when entries are blocked/dropped.
- **Offline session:** `SessionSnapshotStore` persists the last authoritative `AuthSession` in secure storage (`first_unlock_this_device`, 24 h TTL, uid-bound). `MobileRepository` throws `AuthoritativeSessionTransportError` only for no-response Dio failures; `AuthSessionNotifier` restores the snapshot as `offline=true` on those, while 401/403/malformed/UID mismatch still fail closed and clear it. Sign-out and the purger clear it. Auth tokens are **not** serialized into the snapshot.
- **Region:** `RegionService.getSavedRegionConfig()` + `resolveRegionConfig()` read the persisted `ciss_selected_region_config`; `main.dart` uses the live config first, then the cached same-region config, so a non-Kerala user can cold-start offline. Missing/corrupt/mismatched config still fails closed.

### 2.6 Quality quick wins — F-25/F-26/F-29/F-34

- `CissError.parse` no longer returns raw `TypeError`/`StateError`/stack frames/Firebase codes; unmapped errors fall back to “Something went wrong. Please try again.” Short human-readable backend messages are preserved.
- Light-theme status colors darkened for WCAG AA: warning `#8A4A0F` (6.08:1 on its soft tint), success `#14664A` (6.15:1), accent `#8A6A2F` (5.02:1 on white). New `test/contrast_test.dart`.
- `PressableScale` now exposes `Semantics(button:, label:, onTap:)` and honors `MediaQuery.disableAnimationsOf`.
- Three analyzer warnings removed; `flutter analyze` is clean.
- `.gitignore` now covers `android/build/` and `android/.gradle/`.

---

## 3. Finding-by-finding status

| ID | Audit severity | Status | Note |
|---|---|---|---|
| F-01 | High | **Fixed** | App-level overlay above the Navigator; pushed routes covered (widget tests + device boot). |
| F-02 | High | **Fixed** | UID-keyed, encrypted, transport-only, 24 h cap, purged. |
| F-03 | High | **Fixed** | Queue/spool/drafts owner-bound and purged; drafts encrypted; logs redacted. |
| F-04 | High (conditional) | **Partial** | Client: 6-digit new PINs + cooldown. Backend lockout/`setup-pin` overwrite still needs written confirmation. |
| F-05 | Medium | **Fixed** | Session payload/UID and GPS coordinates removed from logs. |
| F-06 | Medium | **Open** | Privacy notice/consent needs product/legal copy and a retention statement; not fabricated. |
| F-07 | Medium | **Open** | Server-side enforcement (identify/token/mock/rate limit); client side unchanged. |
| F-08 | Medium | **Partial** | Cleartext removed, URL policy + signer verification added; server-side manifest signing/pinning remains optional. |
| F-09 | Low | **Fixed** | `FLAG_SECURE` for lock + payslips/documents/profile. |
| F-10 | Low | **Open** | Fresh credential login still disables lock unless re-ticked; product decision. |
| F-11 | Low | **Partial** | FCM token deleted on logout; notification visibility still OS default. |
| F-12 | Info | **Closed** | Secrets scan unchanged; no token persistence. |
| F-13 | High | **Fixed** | `targetSdk 36`; Play upload itself not tested. |
| F-14 | High | **Partial** | Analyze gate green + symbols retained; tagging `v1.0.22` and publishing the manifest need release authorization. |
| F-15 | High (conditional) | **Partial** | Info.plist/Podfile/entitlements added; Xcode team/capabilities, `pod install`, APNs key remain. |
| F-16 | Medium | **Fixed** | Streaming hash, size cap, ENOSPC, cleanup, signer check. |
| F-17 | Medium | **Fixed** | `dataExtractionRules` + `fullBackupContent=false`. |
| F-18 | Medium | **Partial** | Mapping/symbols retained; Dart obfuscation intentionally not enabled yet. |
| F-19 | Low | **Partial** | `RECORD_AUDIO` removed; legacy storage perms and exported plugin receivers remain. |
| F-20 | Low | **Partial** | `.gitignore` fixed; repo history/screenshot purge and key custody remain. |
| F-21 | Info | **Open** | Framework/dependency upgrade not attempted. |
| F-22 | Medium | **Fixed** | Per-entry backoff, no sleep, coalescing, timer/resume, no signed-out replay, blocked kept/visible. |
| F-23 | Medium | **Fixed** | 24 h offline snapshot + cached region config; **device-verified offline cold start**. |
| F-24 | Medium | **Open** | Module gating still inert; needs route refactor or removal. |
| F-25 | Medium | **Fixed** | Reactive maintenance/forceUpdate overlay + resume check. |
| F-26 | Medium | **Partial** | Safe parser fallback; some screens still interpolate `error.toString()`. |
| F-27 | Medium | **Open** | Route-level guard/deep-link refactor not attempted (large, 53 pushes). |
| F-28 | Medium | **Partial** | Shared `PressableScale` semantics/reduce-motion; 45 icon buttons still lack tooltips. |
| F-29 | Medium | **Fixed** | Light-theme contrast passes AA; test added. |
| F-30 | Medium | **Open** | Lazy lists, image cache sizing, duplicate notification pollers, refresh burst. |
| F-31 | Medium | **Partial** | Tests 167→316, coverage 15.3→18.7%; no CI coverage gate yet. |
| F-32 | Medium | **Open** | Layering inversion, provider sprawl, giant screens, framework upgrade. |
| F-33 | Low | **Open** | Dead code/unused deps/stale docs not cleaned. |
| F-34 | Info | **Fixed** | Analyzer clean; lint set still stock. |

---

## 4. Verification evidence

### 4.1 Static and tests

```text
flutter analyze            → No issues found (exit 0)
flutter test               → 316 passed, 0 failed
flutter test --coverage    → 3,526 / 18,866 lines = 18.7%
```

New/updated suites include: `app_lock_overlay_test.dart`, `local_data_lifecycle_test.dart`, `pin_attempt_guard_test.dart`, `pin_policy_test.dart`, `contrast_test.dart`, `ciss_error_test.dart`, `offline_resilience_test.dart`, `session_snapshot_test.dart`, `region_offline_test.dart`, `update_url_policy_test.dart`, `apk_downloader_test.dart`, extended `app_update_gate_test.dart` and `sync_service_test.dart`.

### 4.2 Release builds

```text
flutter build apk --release      → success, 87.1 MB
flutter build appbundle --release → success, 45.5 MB
aapt2 badging                    → targetSdkVersion 36, versionCode 22
apksigner                        → cert SHA-256 e5ee3fd6…29aa (same production key)
merged manifest                  → allowBackup=false, dataExtractionRules, fullBackupContent=false,
                                   networkSecurityConfig, no RECORD_AUDIO
```

### 4.3 Device verification

On a clean API 36 emulator with a real existing session:

| Scenario | Result |
|---|---|
| Normal cold launch | Field-officer dashboard loads; no crash/fatal log |
| Wi-Fi + data disabled, force-stop, cold launch | Dashboard restores from the 24 h snapshot; **“Offline” badge visible**; no sign-out |
| Network restored | Session remains usable; sync resumes |

Screenshots: [`evidence/final_launch.png`](evidence/final_launch.png), [`evidence/offline_cold_start.png`](evidence/offline_cold_start.png), [`evidence/fixed_launch.png`](evidence/fixed_launch.png).

App-lock behavior is covered by widget tests (pushed route covered after `paused`/`resumed`, failed/cancelled prompt keeps the lock, back swallowed) because biometric hardware/prompts are not automatable on this emulator. `FLAG_SECURE` and predictive-back behavior still deserve a physical-device check.

---

## 5. Migration and compatibility notes

1. **New PIN policy:** only *new* PINs must be 6 digits; existing 4–6-digit PINs continue to sign in. No forced reset, but communication to guards is advisable.
2. **Legacy read cache:** an unencrypted `read_cache` box is deleted and recreated encrypted (cache is disposable).
3. **Legacy drafts:** the old plaintext `draft_box` is discarded and recreated encrypted; unsent drafts written before the upgrade are lost. Drafts are convenience data; still worth telling field staff to submit before updating.
4. **Legacy offline queue entries** without a UID are purged when the first account owner is adopted, so they cannot replay under the wrong user. Drain the queue before rolling out, or accept loss of pre-upgrade offline writes.
5. **Legacy tracking spool** without an owner marker is cleared on the first owner adoption; unsent pre-upgrade samples may be lost.
6. **Offline session grace:** a restored session is valid for display/navigation for up to 24 h; all writes still require the backend. This is a deliberate availability/security trade-off, cleared on sign-out/denial.
7. **Updater signer pin:** `AppUpdateService.productionSignerSha256` is hardcoded. If the app is ever re-signed with a new key, this constant must be updated or updates will be refused (by design).
8. **iOS:** the repo now has a Podfile/entitlements but no `Podfile.lock`; run `pod install` on a Mac, set the team/capabilities, and add the APNs key before building.
9. **`targetSdk 36`:** verify foreground-service start while backgrounded, notification permission denial, and edge-to-edge on API 35/36 devices (the code already uses `edgeToEdge` and starts tracking only from the foreground).
10. **No commit/push:** all changes are in the working tree for review.

---

## 6. Remaining work

### Requires backend / security operations
- **F-04:** confirm per-employee and per-IP login throttling/lockout and that `setup-pin` cannot overwrite an existing PIN; add server tests.
- **F-07:** bind public-attendance identify tokens, enforce geofence/mock-location/rate limits, and minimise returned PII server-side.
- **F-08:** consider signing the region/update manifests and pinning the API certificate/public key; currently the client validates URL and APK signer only.
- **F-14:** tag `v1.0.22`, let the signed workflow produce the AAB/APK/SHA256SUMS, then publish that manifest; move to Play App Signing.
- **F-15:** Xcode signing, `pod install`, APNs key/profile, archive, and permission/background-location device tests.

### Requires product/legal decisions
- **F-06:** publish a location/telemetry privacy notice with purpose, fields, retention, recipients, withdrawal and contact; record versioned acceptance and gate tracking start. Copy must be approved, not invented by engineering.
- **F-10:** decide whether a fresh credential login should preserve the existing app-lock flag with an explicit prompt.

### Larger engineering follow-ups
- **F-27/F-24:** introduce real `/guard/*` and `/field-officer/*` routes, move the 53 `Navigator.push` screens to route destinations, add auth/role redirects and deep links, then finish or delete module gating.
- **F-30:** convert eager lists to `ListView.builder`, size network images, consolidate the two 30-s notification pollers, make off-screen providers `autoDispose`, and replace the 15-minute blanket invalidation with TTL-aware refresh.
- **F-31:** add per-directory coverage gates and behavioural tests for guard attendance/field-officer flows.
- **F-32:** move providers out of `presentation/screens`, remove `core → features` imports, decompose the 2.3k–2.8k-line screens, and plan the Flutter/Firebase/Riverpod upgrade.
- **F-18:** decide on `--obfuscate` + symbol retention.
- **F-19:** remove/narrow legacy storage permissions and audit exported plugin receivers.
- **F-26:** finish the typed `AppFailure` migration in screens.
- **F-28:** add tooltips/semantic labels to the remaining icon buttons and text-scale tests.
- **F-33/F-21:** remove dead code/unused codegen deps and upgrade the framework/dependencies.

---

## 7. Files changed (high level)

**New**
- `lib/core/auth/app_lock_controller.dart`, `app_lock_overlay.dart`, `pin_attempt_guard.dart`, `pin_policy.dart`, `session_snapshot_store.dart`
- `lib/core/security/screen_security.dart`
- `lib/core/privacy/local_data_purger.dart`, `privacy_log.dart`
- `lib/core/update/update_url_policy.dart`
- `android/app/src/main/res/xml/data_extraction_rules.xml`
- `ios/Podfile`, `ios/Runner/Runner.entitlements`
- Tests: `app_lock_overlay_test.dart`, `local_data_lifecycle_test.dart`, `pin_attempt_guard_test.dart`, `pin_policy_test.dart`, `contrast_test.dart`, `ciss_error_test.dart`, `offline_resilience_test.dart`, `session_snapshot_test.dart`, `region_offline_test.dart`, `update_url_policy_test.dart`, `apk_downloader_test.dart`

**Modified (principal)**
- `lib/app/app.dart`, `lib/main.dart`, `lib/features/auth/**`, `lib/core/network/**`, `lib/core/cache/**`, `lib/core/offline/**`, `lib/core/sync/**`, `lib/core/location/tracking_buffer.dart`, `lib/core/location/background_tracking_service.dart`, `lib/core/update/**`, `lib/core/region/region_service.dart`, `lib/shared/widgets/sync_status_badge.dart`, `lib/shared/widgets/pressable.dart`, `lib/app/theme/app_tokens.dart`
- `android/app/build.gradle.kts`, `AndroidManifest.xml`, `network_security_config.xml`, `ApkInstallerPlugin.kt`, `MainActivity.kt`
- `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`
- `.github/workflows/build-apk.yml`, `.gitignore`

The full diff is available with `git diff` (plus untracked files); nothing was committed.

---

## 8. Release recommendation

The **client-side P0 set is closed**. Before distributing 1.0.22:

1. Confirm the backend PIN/attendance controls (F-04/F-07) in writing.
2. Run the tag-triggered signed workflow and publish the resulting manifest (F-14); do not hand-build a release.
3. Put the AAB on a Play internal track and run a short field pilot on a low-RAM device with a shared-account test (A logs in, queues, logs out; B logs in; verify no A data appears).
4. Device-test: app lock on a pushed screen with cancel/fail, predictive back, `FLAG_SECURE` screenshot blocking, background tracking after a reboot, notification denial, and an in-app update from 1.0.21 (signature verification must accept the production key).
5. Schedule F-06 (privacy notice/consent) and F-27/F-30/F-32 as the next engineering block; they are not blocked by the fixes above.

*No claim of “all issues fixed”: 14 findings are fully closed, 11 are partially closed, and 9 remain open for the reasons above.*
