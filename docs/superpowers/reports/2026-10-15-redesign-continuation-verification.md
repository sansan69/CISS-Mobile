# CISS redesign continuation — local verification

15 October 2026. The approved local mobile/web continuation is implemented. No actionable findings remain in the completed scoped reviews. Changes are preserved in isolated, uncommitted worktrees; no deployment, migration, real-source backfill or live-data change was performed.

## Work locations

- Mobile: `/Users/mymac/.codex/worktrees/redesign-continuation/CISS-Mobile`, unchanged HEAD `edfec109fdde0cd8e0d23ad3a2a4c2ba0dd7b537`.
- Web/backend: `/Users/mymac/.codex/worktrees/redesign-continuation/CISS`, unchanged HEAD `cad17132c84ec361f5db5512fbe7a161b4a98483`.
- Detailed evidence ledger: mobile worktree `.superpowers/sdd/2026-10-13-tcs-duties-cross-repo-plan/`.

The original mobile and web checkouts retain their existing source and Git heads. SHA-256 comparisons cover 535 original mobile files and 1,415 original web files. The requested AGENTS.md workflow updates are intentionally excluded from the source-preservation comparison.

## Implemented

- Continued the navy/gold mobile foundation, motion, failure-safe haptics, accessible press/action primitives and personal Guard Home. Attendance remains independently available.
- Added TCS category defaults and admin curation: new TCS enrollment defaults to adhoc; forged permanent enrollment cannot elevate; legacy missing/invalid categories remain unclassified. Non-TCS records have no effective category.
- Implemented guard duties, district exam willingness/tallies and ordinary regular/relieving assignments across local backend, mobile and web. Willingness closes at midnight at the start of the duty date in Asia/Kolkata, does not reserve capacity, and does not gate attendance.
- Added owner/deployment-bound durable willingness persistence, stable request identities, concurrency/replay handling and visible pending/rejected outcomes even when a duty leaves the feed or the feed fails. Saved history cannot exhaust runnable queue capacity.
- Added scoped FO willingness/roster and assignment forms, per-guard outcomes, conflict refresh/reselection, and exact retry of uncertain web roster saves. Dialogs protect uncertain requests and selections during authoritative roster loading.
- Added durable inbox events and best-effort targeted push plumbing. Duty navigation respects biometric/onboarding admission, relock/logout/deployment revocation, nested roster dialogs, cold-start ownership, duplicate taps and intentional reopening. Pending events cannot migrate to another deployment or mark another deployment’s inbox read.
- Fixed large-text navigation, dashboard metrics/labels/tabs, primary actions, site/district dropdowns, hero copy and date-helper wrapping. Debug previews use explicit local fixtures and fail-closed service boundaries.
- Added the classification dry-run scaffold and source/provenance documentation. It produces proposals from synthetic/offline inputs and has no live apply path.

## Verification

| Check | Result |
| --- | --- |
| Full mobile Flutter suite after functional fixes | 356 passed |
| Mobile analysis after final style cleanup | No issues |
| Scoped formatting of changed/new Dart files | 81 files, zero remaining changes |
| Mobile debug APK and safe preview builds | Passed |
| Full web/backend suite on final functional web source | 690 passed, 28 opt-in skipped |
| Web typecheck and repository lint | Passed |
| Separate local Firestore rules emulator checks in prior backend verification | 28 passed: 19 duty + 9 category cases |
| Classification dry-run focused checks | 24 passed in its implementation/review round |
| Both worktrees’ whitespace checks | Passed |
| Original checkout source/head preservation | Verified |

The last changes after the 356-test/debug-build run were formatting and four equivalent brace-style fixes. The current analyzer/formatter checks pass; unchanged full suites were not repeatedly rerun for style-only edits. Later independent targeted review compiled and exercised the final source.

Web checks used Node 26.7.0; the declared Node 22 engine was not separately exercised. Opt-in skipped tests are not represented as passing. The local SDK’s missing host-test cache was restored before the October 15 mobile checks.

## Review closure

The evidence ledger retains findings and fixes instead of replacing historical reports:

- `category-sol-rereview.md`, `services-sol-round2-rereview.md`, and `dryrun-sol-rereview.md`: preceding category, backend/service and scaffold review closure.
- `web-sol-round2-rereview.md`: no actionable current web findings after account-bound batches, roster CAS/replay, IST dates, disabled-loading and manual-dialog lifecycle fixes. Mounted component checks covered dismissal, late/obsolete reads and conflict recovery.
- `mobile-sol-final-review.md` and `mobile-sol-round2-rereview.md`: reproduced remaining mobile gate/modal/notification/date issues; these are historical findings, not current open items.
- `mobile-sol-round3-rereview.md`: no actionable defects in the final two fixes. Five permanent regressions and 14 distinct additional temporary cases passed, including nested scheduling-conflict dialog revocation, retained callbacks, unresolved-owner cold starts, cross-origin isolation, duplicates and reopening. All 228 lib/test files were unchanged during that final review.
- `mobile-luna-round2-fix-report.md`, `mobile-luna-round3-fix-report.md`, and `final-style-cleanup-report.md`: implementation and check evidence.

The latest workflow is saved in both projects’ AGENTS.md files: Luna low/medium implementation by complexity, DeepSeek high default review, Sol medium for complex review, and disclosed pre-authorized Luna fallback if DeepSeek is unavailable. October 15 auth/notification reviews used separate GPT-6.1 Sol at medium effort. Earlier DeepSeek runs stopped with insufficient balance; historical records retain their original model details.

## Actual visual checks and restoration

The implementation models directly inspected the captured evidence; the coordinator did not substitute its own screenshot verdict.

- `visual-luna-recheck-report.md`: light/dark, 1.0×/1.8× checks of the navigation, Guard Home/hero, FO dashboard, editor/action/dropdown and unclassified fixture.
- `visual-result-luna-report.md`: pending and rejected outcome cards with missing-duty/failed-feed fixtures, readable reasons and actions at large text.
- `narrow-date-luna-visual-report.md`: actual 360×800 logical emulator captures in light/dark at 1.8× plus light 1.0× smoke; the complete date helper is visible.

Offline preview only. The original installed APK and shared preferences were restored byte-for-byte, accessibility/display settings restored, the original app left force-stopped, airplane mode retained with Wi-Fi off, and the owned emulator shut down. Screenshots, backups and cleanup evidence remain in the ignored ledger/artifact directories.

## Remaining boundaries and uncertainty

- Physical FCM delivery, true OS cold-start integration, physical haptics, release performance, iOS/device parity and live backend behavior were not verified.
- Local rules/indexes and application changes are undeployed. No real guard/category source was classified or imported; source authority and any later backfill still require separate authorization.
- Push is best effort. Inbox/replay polling retries pending delivery; a closed app after a server interruption has no guaranteed immediate retry scheduler.
- The previously documented legacy admin bulk-upsert cancellation-history gap and missing settings-provider endpoint remain outside this continuation. Explicit-false feature-flag behavior is verified with local fixtures; no new settings-provider route is claimed.
- Native Android CONFIRM/REJECT-specific mappings remain a later platform enhancement; current haptics use the supported Flutter mappings.
- Existing unrelated legacy screen/dropdown accessibility behavior was not redesigned. Local checks and scoped review do not constitute a guarantee of literal perfection.

The worktrees and evidence are retained for inspection. No commit, push, merge or publication was performed.
