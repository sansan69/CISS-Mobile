# Field officer system inset repair

The physical Pixel screenshot exposed a gap in prior visual coverage: directory screenshots used zero system insets. Employee Directory loading/error/data, dashboard loading/error, and employee profile used bare Scaffold bodies and could paint under system bars. The loaded dashboard already handled safe insets.

Added local SafeArea boundaries to the missing states and profile. Kept loaded dashboard's existing boundary and all directory/filter/attendance behaviour. No backend changes or business data writes.

Regression tests set both platform padding and viewPadding with nonzero top/bottom/side insets. Before source fixes, five directory/dashboard cases and the profile case failed; loaded dashboard passed. After fixes, all seven pass. Full suite: 375 tests pass. Flutter analyzer: no issues. Debug APK built successfully.

Luna medium reviewed the focused source/test diff and synthetic Inter-font directory data/loading and dashboard loading images, finding no actionable defects. Used the authorized fallback because the DeepSeek image service returned configuration error 400 and its preceding code re-review had failed to finish reliably. Synthetic images do not include actual Android system UI; no claim of live-device visual verification. Device installation result is recorded separately in the ledger.

Evidence and exact source snapshots: `.superpowers/sdd/2026-10-15-system-insets/`. No commit, push, merge, deployment or live business data changes.
