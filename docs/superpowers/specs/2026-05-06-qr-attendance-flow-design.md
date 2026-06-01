# QR Attendance Flow — Design Spec

**Date:** 2026-05-06
**Status:** Approved

## Overview

Add a zero-login attendance flow triggered by scanning a guard's pre-assigned QR code. The flow is intentionally short — 3 steps from scan to done — so guards spend minimal time before duty.

**Trigger:** Long-press the "Guard Operations" card on the Login Hub screen.

## QR Code Format

The QR code format already exists in the CISS web app (`src/lib/qr/employee-qr.ts`). The mobile app mirrors the same parser:

```
Employee ID: CISS/EMP001
Phone: 9876543210
```

QR codes are generated per-employee and stored at `employee.qrCodeUrl`. No new backend work required.

## Flow Architecture

```
LoginHubScreen (long-press guard card)
    │
    ▼
QrScannerScreen          ← new route: /qr-attendance
    │  parse QR → employeeId
    ▼
    │  GET /api/public/attendance/employee?employeeId=...
    │  GET /api/public/attendance  (sites)
    │  auto-pick nearest site by GPS
    ▼
AttendanceActionScreen   ← inline, same route
    │  guard name, site, shift, photo capture
    │  POST /api/attendance/submit
    ▼
ConfirmationScreen       ← inline, same route
    │  "✓ Attendance Marked"
    │  guard name, site, time, status
    │  [Share via WhatsApp] [Share] [Done]
    ▼
LoginHubScreen (pop back)
```

All 3 screens live on a single go_router route (`/qr-attendance`) using a `_QrFlowStep` enum — no deep navigation stack, no back-canceling mid-flow.

## Technical Design

### New files

| File | Purpose |
|---|---|
| `lib/core/qr/qr_parser.dart` | Parse QR text to extract employeeId/phone. Mirrors web's `parseEmployeeQrText()`. |
| `lib/features/attendance_qr/qr_scanner_screen.dart` | Full-screen camera with scan overlay. Detects QR, parses, fetches employee + sites, picks nearest site. |
| `lib/features/attendance_qr/attendance_action_screen.dart` | Shows guard info, selected site/duty-point/shift. Photo capture + MARK IN/OUT button. |
| `lib/features/attendance_qr/attendance_confirmation_screen.dart` | Success card with guard/site/time details. WhatsApp share button + system share sheet. |

### Modified files

| File | Change |
|---|---|
| `lib/features/auth/presentation/login_hub_screen.dart` | Add `onLongPress` to Guard card → `context.go('/qr-attendance')`. |
| `lib/app/router/app_router.dart` | Add `GoRoute(path: '/qr-attendance', builder: ...)` for `QrScannerScreen`. |
| `pubspec.yaml` | Add `mobile_scanner: ^6.0.0` and `share_plus: ^10.0.0`. |

### Reused code

- `parseEmployeeQrText()` logic from web's `employee-qr.ts`, ported to Dart
- `MobileRepository.fetchAttendanceEmployee()` — existing public endpoint wrapper
- `MobileRepository.fetchAttendanceSites()` — existing public endpoint wrapper
- `MobileRepository.submitAttendance()` — existing submit endpoint
- `MobileRepository.uploadAttendancePhoto()` — existing photo upload
- `CameraCaptureScreen` widget — existing reusable camera widget
- `geolocator` — already in pubspec, used for nearest-site selection
- `SiteOptionModel`, `PublicAttendanceEmployeeModel`, `AttendanceHintModel` — existing models

### Packages to add

```yaml
mobile_scanner: ^6.0.0    # QR/barcode scanning
share_plus: ^10.0.0        # System share sheet + WhatsApp
```

## Error Handling

| Scenario | Handling |
|---|---|
| Camera permission denied | Show "Camera access needed" with [Open Settings] button |
| QR doesn't parse | Toast "Could not read QR code. Please try again." — stay on scanner |
| Employee not found (API 404) | "No guard found for this QR code." + [Scan Again] |
| Network error during fetch | "Network error. Check connection and try again." + [Retry] |
| GPS unavailable | Show site picker manually (fallback to list, sorted alphabetically) |
| No sites in district | Show all sites as fallback |
| Attendance submit fails | "Could not record attendance. Please try again." + [Retry] |
| Photo upload fails | Continue without photo (non-blocking), log error |

## Security Considerations

- No Firebase auth required — uses existing public endpoints
- QR codes contain only employeeId + phone (no secrets)
- Attendance submit goes through the same public endpoint as web
- Flow auto-dismisses on success, no lingering auth state
- Photo is optional, non-blocking — guards who can't take photos still mark attendance

## States & Edge Cases

- **Already marked IN today**: Show "You're already clocked in" with OUT as the suggested action
- **Already marked OUT today**: Show "All attendance recorded for today"
- **Loading**: Full-screen skeleton while API fetches
- **Camera in use**: Handle gracefully if another app holds the camera
- **App backgrounding**: If app goes to background mid-flow, resume at current step
- **No internet**: Queue attendance locally via existing OfflineQueue (SyncService picks it up)

## Confirmation Share Card Format

```
CISS Workforce — Attendance Confirmed
────────────────────────────────────
Guard:         [fullName]
Employee ID:   [employeeId]
Site:          [siteName]
Date/Time:     06 May 2026, 08:15 AM
Status:        CLOCKED IN
────────────────────────────────────
Verified by CISS Workforce Platform
```

This text is shared via the system share sheet (WhatsApp, SMS, Telegram, etc.) and also via WhatsApp deep-link for one-tap sharing.
