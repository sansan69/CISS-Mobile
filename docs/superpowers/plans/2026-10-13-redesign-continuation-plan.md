# Redesign Continuation Implementation Plan

> **Historical checkpoint status (2026-10-15):** Foundation work is complete and included in the final regression checks. The later approved TCS cross-repository plan supersedes the read-only Duties/preview restrictions and historical model references in this document. The real backend APIs, willingness controls and protected preview fixtures are now implemented. Commit steps are explicitly skipped under the user’s no-commit instruction. Current verification and limitations: `../reports/2026-10-15-redesign-continuation-verification.md`.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the started motion/haptics and Guard Home plans, and make the started Duties surface useful with verified existing data while preserving attendance and other shipped flows.

**Architecture:** Keep Flutter/Riverpod, existing theme tokens and role shells. Finish the shared interaction primitives, then compose Guard Home from them. The read-only Duties screen reuses the existing dashboard's next assigned work order; no speculative server route or willingness write becomes production behavior.

**Tech Stack:** Flutter, Dart SDK constraint `^3.7.0`, Material 3, Riverpod 2, GoRouter 16, flutter_test; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-13-ciss-mobile-2026-redesign-and-tcs-willingness-design.md`.

**Preceding plans:** `2026-10-13-motion-haptics-foundation.md` and `2026-10-13-declutter-primitives-and-guard-home.md` in this directory. This plan completes their local implementation scope; the broad spec remains a roadmap, not a claim that all roles and backend features are finished.

## Global Constraints

- Preserve all existing attendance, authentication, offline queue, patrol, leave, training, payslip, notification, and FO behavior.
- Assignment is informational only; attendance works with or without an assignment.
- One primary action per screen; at most 3 main content blocks before scrolling at a normal phone size. Larger accessibility text may naturally require more scrolling.
- Press feedback lands on press-in, 100–150 ms (`AppMotion.press`); one haptic per interaction; disabled controls are inert; reduced motion disables spatial feedback.
- Navy/gold branding, bundled Inter, light/dark support, no added gradients/glows/emoji-like checkmark glyphs, no equal-weight three-column metrics.
- New interactive targets are at least 44 px; PrimaryAction and ActionRow remain at least 56 px.
- Use AppMotion and Haptics for new feedback, without adding a platform bridge or claiming unsupported native haptic semantics.
- User's latest workflow: GPT-6 Astra writes new plans only; GPT-6.1 Sol implements/fixes; a separate GPT-6.1 Sol agent reviews. Repeat review until no actionable defects and checks pass.
- Work in the isolated copied worktree `/Users/mymac/.codex/worktrees/redesign-continuation/CISS-Mobile`; preserve the original unfinished source snapshot. Do not commit, push, merge, deploy, change backend files, or write live data.
- Record pre-existing analyzer findings separately; add no new errors or warnings. Remove the three confirmed unused imports in the draft primitive test, auth_controller.dart and permission_onboarding_screen.dart as analyzer hygiene only. Do not expand into unrelated cleanup.

## Status Inventory (inspection on 2026-10-13)

| Area | Current state | Remaining work |
| --- | --- | --- |
| Semantic haptics | Event enum, platform interface, engine and compatible facade exist; mappings tested | Prove real platform-channel failure safety; preserve all old methods; ensure failures never escape fire-and-forget UI calls |
| Motion | Tokens and router reduced-motion branch exist | Test actual route behavior, not just token numbers; preserve non-sliding tabs |
| PressableScale | Press animation and recording haptics tests exist | Null callback still receives gesture feedback; ignores reduced motion; cancellation/rapid interactions insufficiently tested |
| PrimaryAction / ActionRow | Widgets and basic tap tests exist | Accessible single semantic labels/actions, inert disabled rows, long trailing text, dark foreground contrast, large text |
| Guard Home | Substantially reduced from previous dashboard | Short bottom padding lets floating nav obscure content; still has three-column metrics; long hero competes with controls; full-page spinner; CTA guesses attendance from shift text; refresh completes early |
| Home navigation | Payslip/leave/incidents actions remain; Patrol always shown; Training label opens leaderboard | Honor existing module flags; Training opens training assignments while leaderboard remains available; preserve operational tools |
| Guard Duties | Draft models, screen and two new repository methods exist | Both proposed guard-duties endpoints are absent from sibling backend; current production entry would fail; online-only willingness violates offline requirement |
| Existing backend data | `../CISS/src/app/api/guard/dashboard/route.ts` returns next assigned active work order, `nextShiftUnavailable`, attendance status | Mobile ignores next-shift unavailable flag. Reuse supported next duty; do not describe it as a complete future-duty list |
| Verification | Four new draft test files exist; no dashboard/duties widget regressions | Run baseline and focused tests, full suite, analyze, build if practical, safe visual preview |

The on-duty inference, Patrol gate omission, and leaderboard-targeted shortcut predate this draft. They should be corrected narrowly because the touched Home now gives them more prominent meaning. No backend contract may be inferred from mock data such as `shiftLabel: 'On Duty'`.

## Review Focus

1. Missing assignment, whitespace-only assignment fields, or next-shift query failure must never hide attendance or falsely assert the guard is checked in (Tasks 3–4).
2. Narrow phones, large text, long names/districts/row metadata, and dark mode must remain readable without overflow or floating-nav obstruction (Tasks 2–4).
3. Disabled actions, canceled presses, fast repeated taps, reduced motion, and unavailable haptic channels must not produce unexpected action/feedback/errors (Tasks 1–2).
4. Remote module flags and existing training/payslip/patrol paths must remain accurate and reachable (Task 3).
5. Refresh/retry, loading/error states, and preview navigation must settle correctly without fetching speculative APIs or writing live data (Tasks 3–5).

---

### Task 1: Finish failure-safe haptics and verify route motion

**Files:** `lib/core/haptics.dart`, `lib/core/haptics/haptic_platform.dart`, `lib/app/motion.dart`, `lib/app/router/app_router.dart`, `test/haptics_engine_test.dart`, `test/app_motion_test.dart`; add `test/app_route_motion_test.dart` if route tests warrant a separate file.

**Interfaces:** Preserve `Haptics.engine`, `enabled`, `emit(HapticEvent)` and every existing static legacy/semantic method. Preserve AppMotion timings (240 ms route in, 180 ms out, 120 ms press), slide offset `(0.06, 0)`, and standard curve. Use the router's existing page builder; extract a small reusable transition function only if necessary to test the actual implementation.

- [x] Add failing tests that configure `SystemChannels.platform` to throw `MissingPluginException` and `PlatformException` during haptic dispatch; `await Haptics.selection()` and an impact call complete without errors. Existing fake engine mapping tests still verify the expected strength and no vibrate fallback.
- [x] Run `flutter test test/haptics_engine_test.dart` and record the expected new failures.
- [x] Catch unsupported/failed platform haptic calls at the facade or adapter boundary; do not mask arbitrary product errors or schedule fallback vibrations. Keep each dispatch one asynchronous platform call.
- [x] Add actual transition coverage: normal route transition includes spatial motion at an intermediate frame; `MediaQueryData(disableAnimations: true)` yields fade only. Test the code consumed by the router rather than duplicating its logic in a test helper.
- [x] Run haptics/motion/router tests; verify the GuardShell still switches via IndexedStack without a slide. Document the supported Flutter haptic mappings and their visual purpose; native Android CONFIRM/REJECT-specific semantics remain a later platform enhancement.

### Task 2: Complete accessible press and action primitives

**Files:** `lib/shared/widgets/pressable.dart`, `primary_action.dart`, `action_row.dart`, `test/de_clutter_primitives_test.dart`.

**Interfaces:** Keep current constructors compatible. `PressableScale.onTap == null` means disabled. PrimaryAction preserves `enabled`; ActionRow reflects null callback as noninteractive. Semantic activation invokes the callback once; decorative children must not duplicate the accessible label.

- [x] Extend tests for: null callback produces no haptic and no pressed scale; canceled gesture restores scale without invoking callback; two complete taps produce exactly two calls and two haptics; reduced-motion press retains scale 1; disabling during an active press clears feedback.
- [x] Add semantics assertions for one combined label, correct enabled/button state, and a single tap action on enabled controls. Verify disabled controls have no tap semantics. Use `tester.ensureSemantics()` and actual semantic actions where possible.
- [x] Add narrow-width/large-text widget tests using real `buildCissTheme` light and dark themes; long ActionRow trailing text must fit or truncate without overflow. Verify text/icon foreground against the chosen primary fill has at least 4.5:1 text contrast in both themes.
- [x] Run `flutter test test/de_clutter_primitives_test.dart`; observe failures before fixing.
- [x] Disable the gesture handlers and feedback when not actionable; honor reduced motion and clear pressed state when disabled. Apply correct semantic ownership. Constrain row trailing content. Use an on-primary foreground suitable for dark mode instead of hard-coded white; retain token-based shape/spacing and minimum sizes.
- [x] Rerun the primitive tests. Remove the unused haptic_event import if it remains unused after adding tests.

### Task 3: Finish Guard Home with preserved navigation and readable hierarchy

**Files:** `lib/features/guard/presentation/screens/guard_dashboard_screen.dart`, `lib/shared/widgets/modern_hero.dart` only as needed, `lib/dev/preview_harness.dart`, `test/guard_dashboard_redesign_test.dart` (new). Use `lib/shared/utils/initials.dart` instead of duplicating name parsing. Touch GuardShell only if required to expose/reuse navigation clearance, not to change tab order.

**Interfaces:** Keep `guardDashboardProvider` and `GuardDashboardScreen`; attendance remains GuardShell tab index 1. Use existing `guardTrainingProvider`, notification/sync providers and remote-config override patterns in tests. Do not introduce a new attendance-state guess or network dependency.

- [x] Write failing widget regressions with overridden providers and real CISS themes: exactly one PrimaryAction labeled `Mark attendance`; tapping it selects index 1 even with no next shift or arbitrary shift label containing `duty`; missing/blank shift data produces composed copy explaining attendance remains available.
- [x] Cover Home shortcut routing: Payslips, Leave, Patrol, Incidents obey their existing flags; `Training` opens `GuardTrainingScreen`; leaderboard remains reachable through the existing training surface. Existing Profile/Activity access to operational screens remains intact.
- [x] Add 360×800 and narrow 320-pixel layout checks with long name/district/site, large text, both themes, and a short/whitespace name. Last content must be scrollable fully clear of the floating nav. No RenderFlex overflow/uncaught exception is acceptable.
- [x] Add loading/error/retry and refresh coverage using a controlled provider future: loading shows layout placeholders (not a full-page spinner); refresh indicator stays active until refreshed data settles; short/empty lists still allow pull-to-refresh.
- [x] Run `flutter test test/guard_dashboard_redesign_test.dart` to expose the regressions.
- [x] Complete composition: hero → single attendance action → compact known-duty summary; a compact secondary section; month counts as labeled rows or a collapsed summary; recent activity below. Preserve present/absent/working values but remove equal three-column cards. Keep one truthful Mark attendance label because dashboard shift labels are not attendance session state.
- [x] Keep hero identity readable by constraining title/subtitle and separating or relocating trailing utilities when needed. Avoid globally reducing legibility of FO screens if ModernHero changes; cover its shared use in the visual check.
- [x] Restore adequate bottom clearance matching the existing floating-nav layout. Fix training target, module visibility, initials, and refresh awaiting. Retain sync, notifications, payslips and operational entries with correct labels.
- [x] Run new Home tests and existing module, training, attendance, auth and router regression tests.

### Task 4: Stabilize the started Duties surface using the existing dashboard contract

**Files:** `lib/core/models/mobile_dashboard_models.dart`, `lib/core/network/mobile_repository.dart`, `lib/features/guard/presentation/screens/guard_duties_screen.dart`, Home duty summary, `test/guard_duties_screen_test.dart` (new), existing repository/model regression test file as appropriate. Keep `duty_models.dart` and its existing tests as draft/internal types if useful; they must not drive unverified writes.

**Interfaces:** Add optional `bool nextShiftUnavailable = false` to `GuardDashboardSnapshot` and map the existing backend flag in `fetchGuardDashboard()`. Preserve all existing constructors. GuardDutiesScreen reads `guardDashboardProvider`, directly or through a derived provider with no separate network call. Its production content is the next known assigned work-order date/site/shift only.

- [x] Write failing model/repository tests that an existing dashboard payload with `nextShiftUnavailable: true` preserves that state, and old payloads default to false. Mock the existing `/api/guard/dashboard` response; do not invent a duties fixture endpoint.
- [x] Write failing widget tests for known next duty, no next duty, unavailable next duty, dashboard load failure, loading, and refresh/retry completion. Explicitly assert that no willingness buttons or success messages appear and attendance remains accessible from Home in every state.
- [x] Run the new Duties tests and relevant repository regressions before implementation.
- [x] Remove the unverified `fetchGuardDuties` and `respondDutyWillingness` repository methods from production. Replace screen fetching/responding logic with supported read-only data. Label the scope `Upcoming duty` / `Next scheduled duty`; do not claim that one dashboard record is all upcoming assignments or expose a fabricated count.
- [x] Show useful distinctions: known assignment details; no upcoming assignment with `You can mark attendance without an assigned duty`; or `Duty details are unavailable` with retry. A next-shift query failure is not an empty duty list. Empty/whitespace site strings are missing data.
- [x] Route Home's next-duty detail and its Upcoming duty row to this screen. Keep attendance as the independent primary action. Format valid ISO dates locally with existing date utilities and preserve a server display label when it is not parseable; show nonempty shift information without pretending it is check-in status.
- [x] Remove exam response controls from this production screen. Retain any useful future exam display work only in an unmistakably debug-only fixture, without a repository write method. Do not expose unavailable willingness controls or claim responses have been sent.
- [x] Test long duty details in both themes/large text. Run `flutter test test/guard_duties_screen_test.dart test/duty_models_test.dart` plus the dashboard/repository tests.

### Task 5: Safe preview, full regressions and independent Sol review

**Files:** `lib/dev/preview_harness.dart`, `lib/dev/mock_data.dart`, this plan and/or a concise verification record in `docs/superpowers/`.

- [x] Ensure debug preview fixtures cover Home and the supported Duties screen, including no assignment and load failure. Override data and dependent notification/sync/config providers so navigating these previews does not contact a real backend; no response controls or live mutation hooks in preview fixtures.
- [x] Run targeted new tests and then the full `flutter test` suite. Run `flutter analyze`; baseline reported three warnings (two pre-existing imports in auth/onboarding, one draft primitive-test import). No newly introduced analyzer finding may remain.
- [x] Run `dart format --output=none --set-exit-if-changed` on files edited during continuation; run `git diff --check` and inspect tracked/untracked changes. Do not format unrelated files or include generated Android build output.
- [x] Build/debug-launch a safe local preview if an emulator is available. Inspect light/dark Home and Duties, 320/360 widths, large text, scrolling past the floating nav, press/reduced motion and FO shared-header regression. An Android emulator is available through a persistent foreground session; use it if it stays healthy. If devices/build tooling are unavailable, rely on widget layout/semantics tests and recorded screenshots where possible; report absent device verification explicitly.
- [x] Have a separate GPT-6.1 Sol agent review the complete copied-worktree diff against this plan and existing behavior. Sol fixes actionable defects with regression coverage; rerun affected checks and repeat independent Sol review. Complete only when review finds no actionable issues and required automated checks pass.
- [x] Update progress/status to distinguish completed local work from blocked broader features. Final report states verification evidence, any baseline warnings/tooling limits, backend boundary, and isolated worktree path. No commits or publication.

## Backend Boundary and Deferred Spec Work

Read-only inspection confirms the sibling backend has `/api/guard/dashboard`, including a next assigned operational work order and a failure flag. It does not establish `/api/guard/duties`, a duty-willingness write route, `tcsCategory`, or the proposed new guardAssignments system. The existing next shift is enough for a useful read-only continuation; it is not enough for an entire assignment feed or willingness service.

The following broader requirements remain deferred and must not be called implemented: TCS enrollment defaults/backfill; permanent/adhoc eligibility; district-scoped duty feeds; willingness offline queuing and FO notifications; new shift assignment CRUD/push notifications; FO/admin willingness summaries; revised Guard tab taxonomy; app-wide FO screen redesign and RoleDesignProfile; native Android semantic haptic bridge and physical actuator/release-FPS validation. The spec explicitly leaves classification default and assignment decisions open. Those require a subsequent cross-repository contract/decision phase; this continuation makes no live or backend changes.

The earlier plans' commit steps and approval handoff are superseded by the user's no-commit rule and their instruction to continue already-started work using the specified model workflow.
