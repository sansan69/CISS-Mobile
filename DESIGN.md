# Design System: CISS Workforce Mobile (Flutter)

Semantic design language for the CISS Workforce Android/iOS app (`CISS-Mobile`, Flutter). This file is the single source of truth for mobile screen generation and future UI work — Google Stitch format. Mirrors the web platform design language (`DESIGN.md` at the repo root of the web app) so both products read as one brand. Source of record: `lib/app/theme/app_tokens.dart`, `lib/app/theme/app_theme.dart`, `lib/shared/widgets/*`.

## 1. Visual Theme & Atmosphere

A calm, operational tool for guard and field-officer work in the field: bright surfaces, generous whitespace, one confident navy accent, gold used only for emphasis. Density is "Daily App Balanced" (4/10) — data-dense lists breathe. Variance is low (2/10) — predictability reduces cognitive load under duty pressure. Motion is restrained (3/10): every transition slides and fades (280 ms, ease-out-cubic) and live status indicators pulse — nothing else loops.

## 2. Color Palette & Roles

Light (default):

- **Canvas Blue-Gray** (`#F0F4F8`) — app background
- **Pure Surface** (`#FFFFFF`) — cards, sheets, dialogs
- **Surface Muted** (`#F5F8FA`) — chip backgrounds, input fills
- **Ink Navy** (`#0F1F31`) — primary text
- **Muted Steel** (`#536A80`) — secondary text, metadata
- **Whisper Border** (`#D3DFE9`) — 1px structural lines
- **Brand Navy** (`#014C85`) — single accent: primary buttons, active nav, links, focus rings
- **Navy Deep** (`#013A6B`) — pressed/hover states of Brand Navy, emphasis text on soft fields
- **Brand Gold** (`#BD9C55`) — sparse emphasis only (metric highlights, awards); never a CTA fill
- **Success Green** (`#1B825E`), **Warning Amber** (`#B86618`), **Danger Red** (`#B52B44`) — status semantics; each has a matching `*Soft` tint (`#E3F5EE` / `#FAF0E3` / `#FCE8EB`) for chip/dot backgrounds

Dark mode: same hue families shifted for dark canvas (`#070B11` base); Brand Navy becomes `#5C9DD6`, gold becomes `#D8B96C`.

**Rules:** one accent (Brand Navy). Never pure black. Never neon/glow. Never purple. Status colors only for status — text and icons default to Ink/Muted Steel.

## 3. Typography

- **UI/Body:** Inter (bundled in `assets/fonts/`, offline-safe — deliberate exception to the generic-font ban: this is a field tool where legibility and load time beat typographic character; hierarchy carries the design)
- **Display:** Inter at `w800` for screen titles (20–22 px), card titles `w700` 16 px — hierarchy through weight and color, not size
- **Body:** 14–16 px, `inkMuted` for secondary
- **Data/metadata:** 11–13 px, `w700` for values, monospace only for employee IDs and timestamps where present
- **Banned:** generic serif fonts; decorative fonts; ALL CAPS beyond short labels (≤3 words) and buttons

## 4. Component Stylings

- **Buttons:** Filled (Brand Navy) for the single primary action per screen; Outlined/tonal for secondary; minimum height 48 px (44 px touch-target floor); pressed state = darker navy + slight scale; no glow, no elevation games
- **Cards (`ModernCard`):** 16 px radius, 1px Whisper Border, no drop shadow (flat = calmer); used only where grouping serves hierarchy; high-density lists use border-top dividers instead of cards
- **Inputs:** label above, helper below, error below in Danger Red; filled field with Surface Muted background; focus ring in Brand Navy
- **Chips (`StatusChip`):** pill, 12–14 px, `*Soft` tint background + colored border + colored `w700` label — the primary "status at a glance" device
- **Loaders:** page-level skeletons matching layout dimensions (`lib/core/cache/skeleton_widgets.dart`); never bare circular spinners for full-page loads
- **Empty states (`StateBlock`):** composed — icon + title + one-line explanation + optional action; never bare "No data"
- **Maps:** `flutter_map` + OpenStreetMap tiles; brand-navy route polylines; status-colored markers (green in-zone, red out-of-zone, navy stay-points); battery strip under live markers

## 5. Layout Principles

- Single-column mobile-first; never horizontal scroll on content (filter chips may scroll horizontally)
- Screen shells: branded `ScreenScaffold` AppBar (logo + title) or plain AppBar for full-bleed maps
- Standard spacing scale: 4/8/12/16/20/24/32 (`AppSpacing`)
- Bottom sheets for contextual actions (guard summary on live map); sheets rounded 24 px top, grab-handle
- List rows: 44 px minimum interactive height; name `w700`, metadata line muted 12–13 px, status chip right-aligned

## 6. Motion & Interaction

- Route transitions: slide-from-right 280 ms + fade 40% (ease-out-cubic), reverse 200 ms — uniform via `go_router` page builder and `MaterialPageRoute`
- Perpetual micro-interactions, only where they mean something: pulsing live dot (top bar/status bars, success green), `LIVE` label with pulsing dot on the live map, out-of-zone markers in danger red
- No bouncing chevrons, no scroll hints, no decorative looping
- Haptics: light on selection, medium on destructive confirm (`lib/core/haptics.dart`)
- Animate only opacity/transform; never layout-affecting properties

## 7. Anti-Patterns (Banned)

- Emojis and emoji-like glyphs (✗ ✓ ⚠ ❌ ✅) — use Material icons
- Pure black (`#000000`); neon/glow shadows; purple or gradient accents
- More than one primary CTA per screen
- Bare circular spinners as full-page loaders
- Bare "No data" text without a composed empty state
- ALL CAPS text beyond short labels/buttons; decorative fonts; generic serifs
- Overlapping elements; cards stacked without purpose
- Equally-weighted 3-column tile rows (use status chips + rows instead)
- Centered hero-style layouts in operational screens
- Horizontal page scroll; touch targets under 44 px

## Feature surfaces (current)

- **Guard:** dashboard, attendance (QR/GPS/geofence, offline queue), training + quizzes, payslips, leave, evaluations, incidents, patrol, profile, Aadhaar correction, document upload, PIN setup/forgot
- **Field Officer:** dashboard (duty coverage, quick actions, Live Map entry), work orders, guards directory, **Live Map** (realtime positions + device telemetry), guard detail (live map, telemetry strip, **day timeline**), day timeline (polyline route, stay markers, activity classification, battery/WiFi per point), visit/training reports (photo-stamped, offline), training assignments
- **Public:** QR attendance (no-login), public attendance, enrollment
- **Tracking pipeline:** background service with **adaptive heartbeat cadence** (2 min out-of-zone / 5 min moving / 10 min stable in-zone / 15 min stable + low battery) → `POST /api/guard/tracking/heartbeat` (server stores `guardLocations` + 5-min `locationHistory` buckets with battery/speed/WiFi, 30-day retention) → FO streams `guardLocations` via Firestore rules (district-scoped). Battery is the constraint: fewer GPS locks, zone alerts stay responsive.
- **Device compatibility:** battery-optimization exemption (via generic settings screen — the direct dialog needs a Play-restricted permission, deliberately avoided) and OEM auto-start deep links for Xiaomi/Redmi/Poco, Oppo/Realme, Vivo/iQOO, Huawei/Honor, OnePlus, wired into the permission-onboarding flow. minSdk 24 (Android 7.0; local_auth and mobile_scanner hard-require it).
- **Fingerprint unlock (guards + field officers):** enrollment surface in Security (guard profile + FO More) and the login screen. Fingerprint-only — devices are gated via `getAvailableBiometrics` (`fingerprint`/`strong` Class 3; optical + ultrasonic sensors); face/iris/weak-class devices are rejected and no-sensor devices show a disabled state. No-enrollment devices deep-link to the OS fingerprint screen. Enable = server-verified PIN/password + fingerprint gesture, then credential stored in secure storage; disable = fingerprint-confirmed. App-lock gate (after login) uses fingerprint-only auth with typed OS error handling (LockedOut/PermanentlyLockedOut → PIN/password fallback). Fingerprint data never leaves the device.

## Known scope notes

- Admin/accounts/client/HR surfaces remain web-only by design; the mobile app focuses on guard + field-officer operations.
- Web parity backlog (not yet in mobile): leaderboard, notification targeting depth, admin attendance review, site/wage configuration — tracked in work-log.
