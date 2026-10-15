# Motion & Haptics Foundation Implementation Plan

> **Historical checkpoint status (2026-10-15):** Foundation work is complete and included in the final regression checks. The later approved TCS cross-repository plan supersedes the read-only Duties/preview restrictions and historical model references in this document. The real backend APIs, willingness controls and protected preview fixtures are now implemented. Commit steps are explicitly skipped under the user’s no-commit instruction. Current verification and limitations: `../reports/2026-10-15-redesign-continuation-verification.md`.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's broken haptics stub and ad-hoc transitions with a semantic, cross-platform haptics engine and a single motion-token system that every screen can adopt.

**Architecture:** A small testable core (`HapticEvent` → `HapticsEngine` → `HapticPlatform`) sits behind the existing `Haptics` facade so all 36 call sites keep working while the iOS gap and the "everything is heavy" bug are fixed. Motion becomes one `AppMotion` token module consumed by the router's single `_buildPage` transition helper.

**Tech Stack:** Flutter 3.47, Dart, `flutter/services` (`HapticFeedback`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-13-ciss-mobile-2026-redesign-and-tcs-willingness-design.md`

## Global Constraints

- Flutter SDK `^3.7.0`; Material 3; bundled Inter; no new runtime dependencies for this plan.
- Keep the existing public API: `Haptics.light/medium/heavy/selection/success/error/longPress/swipe/keyboardTap` must still exist and compile.
- Haptics must work on **both** Android and iOS (`HapticFeedback` supports both; the current Android-only guard is the bug).
- One haptic per user action; never on scroll, never in loops.
- Motion: transform/opacity only; no slide between tabs; respect Reduce Motion where spatial motion is added.
- `flutter analyze` must report 0 errors; `flutter test` must stay green.

## Review Focus

- **Haptics disabled at the OS level** — the app should still function with zero haptics and no errors; a user who turned haptics off must never feel a `vibrate()` fallback for a UI tick.
- **Non-mobile/test platform** — calling haptics in a widget test must not throw (the platform channel is absent); the facade must no-op safely.
- **Reduce Motion on** — the new transition must not force spatial motion on users who disabled it.
- **Reduced/Haptic-less OEM actuator** — no legacy one-shot `vibrate()` for discrete UI feedback (only for genuine attention events).
- **Rapid repeated taps** — firing the same haptic many times must not queue/lag or move work onto the UI-thread-critical path.

---

### Task 1: Semantic haptics engine

**Files:**
- Create: `lib/core/haptics/haptic_event.dart`
- Create: `lib/core/haptics/haptic_platform.dart`
- Create: `lib/core/haptics/haptics_engine.dart`
- Modify: `lib/core/haptics.dart` (replace the stub, preserve public API)
- Test: `test/haptics_engine_test.dart`

**Interfaces:**
- Produces: `enum HapticEvent { selection, tick, toggle, light, medium, heavy, confirm, reject, warning, vibrate }`
- Produces: `abstract interface class HapticPlatform { Future<void> lightImpact(); Future<void> mediumImpact(); Future<void> heavyImpact(); Future<void> selectionClick(); Future<void> vibrate(); }`
- Produces: `class FlutterHapticPlatform implements HapticPlatform`
- Produces: `class HapticsEngine { HapticsEngine(this.platform); final HapticPlatform platform; Future<void> emit(HapticEvent event); }`
- Produces (facade, `lib/core/haptics.dart`): `Haptics.engine` (settable), plus `Haptics.emit(HapticEvent)`, and the preserved methods `light/medium/heavy/selection/success/error/longPress/swipe/keyboardTap`.

- [x] **Step 1: Write the failing test**

```dart
// test/haptics_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/haptics/haptic_event.dart';
import 'package:ciss_mobile/core/haptics/haptic_platform.dart';
import 'package:ciss_mobile/core/haptics/haptics_engine.dart';

class _RecordingPlatform implements HapticPlatform {
  final List<String> calls = [];
  @override Future<void> lightImpact() async => calls.add('light');
  @override Future<void> mediumImpact() async => calls.add('medium');
  @override Future<void> heavyImpact() async => calls.add('heavy');
  @override Future<void> selectionClick() async => calls.add('selection');
  @override Future<void> vibrate() async => calls.add('vibrate');
}

void main() {
  group('HapticsEngine mapping', () {
    late _RecordingPlatform p;
    late HapticsEngine e;
    setUp(() { p = _RecordingPlatform(); e = HapticsEngine(p); });

    test('selection, tick and toggle are selection clicks', () async {
      await e.emit(HapticEvent.selection);
      await e.emit(HapticEvent.tick);
      await e.emit(HapticEvent.toggle);
      expect(p.calls, ['selection', 'selection', 'selection']);
    });

    test('impact events map to their strength', () async {
      await e.emit(HapticEvent.light);
      await e.emit(HapticEvent.medium);
      await e.emit(HapticEvent.heavy);
      expect(p.calls, ['light', 'medium', 'heavy']);
    });

    test('confirm is medium and reject/warning are heavy', () async {
      await e.emit(HapticEvent.confirm);
      await e.emit(HapticEvent.reject);
      await e.emit(HapticEvent.warning);
      expect(p.calls, ['medium', 'heavy', 'heavy']);
    });

    test('vibrate is reserved for attention events', () async {
      await e.emit(HapticEvent.vibrate);
      expect(p.calls, ['vibrate']);
    });
  });

  group('Haptics facade', () {
    test('is safe when the platform channel is unavailable', () async {
      // In a widget test there is no real platform channel; the default
      // platform must no-op rather than throw.
      await Haptics.selection();
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/haptics_engine_test.dart`
Expected: FAIL — `haptic_event.dart`/`haptic_platform.dart`/`haptics_engine.dart` not found.

- [x] **Step 3: Implement the core**

`lib/core/haptics/haptic_event.dart`:

```dart
/// Semantic haptics vocabulary. Name the *meaning*, not the motor.
enum HapticEvent { selection, tick, toggle, light, medium, heavy, confirm, reject, warning, vibrate }
```

`lib/core/haptics/haptic_platform.dart`:

```dart
import 'package:flutter/services.dart';

/// Thin, injectable boundary over the platform haptics motor.
abstract interface class HapticPlatform {
  Future<void> lightImpact();
  Future<void> mediumImpact();
  Future<void> heavyImpact();
  Future<void> selectionClick();
  Future<void> vibrate();
}

/// Real implementation. Works on Android and iOS.
class FlutterHapticPlatform implements HapticPlatform {
  const FlutterHapticPlatform();
  @override Future<void> lightImpact() => HapticFeedback.lightImpact();
  @override Future<void> mediumImpact() => HapticFeedback.mediumImpact();
  @override Future<void> heavyImpact() => HapticFeedback.heavyImpact();
  @override Future<void> selectionClick() => HapticFeedback.selectionClick();
  @override Future<void> vibrate() => HapticFeedback.vibrate();
}
```

`lib/core/haptics/haptics_engine.dart`:

```dart
import 'haptic_event.dart';
import 'haptic_platform.dart';

/// Maps semantic events to platform primitives. Pure and testable.
class HapticsEngine {
  const HapticsEngine(this.platform);
  final HapticPlatform platform;

  Future<void> emit(HapticEvent event) {
    switch (event) {
      case HapticEvent.selection:
      case HapticEvent.tick:
      case HapticEvent.toggle:
        return platform.selectionClick();
      case HapticEvent.light:
        return platform.lightImpact();
      case HapticEvent.medium:
      case HapticEvent.confirm:
        return platform.mediumImpact();
      case HapticEvent.heavy:
      case HapticEvent.reject:
      case HapticEvent.warning:
        return platform.heavyImpact();
      case HapticEvent.vibrate:
        return platform.vibrate();
    }
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/haptics_engine_test.dart`
Expected: PASS (core mapping groups).

- [x] **Step 5: Rewrite the facade (`lib/core/haptics.dart`) preserving the public API**

Replace the file body: keep the class `Haptics`, keep every existing static method, remove the Android-only guard, add `engine` (defaulting to `HapticsEngine(const FlutterHapticPlatform())`) and `emit(HapticEvent)`; the legacy methods delegate to `emit`. `success()` → `confirm`, `error()` → `reject`.

- [x] **Step 6: Run the whole suite + analyze**

Run: `flutter test && flutter analyze lib/core lib/app`
Expected: all tests PASS; `No issues found`.

- [x] **Step 7: Commit**

```bash
git add lib/core/haptics.dart lib/core/haptics test/haptics_engine_test.dart
git commit -m "feat(haptics): semantic cross-platform haptics engine"
```

---

### Task 2: Motion tokens + router wiring

**Files:**
- Create: `lib/app/motion.dart`
- Create: `test/app_motion_test.dart`
- Modify: `lib/app/router/app_router.dart:23-57` (use `AppMotion` tokens)

**Interfaces:**
- Produces: `abstract final class AppMotion` with `Duration routeIn`, `Duration routeOut`, `Duration press`, `Curve standardCurve` (strong ease-out), `Curve exitCurve`; plus `Offset routeSlideBegin`.
- Consumes: nothing from Task 1.

- [x] **Step 1: Write the failing test**

```dart
// test/app_motion_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/app/motion.dart';

void main() {
  test('route timings are within the motion budget', () {
    expect(AppMotion.routeIn.inMilliseconds, lessThanOrEqualTo(300));
    expect(AppMotion.routeOut.inMilliseconds, lessThan(AppMotion.routeIn.inMilliseconds));
    expect(AppMotion.press.inMilliseconds, inInclusiveRange(100, 150));
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_motion_test.dart`
Expected: FAIL — `app/motion.dart` not found.

- [x] **Step 3: Implement `lib/app/motion.dart`**

Define `AppMotion` with: `routeIn = Duration(milliseconds: 240)`, `routeOut = Duration(milliseconds: 180)`, `press = Duration(milliseconds: 120)`, `standardCurve = Cubic(0.23, 1, 0.32, 1)`, `exitCurve = Curves.easeIn`, `routeSlideBegin = const Offset(0.06, 0)`. One-line doc comment per field stating its purpose.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/app_motion_test.dart`
Expected: PASS.

- [x] **Step 5: Wire the router to the tokens**

In `app_router.dart` `_buildPage`, replace the hard-coded `Offset(0.08, 0)`, `Curves.easeOutCubic`, `280`/`200` ms with `AppMotion.routeSlideBegin`, `AppMotion.standardCurve`, `AppMotion.routeIn`/`routeOut`. Add the import. When `MediaQuery.disableAnimationsOf(context)` is true, return the child with no `SlideTransition` (cross-fade only).

- [x] **Step 6: Verify + commit**

Run: `flutter test test/app_motion_test.dart && flutter analyze lib/app`
Expected: PASS; no issues.

```bash
git add lib/app/motion.dart lib/app/router/app_router.dart test/app_motion_test.dart
git commit -m "feat(motion): AppMotion tokens and reduced-motion-aware route transitions"
```
