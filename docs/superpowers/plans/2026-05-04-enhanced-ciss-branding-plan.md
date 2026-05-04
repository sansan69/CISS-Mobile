# Enhanced CISS Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increase the prominence of the CISS brand on the landing page (Login Hub) with a premium header and modern aesthetic adjustments.

**Architecture:** 
- **Premium Brand Header:** Replace the top `Row` with a centered `Column` featuring a large logo (72px) and a bold company display.
- **Glassmorphism:** Apply a semi-transparent, blurred effect to the role selection cards for a modern look.
- **Improved Spacing:** Increase negative space between the brand identity and the action items.

**Tech Stack:** 
- Flutter (Material 3)
- Google Fonts (Rajdhani)
- BackdropFilter (for glassmorphism)

---

### Task 1: Premium Brand Header Implementation

**Files:**
- Modify: `lib/features/auth/presentation/login_hub_screen.dart`

- [ ] **Step 1: Replace the top brand Row with a centered Column**

```dart
// lib/features/auth/presentation/login_hub_screen.dart
// In build() method of _LoginHubScreenState:

            children: <Widget>[
              // Brand mark — high prominence identity
              FadeTransition(
                opacity: _fade(0.0, 0.5),
                child: Center(
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 20),
                      Container(
                        width: 88,
                        height: 88,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tokens.primarySoft,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tokens.primary.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        kCompanyName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: tokens.primary,
                          letterSpacing: 3,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kCompanyTagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.inkMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              // ... rest of Column
```

- [ ] **Step 2: Run flutter analyze to verify syntax**

Run: `flutter analyze`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/presentation/login_hub_screen.dart
git commit -m "feat: implement premium brand header on login hub"
```

---

### Task 2: Glassmorphism Role Cards

**Files:**
- Modify: `lib/features/auth/presentation/login_hub_screen.dart`

- [ ] **Step 1: Implement glassmorphism in _RoleCard**

```dart
// lib/features/auth/presentation/login_hub_screen.dart
// Update _RoleCard building logic:

      child: AnimatedScale(
        scale: _pressed ? 0.974 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _pressed
                      ? widget.accentColor.withValues(alpha: 0.5)
                      : tokens.border.withValues(alpha: 0.5),
                ),
                boxShadow: _pressed ? const <BoxShadow>[] : AppShadows.card,
              ),
              // ... rest of child
```

- [ ] **Step 2: Add missing import for ImageFilter**

```dart
import 'dart:ui'; // Add this at top
```

- [ ] **Step 3: Run flutter analyze to verify syntax**

Run: `flutter analyze`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/presentation/login_hub_screen.dart
git commit -m "feat: add glassmorphism effect to role selection cards"
```

---

### Task 3: Visual Refinement & Verification

- [ ] **Step 1: Adjust 'Select your portal' text position**

Ensure the "Select your portal" text is centered or positioned aesthetically between the header and the cards.

- [ ] **Step 2: Final Analysis**

Run: `flutter analyze`
Expected: PASS
