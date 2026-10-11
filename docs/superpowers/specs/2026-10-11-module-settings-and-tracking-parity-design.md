# Module Settings Gating + Attendance/Tracking Parity — Design

Date: 2026-10-11
Status: Approved (design), pending spec review
Source app under study: CISS-AMS `com.users.ciss_flutter` v5.0.4 (reverse-engineered, see Appendix)
Target app: CISS-Mobile (`ciss_mobile`, backend `https://cisskerala.site`)

## Goal

Two tracks, approved by the product owner:

1. **Server-driven module gating** — a new `/api/mobile/settings` endpoint returns app config + per-module booleans for the authenticated role/region; the client hard-hides disabled features and redirects direct route access. Backend is ours (cisskerala.site).
2. **Attendance/tracking parity with CISS-AMS** — enrich the tracking payload with AMS-named fields, add break + early-checkout reason, and add server-authoritative geo + IP validation.

Chosen approach: **Central `AppSettings` Riverpod provider + GoRouter redirect guard** (hard-hide + redirect), with an encrypted Hive cache and a fail-open refresh policy.

## Non-goals

- Dynamic QR attendance (deferred).
- Porting AMS HRMS modules (Loan, Expense, Document-Request, Forms, Payment Collection, Order/Product, ATM, Chat/AI-Chat). Flags for them are declared so gating is ready, but no screens are added in this cut.
- Migrating the backend host or the auth model (we stay on Firebase bearer tokens + `cisskerala.site`).

## §1 — Settings contract & client model

**Endpoint:** `GET /api/mobile/settings` (Bearer, region-resolved base URL). Server returns flags for the authenticated role (guard vs field officer).

```json
{ "data": {
  "version": 7,
  "app": { "minSupportedVersion": "1.0.21", "forceUpdate": false, "maintenance": false,
           "supportEmail": "...", "supportPhone": "...", "currencySymbol": "₹", "distanceUnit": "km" },
  "modules": { "attendance": true, "break": true, "geoFence": true, "ipAttendance": false,
               "qrAttendance": true, "dynamicQr": false, "offlineTracking": true,
               "biometricVerification": true, "uidLogin": false, "leave": true, "loan": false,
               "expense": false, "documentRequest": false, "dynamicForm": false, "task": false,
               "product": false, "paymentCollection": false, "notice": false, "clientVisit": false,
               "chat": false, "aiChat": false, "training": true, "payslips": true, "patrol": true,
               "incidents": true, "evaluations": true, "workOrders": true, "reports": true }
} }
```

**Client model** (`lib/core/settings/`):

> Naming note: `AppSettingsController`/`appSettingsControllerProvider`/Hive box `app_settings` already exist for **theme mode** (`lib/app/theme/theme_mode_controller.dart`). To avoid collision the server-driven config is named **`RemoteConfig`** with provider **`remoteConfigProvider`** and Hive box **`remote_config`**.

- `RemoteConfig { AppConfig app; ModuleFlags modules; int version; DateTime fetchedAt; }`
- `ModuleFlags` = typed bool fields over a `Map<String,bool>` fallback.
  - `bool isOn(String key, {required bool fallback})`.
  - Unknown/missing key → fallback.
  - `ModuleFlags.defaults` = today's shipped modules ON, new AMS modules OFF.
- Flag keys are simple stable camelCase identifiers `version` lets the client skip re-render when unchanged.

**Defaults (used when no cache and no server response):**

| ON (shipped today) | OFF (new/AMS-only) |
|---|---|
| attendance, qrAttendance, offlineTracking, biometricVerification, leave, documents, payslips, patrol, incidents, evaluations, training, workOrders, reports, break, geoFence | loan, expense, documentRequest, dynamicForm, task, product, paymentCollection, notice, clientVisit, chat, aiChat, dynamicQr, ipAttendance, uidLogin |

## §2 — Refresh & offline policy

**Storage.** Hive box `remote_config`, encrypted with the same key derivation `OfflineQueue` uses (`hive_encryption_key` in secure storage). Keyed by `"$regionCode:$role"` so a region/role switch uses its own cache.

**Fetch triggers.**
1. After successful login / session restore.
2. On app resume when `now - fetchedAt > TTL` (15 min).
3. After a region switch.
4. Manual pull-to-refresh in More/Settings.
5. On any `403 module_disabled` response (force refresh to reconcile).

**Startup.** Load cache synchronously → boot with last-known flags (no flash of wrongly hidden/shown items) → refresh async.

**First run / new role or region (no cache).** Use `ModuleFlags.defaults` and refresh; never block UI.

**Failure policy.** On fetch error keep cached values; if none, keep defaults. Never fail-closed — the app must always be usable. Only `app.forceUpdate` / `app.maintenance` produce a blocking gate, reusing `lib/core/update/app_update_gate.dart`.

**Concurrency.** One in-flight fetch de-duped; cache write atomic (single `box.put` per key).

## §3 — Gating wiring (router + nav)

**Path→module map.** `lib/core/settings/route_modules.dart` maps every routable path to a module key (or `null` = always allowed):

| Path | Module |
|---|---|
| `/`, `/login`, `/login/guard`, `/login/guard/setup`, `/login/field-officer`, `/permissions`, `/region-select`, `/module-unavailable`, `/update` | always allowed (`null`) |
| `/qr-attendance` | `qrAttendance` |
| `/attendance` | `attendance` |
| (future) `/guard/leave` | `leave` |
| (future) `/guard/patrol` | `patrol` |
| FO live map / day timeline | always allowed (core tracking) |

**Router becomes a provider.** Promote the global `appRouter` to `routerProvider` built with `ref` (and update `lib/app/app.dart` to watch it); attach `refreshListenable` to `remoteConfigProvider`. A top-level `redirect` resolves target path → module; if OFF, redirects to `/module-unavailable?m=<key>`.

**Nav/UI.** `moduleEnabled('leave')` selector drives guard dashboard tiles, Quick Actions, More menu, FO tools, section lists. A `ModuleGate(module: 'leave', child: …)` widget wraps gated screen bodies as defense in depth.

**Unavailable screen.** `/module-unavailable` — neutral copy ("This feature isn't enabled for your account"), with Back.

**Debug override.** `kDebugMode`-only override set (reachable from a hidden spot in More) to force flags without a server change.

## §4 — Tracking payload enrichment (AMS field names)

**Live heartbeat** (`/api/guard/tracking/heartbeat`) sends AMS-named fields:

```json
{ "siteId": "…", "status": "in|out",
  "latitude": 12.9, "longitude": 80.2, "accuracy": 8.0, "locationAccuracy": 8.0,
  "altitude": 12, "bearing": 90, "speed": 1.4,
  "activity": "still|walking|traveling|on_bicycle|in_vehicle|unknown",
  "isMock": false, "isGPSOn": true,
  "batteryPercentage": 78, "wifiConnected": true, "networkType": "wifi|mobile|none",
  "time": 1730000000000, "capturedAt": "2026-10-11T…Z" }
```

- `batteryLevel` → **`batteryPercentage`** (server reads either for one release, then AMS name only).
- `isMock` from `Position.isMocked`; `isGPSOn` from `Geolocator.isLocationServiceEnabled()`.
- `activity` via new dep **`flutter_activity_recognition`** (pravera, same as AMS) mapped to AMS strings; add `ACTIVITY_RECOGNITION` permission to the manifest. Best-effort — `unknown` if unavailable.

**Offline path.** New `TrackingBuffer` (Hive, capped ~5k samples / 24h with eviction) stores samples in the same shape with `isSynced=false`; `SyncService` flushes via new **`POST /api/mobile/tracking/batch`** `{ "samples": [ … ] }` when online. Live path keeps the single-sample heartbeat. Mirrors AMS `syncTrackingFromMobile`.

**Files.** `lib/core/location/tracking_sample.dart` (model + AMS mapping), extend `background_tracking_service.dart`, new `lib/core/location/tracking_buffer.dart`, register the batch path in `sync_service.dart`.

## §5 — Break + early-checkout reason

**Break.** `POST /api/mobile/attendance/break` `{ "action": "start|stop", "lat":…, "lng":…, "accuracy":…, "capturedAt":… }` → `{ "onBreak": true, "breakStartedAt": "…", "breakSeconds": 900, "canCheckOut": false }`.

- Client state in a new `lib/core/attendance/attendance_session.dart` (Riverpod notifier): `onBreak`, `breakStartedAt`, `totalBreakSeconds`, server `canCheckOut`.
- UI on the attendance screen: Start break / End break action, live elapsed timer while on break, checkout disabled while `canCheckOut == false` (with explanatory line).
- Gated by the `break` module flag; hidden entirely when OFF.

**Early-checkout reason.** Server flags an early checkout (`canCheckOut:false, requiresReason:true`) when checkout is before scheduled shift end. Client shows a reason sheet with a client-side preset list ("Personal emergency", "Shift relief arrived", "Supervisor instruction", "Other") plus free text when "Other" is chosen, and re-submits checkout including **`earlyCheckOutReason`**. The preset list is a client constant in this cut (the server may later return it in `app` settings). Implemented as a field on the checkout payload; optional standalone endpoint mirroring AMS `setEarlyCheckoutReason` if the server later needs it.

**Offline.** Break and checkout are ordinary `OfflineRequest`s → route through the existing `OfflineQueue`/`SyncService`.

**Files.** `lib/core/attendance/attendance_session.dart` (new), `guard_attendance_screen.dart` + `field_officer_attendance_screen.dart` (break action, timer, reason sheet), API additions in the mobile repository.

## §6 — Geo + IP validation (server authoritative)

**Endpoint.** `POST /api/mobile/attendance/validate` `{ "siteId":"…", "lat":…, "lng":…, "accuracy":…, "publicIp":"<optional>", "capturedAt":… }` →

```json
{ "allowed": true,
  "checks": { "geoFence": { "ok": true, "distanceM": 45, "radiusM": 100 },
              "ip": { "ok": true, "clientIp": "1.2.3.4", "matched": "…" } },
  "reason": null }
```

**Authority.** The server derives the client IP from the request itself (trusted `X-Forwarded-For`/remote addr) and owns the geofence math (site lat/lng + radius). An optional client-supplied `publicIp` is a hint only. The **attendance submit endpoint re-enforces** the same checks, so skipping the pre-check cannot bypass them.

**Client flow.** Before check-in/out call `validate` for instant UX: `allowed:false` → block submit and show `reason` ("Outside site geofence (45 m of 100 m)" / "Not on the site network"); warn if `accuracy` is worse than a threshold (e.g. >100 m). Enforcement keys off `geoFence` and `ipAttendance` module flags (server-side); when both are off the call is skipped.

**IP lookup helper.** Optional `lib/core/location/public_ip.dart` (single `GET` to a configurable endpoint, e.g. `api.ipify.org`) supplying the hint; failure is non-fatal.

**Files.** `lib/core/location/public_ip.dart` (new), attendance API in the mobile repository, wired into both attendance screens.

## §7 — Testing + rollout

**Tests.**
- Unit: `ModuleFlags` parse + unknown-key fallback; `routeModule` map & redirect decision (on/off/unmapped→allow); `tracking_sample` AMS mapping (activity strings, `isMock`, `isGPSOn`, `batteryPercentage`); `TrackingBuffer` cap/eviction; `attendance_session` break state machine.
- Widget: `ModuleGate` on/off; dashboard hides a disabled tile; attendance break timer + disabled checkout; `validate` blocks submit when `allowed:false`.
- Integration: offline flush includes a tracking batch; settings cache round-trip.
- Gates: `flutter analyze` + `flutter test` (existing `test/` suite stays green).

**Rollout / migration.**
- **Backend** adds `/api/mobile/settings`, `/api/mobile/attendance/break`, `/api/mobile/attendance/validate`, `/api/mobile/tracking/batch`; heartbeat accepts `batteryPercentage` (and legacy `batteryLevel` for one release).
- **Client** ships with compiled defaults = today's shipped modules ON; server flags override. Unknown/missing flags → fallback, so old app ↔ new server stays safe. Server tolerates legacy heartbeat keys.
- **Zero behavior change until enabled:** the new paths (break, geoFence, ipAttendance) are themselves behind module flags, so nothing new activates until the server turns them on.
- Version bump; all routes resolve through `routeModule` with default-allow for unmapped paths.

**Main risk.** Promoting the global `appRouter` to `routerProvider` touches app startup. Mitigated by keeping redirect pure + unit-tested and confirming `EdgeGestureWrapper` and existing transitions still apply.

## Appendix — CISS-AMS reverse-engineering summary

- **Identity:** CISS-AMS, `com.users.ciss_flutter`, CISS Services Ltd; v5.0.4 (vc 6), minSdk 24, targetSdk 36; Flutter app, Dart package `fieldmanager_hrms_flutter`.
- **Backend:** `https://cissams.co.in:8080/api/V1/…` (73 endpoints): auth (login, loginWithUid, checkDevice/registerDevice, verifyOTP, forgotPassword/resetPassword/changePassword, messagingToken, getAppSettings), attendance (checkInOut, checkStatus, startStopBreak, setEarlyCheckoutReason, statusUpdate, validateGeoLocation, validateIpAddress, qrAttendance/verifyCode, dynamicQr/verifyCode), tracking (offlineTracking/syncTrackingFromMobile), and modules (client, order/product, visit, task, leave, loan, expense, documentRequest, forms, paymentCollection, notice, chat, ATM, reportIncident, settings/getModuleSettings).
- **State/plugins:** MobX + flutter_mobx, google_maps_flutter, mobile_scanner (ML Kit Barcode `libbarhopper_v3`), background_location_tracker, geolocator, flutter_activity_recognition, disable_battery_optimization, sqflite (`app.db`), firebase_core/firebase_messaging, flutter_local_notifications, cached_network_image, infinite_scroll_pagination, lottie, pdfium.
- **Offline DB:** `app.db` tables `trackings`, `visit`, `client`, `clientSync`, `domain`, `cacheObject`. `trackings` columns: `status, accuracy, activity, latitude, longitude, altitude, bearing, locationAccuracy, speed, time, isMock, batteryPercentage, isGPSOn, …`.
- **Observations:** server-driven `is*ModuleEnabled` flags via `getModuleSettings`; IP-based attendance via public-IP lookup (`ipv4.seeip.org`); Firebase project `ciss-mis`; Maps key in manifest. No Crashlytics/Sentry.
