# De-clutter Primitives & Guard Home Implementation Plan

> **Historical checkpoint status (2026-10-15):** Foundation work is complete and included in the final regression checks. The later approved TCS cross-repository plan supersedes the read-only Duties/preview restrictions and historical model references in this document. The real backend APIs, willingness controls and protected preview fixtures are now implemented. Commit steps are explicitly skipped under the user’s no-commit instruction. Current verification and limitations: `../reports/2026-10-15-redesign-continuation-verification.md`.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every screen three reusable de-clutter primitives (press feedback, a single primary action, a compact secondary-action row) and rebuild Guard Home on them so it reads as "what do I do now" instead of a data dump.

**Architecture:** New primitives live in `lib/shared/widgets/` and compose existing tokens (`CissThemeTokens`, `AppSpacing`, `AppRadius`) plus the new `AppMotion` tokens and `Haptics`. Guard Home is reduced to: hero → one primary action (Mark Attendance) → next-duty card → a short secondary-action cluster, with month metrics and everything else moved below the fold or behind routes.

**Tech Stack:** Flutter 3.47, Material 3, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-13-ciss-mobile-2026-redesign-and-tcs-willingness-design.md`

## Global Constraints

- Flutter SDK `^3.7.0`; Material 3; bundled Inter; no new dependencies.
- One primary action per screen; at most 3 content blocks above the fold.
- Press feedback lands on press-**in**, 100–150 ms (`AppMotion.press`), fires exactly one haptic.
- Motion uses `AppMotion` tokens only; haptics use `Haptics.*` only.
- Tap targets ≥ 44 px; light + dark must both render correctly.
- `flutter analyze` adds no new issues; `flutter test` stays green.

## Review Focus

- **Very long guard names / districts** — the hero and action labels must truncate, not overflow.
- **Rapid repeated taps** — press feedback must not stack animations or fire multiple haptics per tap.
- **Dark mode** — primary action contrast must pass in dark; no hard-coded light-only colors.
- **Missing next-shift data** — the screen must render a composed empty state, not a blank/broken block.
- **Screen reader (TalkBack/TalkBack semantics)** — the primary action and each row must expose a label and be tappable; decorative icons excluded.

---

### Task 1: Press feedback primitive (`PressableScale`)

**Files:**
- Create: `lib/shared/widgets/pressable.dart`
- Test: `test/de_clutter_primitives_test.dart`

**Interfaces:**
- Produces: `class PressableScale extends StatefulWidget { const PressableScale({Key? key, required Widget child, VoidCallback? onTap, HapticEvent? haptic = HapticEvent.light, double pressedScale = 0.97}); }`

- [x] **Step 1: Write the failing tests** (see the widget tests in `test/de_clutter_primitives_test.dart`, group `PressableScale`).
- [x] **Step 2: Run** `flutter test test/de_clutter_primitives_test.dart` → FAIL.
- [x] **Step 3: Implement** `PressableScale`: `GestureDetector` (`onTapDown` → set pressed + `Haptics.emit(haptic)`; `onTapUp`/`onTapCancel` → clear; `onTap` → `onTap`), wrapping `AnimatedScale(scale: pressed ? pressedScale : 1, duration: AppMotion.press, curve: AppMotion.standardCurve)`. `HitTestBehavior.opaque`.
- [x] **Step 4: Run** the test → PASS.

### Task 2: Primary action + secondary action row

**Files:**
- Create: `lib/shared/widgets/primary_action.dart`
- Create: `lib/shared/widgets/action_row.dart`
- Test: `test/de_clutter_primitives_test.dart`

**Interfaces:**
- Produces: `class PrimaryAction extends StatelessWidget { const PrimaryAction({Key? key, required IconData icon, required String label, String? sublabel, required VoidCallback onTap, bool enabled = true}); }`
- Produces: `class ActionRow extends StatelessWidget { const ActionRow({Key? key, required IconData icon, required String label, String? trailing, VoidCallback? onTap, IconData? leadingBadge}); }`

- [x] **Step 1: Write the failing tests** (groups `PrimaryAction`, `ActionRow`).
- [x] **Step 2: Run** → FAIL.
- [x] **Step 3: Implement** both on top of `PressableScale` (PrimaryAction haptic `medium`, ActionRow haptic `light`), using `CissThemeTokens` for color and `AppRadius`/`AppSpacing` for shape/spacing. PrimaryAction fills with `tokens.primary`, white content, ≥56 px tall, `Semantics(button: true, label: ...)`. ActionRow is a ≥56 px row: icon, label (w600), optional trailing chip text, optional chevron.
- [x] **Step 4: Run** → PASS.

### Task 3: Rebuild Guard Home on the primitives

**Files:**
- Modify: `lib/features/guard/presentation/screens/guard_dashboard_screen.dart`

- [x] **Step 1:** Reduce `_DashboardBody` to: `ModernHero` → `PrimaryAction(Mark Attendance)` → next-duty `ModernCard` (or `StateBlock` empty state) → `SectionHeader('More')` + 3–4 `ActionRow`s (Payslips, Leave, Patrol, Training). Move the Present/Absent/Working metrics below the fold (or into a `SectionHeader('This month')` collapsible).
- [x] **Step 2:** Verify light/dark + long-name truncation in the simulator; run `flutter analyze` and `flutter test`.
- [x] **Step 3: Commit.** Skipped by the user’s no-commit instruction; work remains uncommitted.
