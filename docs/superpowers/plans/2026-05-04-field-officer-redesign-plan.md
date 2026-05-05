# Field Officer "Command Center" Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the entire Field Officer experience with a premium, high-density "Command Center" aesthetic featuring glassmorphism, Rajdhani typography, and enhanced data visibility.

**Architecture:**
- **Modular Redesign:** Create reusable glassmorphism components to ensure consistency across all redesigned screens.
- **Global Header Pattern:** Replace standard app bars with a custom-wrapped `BrandBanner` that handles titles, subtitles, and actions.
- **Isolate & Implement:** Redesign screens one-by-one to maintain stability during the transition.

**Tech Stack:**
- Flutter (Material 3)
- Google Fonts (Rajdhani)
- BackdropFilter (for blurring)
- Riverpod (for state management)

---

### Task 1: Redesign Foundation & Shared Components

**Files:**
- Create: `lib/shared/widgets/glass_card.dart`
- Modify: `lib/shared/widgets/brand_banner.dart` (Add support for generic titles/actions if missing)

- [ ] **Step 1: Create a reusable GlassCard component**

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: accentColor?.withValues(alpha: 0.3) ?? tokens.border.withValues(alpha: 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit foundation**

```bash
git add lib/shared/widgets/glass_card.dart
git commit -m "feat: add reusable GlassCard component for redesign"
```

---

### Task 2: Dashboard Overhaul (The Command Hub)

**Files:**
- Modify: `lib/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart`

- [ ] **Step 1: Implement "Command Tiles" (Hero Stats)**
Replace the top section with a horizontal list of large `GlassCard` stats using Rajdhani typography.

- [ ] **Step 2: Implement "Command Log" (The new Notebook)**
Transform the notebook into a modern, collapsible panel at the bottom of the screen.

- [ ] **Step 3: Replace AppBar with BrandBanner**
Update the screen scaffold to use the brand header.

- [ ] **Step 4: Commit Dashboard**

```bash
git add lib/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart
git commit -m "feat: redesign Field Officer dashboard with Command Hub aesthetic"
```

---

### Task 3: Work Orders Overhaul (Operation Tiles)

**Files:**
- Modify: `lib/features/field_officer/presentation/screens/field_officer_work_orders_screen.dart`

- [ ] **Step 1: Implement Glassmorphism "Operation Tiles"**
Each work order should be a `GlassCard` with a radial progress ring for assignments.

- [ ] **Step 2: Redesign Assignment Sheet**
Apply the frosted glass look and Rajdhani typography to the `_AssignGuardsSheet`.

- [ ] **Step 3: Commit Work Orders**

```bash
git add lib/features/field_officer/presentation/screens/field_officer_work_orders_screen.dart
git commit -m "feat: redesign Work Orders with operation tiles and frosted sheets"
```

---

### Task 4: Attendance & Reports Overhaul (Live Feed)

**Files:**
- Modify: `lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart`
- Modify: `lib/features/field_officer/presentation/screens/field_officer_reports_screen.dart`

- [ ] **Step 1: Implement Unified Timeline Feed**
Overhaul the attendance page to use a sticky site-filtering carousel and high-contrast "Live Feed" rows.

- [ ] **Step 2: Implement "Briefing Cards" for Reports**
Overhaul the reports list with premium high-contrast cards and verified badges.

- [ ] **Step 3: Commit Attendance & Reports**

```bash
git add lib/features/field_officer/presentation/screens/field_officer_attendance_screen.dart lib/features/field_officer/presentation/screens/field_officer_reports_screen.dart
git commit -m "feat: redesign Attendance and Reports with live feed and briefing cards"
```

---

### Task 5: More Tools & Settings Overhaul

**Files:**
- Modify: `lib/features/field_officer/presentation/field_officer_shell.dart` (For the "More" screen)

- [ ] **Step 1: Implement Frosted Tool Grid**
Create a 2x2 grid of large icon buttons for settings.

- [ ] **Step 2: Implement "Account Vault"**
Redesign the user profile and session section at the bottom.

- [ ] **Step 3: Commit More Tools**

```bash
git add lib/features/field_officer/presentation/field_officer_shell.dart
git commit -m "feat: redesign More tools page with settings vault aesthetic"
```

---

### Task 6: Final Polish & Verification

- [ ] **Step 1: Run Full Analysis**

Run: `flutter analyze`
Expected: PASS

- [ ] **Step 2: Verify Responsive Layouts**
Ensure all glassmorphism cards and carousels behave correctly on narrow/wide mobile screens.
