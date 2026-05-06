# Live Guard Location Tracking — Design Spec

**Date:** 2026-05-06
**Status:** Approved

## Overview

Real-time guard location tracking visible in Flutter FO app + Next.js web dashboards (admin + client). Uses Firestore as the shared real-time data layer.

## Data Model — Firestore

```
/guardLocations/{employeeId}
  employeeId:    string        // "CISS/EMP001"
  guardName:     string
  siteId:        string
  siteName:      string
  clientName:    string
  district:      string
  lat:           number
  lng:           number
  accuracy:      number
  isOutOfZone:   boolean
  status:        "In" | "Out"
  updatedAt:     timestamp
  attendanceId:  string?
  siteLat:       number        // for geofence circle on map
  siteLng:       number
  geofenceRadius: number
```

## Writes

| Trigger | Action | Writer |
|---|---|---|
| Guard marks IN (login flow) | `set()` document with status="In" | `GuardAttendanceScreen._submitAttendance` |
| Guard marks IN (QR flow) | `set()` document with status="In" | `QrAttendanceFlow._submitAttendance` |
| Every 5 min heartbeat | `update()` lat/lng/accuracy/isOutOfZone | `BackgroundTrackingService` |
| Guard marks OUT | `set()` status="Out", clear coords | `GuardAttendanceScreen._submitAttendance` |
| Guard marks OUT (QR) | `set()` status="Out", clear coords | `QrAttendanceFlow._submitAttendance` |

## Reads

| Consumer | Query | Usage |
|---|---|---|
| Flutter FO attendance tab | `where('status', '==', 'In')` → stream | Show live dot on each guard row |
| Flutter FO guard detail | `doc(employeeId)` → stream | Real-time marker on map |
| Next.js admin dashboard | Same stream | Live guard dots on admin map |
| Next.js client dashboard | `where('clientName', ...)` → stream | Client sees only their guards |

## Mobile Architecture

### New files

| File | Purpose |
|---|---|
| `lib/core/location/live_location_service.dart` | Firestore read/write for `guardLocations` collection |
| `lib/features/field_officer/presentation/screens/field_officer_guard_detail_screen.dart` | Detail: map + guard info + live location |

### Modified files

| File | Change |
|---|---|
| `lib/core/location/background_tracking_service.dart` | Add Firestore `update()` on each heartbeat |
| `lib/features/guard/presentation/screens/guard_attendance_screen.dart` | Call `LiveLocationService.setLocation()` on IN/OUT |
| `lib/features/attendance_qr/qr_attendance_flow.dart` | Call `LiveLocationService.setLocation()` on IN/OUT |
| `lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart` | Stream locations, show live dot, tap → detail |
| `pubspec.yaml` | +`cloud_firestore`, +`flutter_map`, +`latlong2` |

### Map

- **Package:** `flutter_map` + OpenStreetMap tiles (free, no API key)
- **Behavior:** Auto-follows guard marker with re-center toggle

## Guard Detail Screen

- Full-screen map with OSM tiles
- Guard marker (pulsing dot, color = in-zone green / out-of-zone red)
- Site geofence circle
- Accuracy ring around marker
- Info card below map: guard name, site, status, last update time, distance from site
- Streams from Firestore — marker moves in real-time
- Back button returns to attendance list

## Firestore Security Rules

```
match /guardLocations/{employeeId} {
  allow read: if request.auth != null;  // any authenticated user (FO, admin, client)
  allow write: if request.auth != null; // guard's device writes via Firebase Auth
}
```
