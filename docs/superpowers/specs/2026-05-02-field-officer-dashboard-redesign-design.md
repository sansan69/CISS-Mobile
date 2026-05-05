# Field Officer Dashboard Redesign

**Date:** 2026-05-02  
**Scope:** `lib/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart`  
**Style direction:** Elegant cards with gradients, brand-focused header

## Goal

Refactor the field officer dashboard to deliver a modern, polished experience using the existing design system (`BrandBanner`, `MetricTile`, `CissThemeTokens`). Focus on visual richness: gradient accents, better spacing, prominent brand identity in the header, and elevated card treatments.

## Design

### 1. Header — BrandBanner replaces AppBar

Replace the current `ScreenScaffold`-based AppBar with the existing `BrandBanner` widget. The `BrandBanner` already provides:

- Dark navy gradient background (matching auth/onboarding screens)
- Company logo in a frosted circle
- Company name (`kCompanyName`) in accent gold, uppercased
- Tagline (`kCompanyTagline`) in muted white
- Hairline gradient divider
- Page title and subtitle below the divider

The dashboard will pass:

- `title`: "Dashboard"
- `subtitle`: officer name and assigned districts (e.g., "Rajesh Kumar · Kollam, Alappuzha")
- `trailing`: refresh IconButton and SyncStatusBadge stacked or side-by-side

The body switches from `ScreenScaffold` to a plain `Scaffold` with no AppBar, using `ListView.separated` directly for content padding and spacing.

### 2. Stat cards — MetricTile grid

Replace the current inline 3-stat compact row with proper `MetricTile` widgets in a 2-column layout:

Row 1:
- "Total Guards" — primary color, `Icons.groups_2_outlined`
- "Active Guards" — success color, `Icons.verified_outlined`

Row 2:
- "Checked In Today" — accent color, `Icons.login_rounded`, spans full width

Each `MetricTile` receives its `accentColor` matching the stat's semantic color. Helper text provides context (e.g., "Deployed across districts", "Currently on duty").

### 3. Quick actions — gradient-accented cards

Replace the flat icon row with a 2x2 grid of compact action cards:

- "Work Orders" — primary tint, `Icons.assignment_turned_in_rounded`
- "Guards" — success tint, `Icons.groups_2_rounded`
- "Visit Report" — warning tint, `Icons.fact_check_rounded`
- "Training" — accent tint, `Icons.school_rounded`

Each card:
- Surface background with a colored left border accent (4px wide, rounded)
- Icon container with the semantic color at low opacity
- Label text below the icon
- `InkWell` tap → updates `fieldOfficerTabIndexProvider`

### 4. Attendance card — gradient accent bar

Keep the existing attendance overview structure with these visual upgrades:

- Gradient accent bar at the card top (primary → primaryStrong, 4px height, pill-shaped)
- Section header with icon container + title + StatusChip remains
- District/site progress lines unchanged internally but with slightly larger touch targets (padding)
- Divider between district summary and active sites kept

## Component reuse

| Component | Source | Used for |
|-----------|--------|----------|
| `BrandBanner` | `lib/shared/widgets/brand_banner.dart` | Dashboard header |
| `MetricTile` | `lib/shared/widgets/metric_tile.dart` | Stat cards |
| `StatusChip` | `lib/shared/widgets/status_chip.dart` | Attendance status |
| `SyncStatusBadge` | `lib/shared/widgets/sync_status_badge.dart` | Header trailing |
| `CissThemeTokens` | `lib/app/theme/app_tokens.dart` | Colors, spacing, radii |

## What changes

- `ScreenScaffold` → `Scaffold` (AppBar becomes body content via BrandBanner)
- Inline stat row → `MetricTile` grid
- Quick actions icon row → gradient card grid
- Attendance card gets a gradient accent bar
- Unused `report_models.dart` import already removed earlier

## What stays

- Data fetching (`fieldOfficerDashboardProvider`), loading/error states, refresh logic
- Attendance card internal structure (progress lines, district/site lists)
- All notebook logic unchanged
