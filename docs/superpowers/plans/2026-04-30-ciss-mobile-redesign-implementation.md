# CISS Mobile Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter mobile UI around a consistent, production-grade design system and apply it to the highest-value guard and field officer flows.

**Architecture:** Implement the redesign system-first. Start by replacing the global theme, shared shell, navigation, cards, rows, and state components; then migrate screens onto those primitives in descending user-value order. Keep the data model and API calls stable while changing presentation and screen composition.

**Tech Stack:** Flutter, Material 3, Riverpod, go_router, google_fonts, existing mobile feature modules

---

## File Structure

**Create:**
- `/Users/mymac/Documents/CISS-Mobile/lib/app/theme/app_tokens.dart` — color, spacing, radius, elevation, and layout constants
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/page_header.dart` — standardized page intro/header block
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/metric_tile.dart` — compact and standard metric tiles
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/status_chip.dart` — reusable operational status chips
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/state_block.dart` — loading, empty, error, and offline blocks
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/branded_navigation_bar.dart` — custom bottom navigation shell

**Modify:**
- `/Users/mymac/Documents/CISS-Mobile/lib/app/theme/app_theme.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/screen_scaffold.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/section_card.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/brand_banner.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/company_contact_card.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/sync_status_badge.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/guard_shell.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/field_officer_shell.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/login_hub_screen.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/role_login_screen.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/permission_onboarding_screen.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_dashboard_screen.dart`
- `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart`

**Test/Verify:**
- `/Users/mymac/Documents/CISS-Mobile/test/widget_test.dart`

### Task 1: Build the redesign system layer

**Files:**
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/app/theme/app_tokens.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/page_header.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/metric_tile.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/status_chip.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/state_block.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/branded_navigation_bar.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/app/theme/app_theme.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/screen_scaffold.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/section_card.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/brand_banner.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/company_contact_card.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/sync_status_badge.dart`

- [ ] **Step 1: Add the new design tokens**
- [ ] **Step 2: Replace the app theme with the Balanced Operations system**
- [ ] **Step 3: Add reusable header, metric, status, and state widgets**
- [ ] **Step 4: Rebuild scaffold, cards, and brand banner onto the new system**
- [ ] **Step 5: Run `flutter analyze`**

### Task 2: Rebuild app shell and navigation

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/guard_shell.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/field_officer_shell.dart`
- Use: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/branded_navigation_bar.dart`

- [ ] **Step 1: Replace direct `NavigationBar` usage with the branded nav component**
- [ ] **Step 2: Rework “More” screens to match the new list/card system**
- [ ] **Step 3: Run `flutter analyze`**

### Task 3: Redesign auth and setup flows

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/login_hub_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/role_login_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/permission_onboarding_screen.dart`

- [ ] **Step 1: Redesign the login hub with the new component system**
- [ ] **Step 2: Redesign guard and field officer login forms**
- [ ] **Step 3: Redesign the permission onboarding screen**
- [ ] **Step 4: Run `flutter analyze`**

### Task 4: Redesign guard and field officer dashboards

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_dashboard_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart`

- [ ] **Step 1: Recompose the guard dashboard as a true overview screen**
- [ ] **Step 2: Recompose the field officer dashboard as a command overview**
- [ ] **Step 3: Replace ad hoc metric blocks with shared metric components**
- [ ] **Step 4: Run `flutter analyze`**

### Task 5: Stabilize the baseline widget test

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/test/widget_test.dart`

- [ ] **Step 1: Update the smoke test to assert the redesigned app shell boots**
- [ ] **Step 2: Run `flutter test test/widget_test.dart`**

## Self-Review

Spec coverage for the first implementation slice is complete:
- design system, shell, auth, and dashboards are explicitly covered
- deeper module redesign work remains for later execution after this baseline lands

No placeholders remain in the task definitions; scope is intentionally limited to the highest-leverage UI layer so the implementation can start cleanly.
