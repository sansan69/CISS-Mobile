# Recorded attendance only — 15 October 2026

User requirement: attendance comes only from actual check-ins/check-outs. Work orders and guard assignments are separate TCS adhoc planning and cannot create attendance/absence records or restrict recording.

## Changes
- Shared backend field-officer aggregator reads attendanceLogs only. Removed work-order queries and generated absent rows; accepts usable IN/OUT timestamps, retaining session grouping, date/district authorization and evidence.
- Mobile repository filters both field-officer daily/range results to actual punches, protecting guard-level attendance logs as well as main live/history views against older server responses.
- History shows session date and labeled check-in/check-out times; summary counts actual punches. OUT-only sessions remain visible. Sharing counts actual punch state.
- Responsive history summary/cards tested at 320dp and 1.8 text scale; fixed overflows discovered by widget regression.

## Verification
- Backend full suite: 695 passed, 28 opt-in skipped. Typecheck and focused ESLint pass.
- Mobile full suite: 360 passed. Full analyzer clean. Debug APK builds.
- New backend recorded-only tests failed before work-order dependency was removed. Model and real-Dio repository regressions failed before filtering; rendered widget test fails against old screen because phantom absent record appears, then passes against corrected screen. Large-text rendering failures reproduced and corrected.
- Initial DeepSeek high review found missing widget coverage and an adjacent direct-repository caller; both addressed. Targeted final review: no actionable findings, using GPT-6 Luna medium after DeepSeek failed to complete the bounded re-review. The original DeepSeek event/tool log is preserved.

## Delivery boundary
Backend source is local and undeployed. Approval given earlier applied only to the missing Firestore index, which is already READY. No attendance data writes or TCS planning/payroll changes. Final reviewed debug APK installed successfully on the connected Pixel 9 using replace mode (app data retained). User will perform final live-screen check; automated rendering uses synthetic fixtures, without reading private attendance records. Source changes remain uncommitted.
