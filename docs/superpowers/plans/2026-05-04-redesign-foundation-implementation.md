# Redesign Foundation & Shared Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a reusable `GlassCard` component for the redesign and ensure `BrandBanner` is ready for broader use.

**Architecture:** Use `BackdropFilter` for the glass effect and `CissThemeTokens` for consistent styling.

**Tech Stack:** Flutter

---

### Task 1: Create GlassCard component

**Files:**
- Create: `lib/shared/widgets/glass_card.dart`

- [ ] **Step 1: Write the implementation**

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
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
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
              boxShadow: [
                BoxShadow(
                  color: (accentColor ?? tokens.primary).withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze to verify syntax**

Run: `flutter analyze`
Expected: No issues found in `lib/shared/widgets/glass_card.dart`

- [ ] **Step 3: Commit the change**

```bash
git add lib/shared/widgets/glass_card.dart
git commit -m "feat: add reusable GlassCard component for redesign"
```

### Task 2: Verify BrandBanner component

**Files:**
- Modify: `lib/shared/widgets/brand_banner.dart`

- [ ] **Step 1: Check existing implementation**
The existing implementation already supports `title` and `subtitle`. No changes needed based on current requirements.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Commit if any changes were made**
(Skip if no changes)
