# Spec: Field Officer "Command Center" Redesign

**Date:** 2026-05-04  
**Topic:** Complete UI/UX overhaul of Field Officer screens.  
**Approach:** Approach 1 (Command Center)

## 1. Vision
Transform the Field Officer experience into a high-density, tech-forward "Command Center" that aligns with the premium CISS branding (established on the landing page). The interface will prioritize real-time visibility, operational efficiency, and a modern aesthetic using glassmorphism and Rajdhani typography.

## 2. Design Language
- **Typography:** Use `GoogleFonts.rajdhani` for all headers, card titles, and prominent statistics.
- **Visual Style:** Glassmorphism (frosted, blurred semi-transparent cards) with subtle background glows.
- **Color Palette:** Deep navy gradients for headers, vibrant cyan/gold accents for active data.
- **Hierarchy:** Horizontal carousels for high-level summaries, followed by unified vertical feeds for details.

## 3. Screen-by-Screen Overhaul

### 3.1. Global Header (All FO Screens)
- Replace standard `AppBar` with the `BrandBanner` widget.
- **Title:** The screen's name (e.g., "Dashboard").
- **Subtitle:** Officer name and assigned districts (e.g., "Anil Kumar · Kollam, Alappuzha").
- **Trailing:** Side-by-side stack of `SyncStatusBadge` and a custom-styled `IconButton` for refresh.

### 3.2. Dashboard
- **Command Tiles (Hero Stats):** A horizontal scrollable row of glassmorphism tiles.
    - *Total Guards:* Large bold number + radar pulse icon.
    - *Deployment Ring:* Radial progress indicator for "Checked In" percentage.
- **Operations Summary:** High-density section using `MetricTile` for "Open Work Orders" and "New Incidents".
- **Collapsible Command Log:** Replaces the static "Notebook". A persistent but collapsible panel at the bottom for quick field notes.

### 3.3. Work Orders
- **Operation Tiles:** Interactive glassmorphism cards.
    - Circular progress ring showing assignment status (e.g., 5/10 guards).
    - Color-coded borders: Gold (Open), Green (Covered).
- **Frosted Assignment Sheet:** Full-screen blurred panel for guard selection.
    - Avatars with real-time status pips.
    - Prominent Rajdhani search bar.

### 3.4. Attendance & Reports
- **Unified Timeline Feed:** 
    - Sticky carousel of site summaries (tappable to filter the list).
    - Individual records in a "Live Feed" style with large avatars and status glow highlights.
- **Briefing Cards (Reports):** High-contrast cards for visit/training reports.
    - Verified badges for synced data.
    - Rajdhani typography for site names.

### 3.5. More Tools & Settings
- **Frosted Tool Grid:** 2x2 grid of large icon buttons (Sync, Biometrics, Theme, Incidents).
- **Account Vault:** Frosted section for profile details and logout, using luxury typography.

## 4. Technical Integration
- Use `BackdropFilter` and `ImageFilter.blur` for the glassmorphism effects.
- Leverage `CissThemeTokens` for consistent spacing and rounded corners (`AppRadius.lg`).
- Ensure all screens are wrapped in `SingleChildScrollView` or use `ListView` to prevent overflow.

## 5. Success Criteria
- [ ] Every FO screen uses the `BrandBanner` header.
- [ ] Dashboard hero stats use the frosted glass look with Rajdhani font.
- [ ] Work orders show radial progress rings for assignments.
- [ ] Attendance feed matches the "Live Feed" design with site-site filtering.
- [ ] No layout overflows on standard mobile screens.
