# CISS Mobile App — Complete UI/UX Redesign Specification

**Date:** 2026-07-05  
**Project:** CISS-Mobile Flutter App  
**Scope:** Redesign all pages for Guard, Field Officer, Admin, and Client roles. Implement all missing features present in the Next.js webapp (`/Documents/CISS`).  
**Design direction:** Modern Enterprise, fully adaptive to device light/dark mode.

---

## 1. Goals

1. Provide a modern, cohesive visual experience across all four user roles.
2. Ensure every dashboard surfaces the most relevant data for that role at a glance.
3. Make the app fully adaptive to system light/dark themes.
4. Implement all major features from the webapp that are currently missing in mobile.
5. Improve information hierarchy, readability, and touch targets for field use.
6. Keep the implementation within the existing Riverpod + GoRouter + Dio + Hive stack.

---

## 2. Design Direction

### 2.1 Visual Style: Modern Enterprise

- **Clean card-based layouts** with generous whitespace.
- **Soft, purposeful shadows** on elevated surfaces.
- **Rounded corners:** 16px–20px for cards, 12px for inputs, 999px for pills/FABs.
- **Gradient hero panels** using primary-to-primaryStrong for role dashboards.
- **Status colors** used as accents: success green, warning amber, danger red, primary blue.
- **Adaptive surfaces:** light mode uses white cards on a subtle canvas; dark mode uses tinted dark surfaces with translucent overlays.

### 2.2 Light / Dark Adaptivity

The app must respect the device's theme setting via `MediaQuery.platformBrightnessOf(context)` and `ThemeMode.system`. All widgets use `CissThemeTokens.of(context)` and the existing `ThemeExtension` already supports light/dark tokens.

**Required additions to tokens:**

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `surfaceGlass` | `rgba(255,255,255,0.7)` | `rgba(20,30,40,0.6)` | Glassmorphic metric cards on hero |
| `surfaceAlt` | `#F8FAFB` | `#192532` | Alternating list/card backgrounds |
| `chartGrid` | `#EAF0F4` | `#223142` | Chart gridlines |

---

## 3. Design System Refinements

### 3.1 Updated Tokens

Extend `CissThemeTokens` with `surfaceGlass` and `surfaceAlt`. Keep all existing tokens (canvas, surface, ink, primary, success, warning, danger, etc.).

### 3.2 Typography

Use existing `AppTypography` scale. Emphasize:

- `AppTypography.display` for hero titles.
- `AppTypography.metric` for large dashboard numbers.
- `AppTypography.title` for section headers.
- `AppTypography.label` for uppercase section labels.

### 3.3 Spacing & Radius

- Page horizontal padding: **16px**.
- Section vertical gap: **24px**.
- Card internal padding: **16px**.
- Card-to-card gap: **12px**.
- Card radius: **16px–20px**.
- Input radius: **12px**.
- Pill/FAB radius: **999px**.

### 3.4 Shadows

Continue using `AppShadows.card` and `AppShadows.subtle`. Add a lighter shadow for metric cards.

### 3.5 Motion

- Page transitions: **200ms** ease.
- List stagger: **50ms** per item.
- FAB press: scale to **0.95**.
- Pull-to-refresh haptic: `Haptics.medium()` on trigger.
- Chart/data load: animate bars/counts over **400ms**.

---

## 4. Navigation Structure

Keep a bottom-tab shell per role. Unify where possible.

| Role | Tab 1 | Tab 2 | Tab 3 | Tab 4 |
|------|-------|-------|-------|-------|
| **Admin** | Home | Workforce | Operations | More |
| **Client** | Home | Guards | Activity | More |
| **Field Officer** | Home | Duties | Reports | More |
| **Guard** | Home | Schedule | Activity | Profile |

### 4.1 More Menu Contents

**Admin More:**
- Training (modules, assignments, question banks)
- Evaluations & Leaderboard
- Payroll cycles
- Settings hub (clients, sites, wage config, imports, exports, QR, bulk import)
- Notifications composer
- Sign out

**Client More:**
- Visit Reports
- Training Reports
- Patrol Activity
- Notifications inbox
- Sign out

**Field Officer More:**
- Guards directory
- Attendance logs
- Tools / QR scanner
- Profile / sync status
- Sign out

---

## 5. Dashboard Designs

### 5.1 Admin Dashboard

**Hero panel:** greeting, "Admin Portal", region + client/site counts.

**Metrics strip (horizontal scroll):**
- Total guards
- On duty now
- Checked in today
- Pending work orders
- Total clients
- Total sites

**Infographics section:**
- **Daily attendance per client:** horizontal bar chart (client name + % checked in).
- **District-wise enrollment:** donut or stacked bar chart showing guard count per district plus total.
- **TCS upcoming duties:** list card of next 3–5 TCS work order shifts (site, date, guards required).
- **Field officer report status:** table/card showing each FO, visit reports count, training reports count, and sites under them.
- **Pending action shortcuts:** Enroll Guard, Run Payroll, Send Alert, Import Work Orders.

**Live activity feed:** recent check-ins, alerts, report submissions.

### 5.2 Client Dashboard

**Hero panel:** "Welcome back", client name, guard/site count.

**Metrics grid (2x2):**
- On Duty
- Checked In
- Night Checks
- Pending Reports

**Top sites:** list of sites with on-duty / total guard ratio.

**Guard highlights:** horizontal cards for top performers or recent alerts.

**Live attendance:** top 5 currently checked-in guards with duty point/shift.

**Quick links:** Visit Reports, Training Reports, Patrol Activity.

### 5.3 Field Officer Dashboard

**Hero panel:** FO name, assigned districts.

**Metrics strip:**
- My Guards
- On Duty
- Reports Due

**Coverage section:** progress bars per district showing attendance coverage %.

**Pending duties:** upcoming site visits/work orders.

**Primary FAB:** "+ New Report".

### 5.4 Guard Dashboard

**Hero panel:** greeting, guard name, current site/district, profile avatar.

**Metrics strip:**
- Present days
- Absent days
- Working days

**Next shift card:** date, time, site.

**Quick actions:** Check In, View Payslips, Start Patrol, Report Incident.

**Upcoming sections:** training due, recent evaluation score, latest payslip.

---

## 6. Existing Screen Redesigns

The following existing screens must be redesigned using the new tokens, cards, spacing, and adaptive theme:

### Admin
- `admin_dashboard_screen.dart`
- `admin_guards_screen.dart`
- `admin_attendance_screen.dart`
- `admin_orders_screen.dart`
- `admin_more_screen.dart`
- `admin_training_screen.dart`
- `admin_evaluations_screen.dart`
- `admin_payroll_screen.dart`
- `admin_settings_screen.dart`
- `admin_field_officers_screen.dart`
- `admin_notifications_screen.dart`

### Client
- `client_dashboard_screen.dart`
- `client_guards_screen.dart`
- `client_attendance_screen.dart`
- `client_orders_screen.dart`
- `client_more_screen.dart`
- `client_visit_reports_screen.dart`
- `client_training_reports_screen.dart`
- `client_patrol_activity_screen.dart`

### Field Officer
- `field_officer_dashboard_screen.dart`
- `field_officer_guards_screen.dart`
- `field_officer_work_orders_screen.dart`
- `field_officer_attendance_screen.dart`
- `field_officer_reports_screen.dart`
- `field_officer_tools_screens.dart`
- `field_officer_guard_detail_screen.dart`

### Guard
- `guard_dashboard_screen.dart`
- `guard_attendance_screen.dart`
- `guard_profile_screen.dart`
- `guard_training_screen.dart`
- `guard_training_detail_screen.dart`
- `guard_evaluations_screen.dart`
- `guard_payslips_screen.dart`
- `guard_leave_screen.dart`
- `guard_incidents_screen.dart`
- `guard_patrol_screen.dart`

### Shared
- `login_hub_screen.dart`
- `admin_login_screen.dart`
- `role_login_screen.dart`
- All shell screens (`admin_shell.dart`, `client_shell.dart`, `guard_shell.dart`, `field_officer_shell.dart`)

---

## 7. Missing Features to Implement

Based on webapp parity analysis.

### 7.1 Admin

| Feature | Webapp Path | Mobile Implementation |
|---------|-------------|----------------------|
| Enroll guard | `/employees/enroll` | New `admin_enroll_guard_screen.dart` |
| Employee detail/edit/status | `/employees/[id]` | New `admin_guard_detail_screen.dart` |
| Bulk employee import | `/settings/bulk-import` | New `admin_bulk_import_screen.dart` |
| QR management | `/settings/qr-management` | New `admin_qr_management_screen.dart` |
| Data export | `/settings/data-export` | New `admin_data_export_screen.dart` |
| Wage config | `/settings/wage-config` | New `admin_wage_config_screen.dart` |
| Enrollment form config | `/settings/enrollment-form` | New `admin_enrollment_config_screen.dart` |
| Client CRUD | `/settings/clients` | Extend settings or new `admin_clients_screen.dart` |
| Site/office CRUD + geocode | `/settings/site-management`, `/settings/client-locations` | New `admin_sites_screen.dart` |
| Create evaluation | `/evaluations` | Add FAB/form to `admin_evaluations_screen.dart` |
| Work order import/preview/commit | `/work-orders`, `/work-orders/import/preview` | New `admin_work_order_import_screen.dart` |
| Work order rename/bulk delete | `/work-orders` | Add actions to `admin_orders_screen.dart` |

### 7.2 Client

| Feature | Webapp Path | Mobile Implementation |
|---------|-------------|----------------------|
| Guard profile detail | `/employees/[id]` | New `client_guard_detail_screen.dart` |
| Work order site detail | `/work-orders/[siteId]` | Optional detail sheet in `client_orders_screen.dart` |

### 7.3 Field Officer

| Feature | Webapp Path | Mobile Implementation |
|---------|-------------|----------------------|
| Work order/site assignment editing | `/work-orders/[siteId]` | Edit flow in `field_officer_work_orders_screen.dart` |
| Visit report submission parity | `/visit-reports` | Verify/update `field_officer_reports_screen.dart` |
| Training report submission parity | `/training-reports` | Verify/update `field_officer_reports_screen.dart` |

### 7.4 Guard

| Feature | Webapp Path | Mobile Implementation |
|---------|-------------|----------------------|
| Quiz/training parity | `/guard/training/quiz/[assignmentId]` | Verify `guard_training_detail_screen.dart` |

---

## 8. Shared Component Library

Create/update the following reusable widgets under `lib/shared/widgets/`:

| Widget | Purpose |
|--------|---------|
| `modern_card.dart` | Base card with radius, shadow, border, adaptive colors |
| `modern_hero.dart` | Gradient hero panel with title/subtitle/avatar |
| `metric_card.dart` | Compact metric value + label with tinted background |
| `metric_strip.dart` | Horizontal scroll of metric cards |
| `section_header.dart` | Uppercase label + optional action |
| `info_row.dart` | Label/value row for detail screens |
| `status_badge.dart` | Pill-shaped status indicator |
| `modern_fab.dart` | Primary floating action button |
| `modern_bottom_nav.dart` | Updated bottom nav with active pill |
| `modern_input.dart` | Outlined text field with filled background |
| `modern_dropdown.dart` | Dropdown selector with consistent styling |
| `modern_button.dart` | Filled/tonal/outlined button variants |
| `document_list_tile.dart` | Document name + type + download action |
| `mini_bar_chart.dart` | Simple horizontal bar chart for admin dashboard |
| `mini_donut_chart.dart` | Donut chart for district enrollment |
| `data_table_card.dart` | Card-based table for FO report status |

---

## 9. Animation & Motion

- Use `AnimatedSwitcher` for dashboard loading → data transitions.
- Use `AnimatedContainer` for card hover/press states.
- Animate metric numbers with `TweenAnimationBuilder` on first load.
- Use `SliverAnimatedList` or staggered list animations for long lists.
- Page transitions via GoRouter custom transitions: fade + slight slide up.

---

## 10. Implementation Approach

1. **Update design tokens** — add `surfaceGlass`, `surfaceAlt`, `chartGrid`.
2. **Build shared component library** — create all widgets in Section 8.
3. **Redesign shells** — update bottom nav to modern pill style.
4. **Redesign dashboards** — one role at a time, starting with Admin.
5. **Redesign list/detail screens** — guards, attendance, orders, reports.
6. **Implement missing admin features** — enrollment, client/site CRUD, evaluations, imports.
7. **Implement missing client features** — guard detail.
8. **Verify FO report submission parity** — update if needed.
9. **Verify guard training/quiz parity** — update if needed.
10. **Theming audit** — ensure every screen adapts to light/dark.
11. **Compilation and navigation testing** — 0 errors, 0 warnings.

---

## 11. Acceptance Criteria

- [ ] All four roles have redesigned dashboards matching Section 5.
- [ ] The app renders correctly in both light and dark modes.
- [ ] All existing screens use the new shared components and tokens.
- [ ] All missing features in Section 7 are implemented and navigable.
- [ ] No compilation errors or warnings (`flutter analyze lib/`).
- [ ] Navigation between tabs and pushed screens remains functional.
- [ ] Pull-to-refresh, error states, and empty states use the new design.
- [ ] Haptics and animations are consistent across roles.

---

## 12. Out of Scope

- Payroll run/cycle detail/finalize (explicitly skipped by stakeholder).
- Super-admin region onboarding wizard.
- Live guards map on admin dashboard (can be added later).
- Backend API changes; assume existing webapp endpoints are available.

---

## 13. Notes

- Maintain existing state management (Riverpod) and API patterns.
- Reuse existing models; extend only where missing fields are required.
- Mobile-appropriate simplifications are acceptable for complex webapp flows (e.g., geocode as a single "Verify coordinates" action rather than full map editing).
- All new screens must support pull-to-refresh and proper `mounted` checks.
