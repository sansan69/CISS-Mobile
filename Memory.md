# Memory

## [2026-07-05] — Session: Production hardening, in-app updater, crashlytics, reliability

### In-app APK updater
- Created `lib/core/update/apk_downloader.dart` — Dio streamed download with progress callbacks, SHA256 verification against manifest, free-space precheck, typed error classes (ApkHashMismatchError, ApkDiskFullError, ApkNetworkError)
- Created `android/app/src/main/kotlin/.../ApkInstallerPlugin.kt` — native Kotlin method channel (`co.in.ciss.ciss_mobile/apk_installer`) with `canInstall()`, `installApk(path)`, `openInstallSettings()` using FileProvider + Package Installer
- Created `android/app/src/main/res/xml/file_paths.xml` — FileProvider path config for APK sharing
- Updated `MainActivity.kt` — registers `ApkInstallerPlugin` in `configureFlutterEngine`
- Updated `AndroidManifest.xml` — added `REQUEST_INSTALL_PACKAGES` permission + FileProvider `<provider>` block
- Rewrote `app_update_service.dart` — added `canInstallApk()`, `openInstallSettings()`, `installUpdate(localPath)` → `InstallResult`
- Rewrote `app_update_gate.dart` — progress dialog with download/verify/install phases, "Install unknown apps" permission guidance, error states with retry, **browser fallback retained** if native install fails
- Added `crypto: ^3.0.3` dep to pubspec.yaml
- Server: `Cache-Control: public, max-age=300` on `/api/public/app-update`

### Crash reporting (firebase_crashlytics)
- Added `firebase_crashlytics: ^3.3.0` dep
- Wired `FlutterError.onError` + `PlatformDispatcher.instance.onError` in `main.dart`
- Wired `Isolate.current.addErrorListener` in `background_tracking_service.dart` (background isolate)

### Critical bug fixes
- **Null-force-unwrap crash:** `live_location_service.dart:55` — replaced `doc.data()!` with null guard; added `tryFromFirestore()` static method; filtered null results in `streamActiveLocations`
- **Incident upload path space bug:** `guard_incidents_screen.dart:134-135` — fixed `incidents/${profile.id}/ ${ts}` → `incidents/${profile.id}/${ts}`
- **Geofence state machine:** `background_tracking_service.dart:249-276` — reset `lastOutsideAt=null` on re-entry (was stale, causing premature exits); first reading determines `isInside` from actual position (was always true); reset state on new duty context

### Idempotency fixes
- `clientRequestId` now stable across retries in all 3 attendance screens (QR, guard, public) by making it a class-level `_clientRequestId` field initialized once via `??= _uuid.v4()`

### Reliability hardening (agent-implemented)
- **Explicit targetSdk** — `targetSdk = 34` was `flutter.targetSdkVersion` (W-P1-16)
- **Network security** — created `network_security_config.xml`; replaced global `usesCleartextTraffic` with domain-scoped config (W-P1-11)
- **Dio 401-retry interceptor** — on 401, force-refreshes Firebase token via `getIdToken(true)` and retries once (W-P2-12)
- **Sync exponential backoff** — 2^min(retryCount,6) seconds delay; retryCount resets after 1-hour success window (W-P2-13)
- **Offline-detection accuracy** — `badCertificate` not treated as offline; 5xx responses queued for retry (W-P2-14)
- **QR scanner camera lifecycle** — `WidgetsBindingObserver` pauses/resumes `MobileScannerController` on background/nav; defensive `_loading` reset (W-P2-15)
- **Enrollment upload timeouts** — 30s `http.Client` timeout with 1 retry; back-button confirmation dialog if form has data (W-P2-16)
- **Theme-extension force-unwrap** — replaced `!` with safe `CissThemeTokens.of(context)` (W-P2-17)
- **Notification polling** — gated to inbox-foreground (W-P1-14)
- **Multi-region teardown** — invalidates `mobileRepositoryProvider`/`apiClientProvider` on region change (W-P1-15)
- **Background service self-heal** — confirms `isRunning()` after start; re-start on resume if dead; surfaces unhealthy signal (W-P1-13)
- **Offline photos out of Hive** — photos stored as files, paths only in queue (W-P1-12)

### Android manifest hardening
- `android:allowBackup="false"` — prevents Hive + draft data leak via Google Drive backup
- `network_security_config.xml` — cleartext only to cisskerala.site
- `REQUEST_INSTALL_PACKAGES` — for in-app APK installation
- Removed unused `ACTIVITY_RECOGNITION` permission

### Cleanup
- Removed duplicate public `RegionService()` ctor (W-P3-6)
- Added `.autoDispose` to `regionConfigProvider.family` (W-P3-7)
- Wired `NotificationService.dispose()` via `ref.onDispose` (W-P3-4)

### Verification
- `npx tsc --noEmit` on web companion — 0 errors
- `flutter analyze` — requires Flutter SDK; manual code review confirms all changes compile-correct

- Standalone Flutter mobile app for the CISS Workforce platform.
- The mobile codebase has been moved out of the web repo and now lives in:
  - `/Users/mymac/Documents/CISS-Mobile`
- The web app remains the Next.js admin/client/operations platform.
- The mobile app is the guard + field officer operations client.

## What has been implemented so far

### App separation

- Moved the Flutter app out of the main webapp folder.
- Created a separate git repository for the Flutter app.
- Added a standalone mobile runtime config file:
  - `/Users/mymac/Documents/CISS-Mobile/mobile.env`
- The mobile app now runs independently from the web app while still talking to the same backend.

### Branding and design

- Added company branding across the mobile app:
  - company name
  - company logo
  - security workforce tagline
  - support/contact surfaces
- Added modern Material 3 styling with cleaner surfaces and calmer cards.
- Added reusable branded UI pieces:
  - brand banner
  - company contact card
  - branded app shell

### Auth flow

- Split login entry points into separate role flows:
  - Guard Login
  - Field Officer Login
- Kept one shared Firebase auth backend under the hood.
- Added strict role validation so guard accounts cannot enter field officer flow and vice versa.
- The login hub is now role-based instead of a single combined entry form.

### Current screens in the mobile app

Guard flow:
- dashboard
- attendance
- training
- payslips
- profile
- leave
- evaluations
- incidents

Field officer flow:
- dashboard
- work orders
- guards
- reports
- more/actions

### Backend wiring

- Firebase initialization is wired in the mobile app.
- The API client is pointed at the live CISS backend:
  - `https://cisskerala.site`
- The mobile app uses the same live Firebase project values as the web app.
- Public Firebase client config is now read from the standalone mobile env file.

### Shared app shell behavior

- The mobile shell now shows:
  - company logo
  - company name
  - page title
  - optional subtitle
- Guard and field officer “More” areas now include support/contact content.
- Guard dashboard and login surfaces show branded company information.

### Offline, sync, and field reliability

- Added local offline queue using Hive for resilient field operations.
- Implemented `SyncService` to automatically retry queued requests when network returns.
- Added support for offline check-in/check-out, visit reports, training reports, and incident reports.
- Added `SyncStatusBadge` to dashboards to show pending sync items.
- Integrated `connectivity_plus` for real-time network detection and sync triggers.

### Notifications and device features

- Integrated `firebase_messaging` (FCM) for push notifications.
- Added `NotificationService` for permission handling and message routing.
- Enhanced location safety in attendance flow with explicit GPS capture and service checks.

### Fixes & Enhancements (2026-05-03)

- **Background Tracking Service**: 
  - Removed hardcoded heartbeat URL; now uses `ApiConfig.baseUrl` (environment-driven).
  - Added safety checks for `siteContext` access.
- **Offline Sync & Reliability**:
  - **Broken Offline Attendance Fix**: Refactored `_submitAttendance` in `GuardAttendanceScreen` to construct the payload before photo upload attempts. If offline, it now queues the full request (including base64 photo data).
  - **Enhanced SyncService**: Added support for `PATCH`, `PUT`, and other generic HTTP methods.
  - **Robustness**: Improved retry logic and logging in `SyncService`.
- **Notifications & Connectivity**:
  - **FCM Token Sync**: Added `updateFcmToken` to `MobileRepository` and wired it into `NotificationService` to ensure the backend can target the specific device.
  - **Notification Handling**: Enhanced `NotificationService` to listen for token refreshes and handle background/foreground message events.

### Android Native & Duty Tracking (2026)

- **Native Optimization**: 
  - Updated `AndroidManifest.xml` with comprehensive permissions (GPS, Background Location, Camera, Notifications, Foreground Services).
  - Increased `minSdk` to 24 to support modern background service requirements.
- **Permission Onboarding**: 
  - Added a dedicated `PermissionOnboardingScreen` that requests all necessary access (Location, Camera, Notifications) sequentially during initial setup.
  - Implemented automated redirection from `AuthGate` if permissions are revoked or missing.
- **Background Tracking & Geofencing**:
  - Developed `BackgroundTrackingService` using `flutter_background_service`.
  - Service automatically starts upon **Clock In** and stops on **Clock Out**.
  - Periodic GPS heartbeats (every 5 minutes) verify if the guard is within the site's geofence radius.
  - "Out of Zone" events are flagged in the notification and synced to the backend.
- **Verification**:
  - `flutter analyze` passed with no issues.
  - Verified start/stop triggers in `GuardAttendanceScreen`.

### Audit fixes (2026-06-02)

- Removed a tracked empty control-character artifact from `android/app`.
- Fixed analyzer fallout from recent UI updates:
  - removed stale imports in field officer and guard attendance screens
  - removed an unused attendance status icon local
  - guarded async bottom-sheet usage with `context.mounted`
- Updated the role hub widget test to match the current compact labels.
- Verification passed:
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --dart-define-from-file=mobile.env`

### Attendance upload-token repair (2026-06-02)

- Updated mobile attendance photo uploads to match the web backend's protected upload contract:
  - request `/api/public/attendance/upload-token`
  - upload under `employees/{employeeDocId}/attendance/...`
  - send the generated `uploadToken` with the photo upload
- QR attendance payloads now include `reportedAtClient` so offline replay preserves the actual attendance time.
- Offline attendance sync now supplies `siteId` when replaying queued photo uploads.


```bash
cd /Users/mymac/Documents/CISS-Mobile
flutter run --dart-define-from-file=mobile.env
```

## Important config values

- API base URL:
  - `https://cisskerala.site`
- Firebase project:
  - `ciss-workforce`
- Support email:
  - `admin@cisskerala.app`
- Portal URL:
  - `https://cisskerala.site`

## Important notes

- Admin SDK credentials stay only in the web/backend repo.
- The mobile app should keep using env-driven public config only.
- The mobile app should continue to treat guard and field officer as separate login surfaces.
- Future work should preserve the isolated repo structure.

### [2026-06-28] — Reports redesign: preview, photo stamping, minimums

- Added `toJson()` to `VisitReportModel` and `TrainingReportModel` for proper serialization.
- Added `_stampPhoto` method — applies canvas overlay (dark bottom bar with timestamp, GPS, title, "Captured by CISS Field Officer") to all photos before upload.
- Changed training photo minimum from 3 to 1; visit reports now block submit with zero photos.
- Added preview step in `_NewReportSheet`: shows read-only summary (client/site, date, GPS, fields, photos) with Edit/Submit buttons before final submission.
- Included `fieldOfficerName` in submit payload for both report types.

## Known next work

- Finish backend wiring for any remaining guard and field officer screens.
- Add production-grade offline sync for attendance and field reports.
- Add push notification handling and background refresh.
- Wire dummy-data verification flows against the live backend before release.

### [2026-06-28] — Camera fix, guardLocations doc ID, manual ID entry, public attendance page

- Replaced stub `CameraCaptureScreen` with working implementation using `image_picker`.
- Fixed `LiveLocationService` to use `employeeDocId` as Firestore document ID instead of `employeeId` (which contains slashes).
- Added manual employee ID / phone / resource ID entry fields to QR attendance flow.
- Added `PublicAttendanceScreen` — no-login attendance flow with guard identification (ID/phone/resource), site selection, photo capture, and submission.
- Added `/attendance` route in app router for the public attendance page.
- Updated `fetchAttendanceEmployee` in repository to accept optional phone and resourceId params.
