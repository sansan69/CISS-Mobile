# Memory

## Project

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

## Known next work

- Finish backend wiring for any remaining guard and field officer screens.
- Add production-grade offline sync for attendance and field reports.
- Add push notification handling and background refresh.
- Wire dummy-data verification flows against the live backend before release.
