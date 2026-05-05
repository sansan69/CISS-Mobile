# Plan: Android Native Optimization & Guard Tracking

Implement background tracking and geofencing for guards during their duty hours using an open-source foreground service approach.

## 1. Dependencies & Permissions
- [ ] Add `flutter_background_service`, `permission_handler`, `device_info_plus`, and `battery_plus` to `pubspec.yaml`.
- [ ] Update `android/app/src/main/AndroidManifest.xml` with:
    - `INTERNET`
    - `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
    - `CAMERA`
    - `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
    - `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`
    - `POST_NOTIFICATIONS` (for API 33+)

## 2. Permission Onboarding
- [ ] Create `lib/features/auth/presentation/permission_onboarding_screen.dart`.
- [ ] This screen will explain *why* we need each permission and request them using `permission_handler`.
- [ ] Route the user to this screen after a successful login if permissions are not already granted.

## 3. Background Tracking Service
- [ ] Create `lib/core/location/background_tracking_service.dart`.
- [ ] Initialize `flutter_background_service`.
- [ ] Define a background task that:
    - Periodically fetches GPS location.
    - Compares current location to the site's geofence center/radius.
    - If outside the fence, logs an "Out of Zone" event or sends a notification.
    - Sends heartbeat location updates to `/api/guard/tracking`.

## 4. Guard Flow Integration
- [ ] Modify `lib/features/guard/presentation/screens/guard_attendance_screen.dart`:
    - When "Clock In" is successful, start the `BackgroundTrackingService`.
    - Pass the current site's lat/lng/radius to the service.
    - When "Clock Out" is successful, stop the `BackgroundTrackingService`.

## 5. Android Optimization
- [ ] Update `android/app/build.gradle.kts` to set `minSdk = 24` if needed.
- [ ] Ensure `MainActivity` and `AndroidManifest` are configured for the background service.
