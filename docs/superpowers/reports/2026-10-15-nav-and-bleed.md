# Field officer system-bar bleed and bottom navigation — 15 October 2026

The physical-device screenshot showed the Employee Directory header painted under the Android status bar; the user reported the same for the dashboard loading screen and asked for Attendance and Employee Directory buttons in the bottom bar. Earlier work in this branch had already added the five-button bar (Home, Attendance, Employees, Duties, More with Reports inside More) and safe-area boundaries for the directory, dashboard and profile states. This pass closed the remaining bleed and layout defects found while auditing every field-officer surface.

- **Operations (work orders) still bled.** Its loading, error and data bodies were bare `Scaffold` bodies, so the `BrandBanner` header and list painted under the status bar and behind the floating nav bar whenever the screen was pushed standalone (More → Operations, or a work-order notification). All three states now sit inside a `SafeArea`.
- **Dashboard overflowed at large text.** `_AttendanceCoverage`'s header row overflowed by 150 px at 1.8 text scale, which clips silently in release builds. The title now flexes and wraps instead of pushing the percentage pill off screen.
- **Directory sat off its own grid.** The header and the Employees/Districts metric cards were indented 16 dp further than the search field, filter dropdowns and employee cards. Everything now shares one 16 dp margin, and the metric cards stretch across the row instead of leaving a third of it empty. The dead back-button placeholder was dropped so the header logo lines up with the other tabs; a pushed instance still gets a back button.
- **Attendance lists could hide their last row.** Live Feed and History now add the system bottom inset to their list padding so the floating nav bar plus gesture inset cannot cover the final muster row.

## Verification

- `flutter analyze`: no issues. Full `flutter test`: 387 tests pass.
- New regression cases: three operations inset cases (loading/error/data with top 48, bottom 24, side 8 insets at 411x914), one directory grid case (header logo, metric cards and search field on the same margin; metric row reaching the right edge). The operations loading case was confirmed to fail with the pre-fix layout (header top 0.0 instead of >= 48) before the fix was restored.
- Synthetic screenshots with realistic insets (top 44 / bottom 24, Inter font) at 411x914 @1.0 and 320x800 @1.8 were rendered from the real widgets and inspected: shell tabs Home, Attendance, Employees, Duties and More, operations loading/data, directory, and the guard dashboard. Every surface starts below the status bar, and the bottom bar no longer covers list content.

## Review and remaining uncertainty

No independent reviewer ran this pass: every sub-agent launch failed at the local proxy (GPT-6.1 Sol twice, GPT-6 Luna once) — two ended with "stream disconnected before completion" and one returned an unreadable-encrypted-agent-task error stating that the sub-agent task was encrypted by the main agent's provider and cannot be decrypted by the sub-agent's provider. The change was therefore self-reviewed against the final diff, the focused regression tests and the rendered screenshots.

`field_officer_work_orders_screen.dart` was normalized by `dart format` (Dart 3.7 tall style) during this pass, so its textual diff is large while the semantic delta versus HEAD stays ~192/24 lines; the file's other content is pre-existing WIP from earlier agents. Screenshots are synthetic widget renders: they do not draw the real Android status bar, so final confirmation on the phone still needs the user's device. The Attendance-tab probe cannot render its Firestore-backed live feed in a widget test, so that capture shows the surrounding layout only. No commit, push, merge or deployment was performed, and nothing was installed on the device.
