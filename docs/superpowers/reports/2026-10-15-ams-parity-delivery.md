# CISS-AMS parity delivery — 15 October 2026

Plan: `docs/superpowers/plans/2026-10-15-ciss-ams-parity-and-hardening.md`. Analysis behind it: `docs/superpowers/reports/2026-10-15-ciss-ams-rea-analysis.md` (REA Evidence in `.superpowers/sdd/2026-10-15-ciss-ams-rea/`).

## Delivered (all six planned items)

1. **Localization foundation** — `lib/core/i18n/app_language.dart` (enum + Hive-persisted controller), `lib/core/i18n/app_strings.dart` (en/hi/ml maps, English fallback when no scope is present), `lib/features/shared/language_screen.dart`, a Language entry in More and in the guard Profile hub, and localized bottom-navigation labels for both portals. `main.dart` initialises the language box in an isolated try/catch; `app.dart` publishes the strings through `AppStringsScope`.
2. **Tracking health** — `lib/core/location/tracking_health.dart` (provider-backed source, permissions read only on demand, bounded repairs) and `lib/features/shared/tracking_health_card.dart`: Location access, Battery unrestricted, Notifications allowed, Tracking service, each with status and a Fix action. The battery Fix opens the system page instead of requesting the Play-restricted exemption grant, and the manifest deliberately still omits `ACCESS_BACKGROUND_LOCATION` / `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` because `test/mobile_contract_regression_test.dart` encodes the visible-foreground-service decision.
3. **Cached images** — `cached_network_image` added; all six remote-image sites (directory rows, both profiles, attendance photos, work-order assign panel, guard profile) now use `CachedNetworkImageProvider`.
4. **Unread badge** — both shells surface the notification unread count on the tab that owns the inbox (More for field officers, Profile for guards).
5. **PDF muster roll** — `lib/features/field_officer/presentation/pdf/muster_roll_pdf.dart` builds a printable A4 report (summary, site deployment, attendance records, generated timestamp); the attendance app bar now offers "Share summary" and "Share as PDF", the latter written to a temp file and shared as `application/pdf`.
6. **Release hardening** — R8 (`isMinifyEnabled`), resource shrinking, `proguard-rules.pro` keep rules, `targetSdk 36`, and `--obfuscate --split-debug-info=build/symbols` in the CI APK workflow.

Also fixed this pass: the dashboard "Attendance Coverage" header overflow at large text, and the operations/work-orders system-bar bleed (carried over from the earlier report).

## Verification

- `flutter analyze`: no issues (whole project).
- `flutter test`: **392 tests pass**, including five new ones in `test/ciss_ams_parity_test.dart` (nav localization, language persistence, tracking-health report and repair, unread badge, PDF growth) and the pre-existing contract/security suites.
- `flutter build apk --debug`: succeeds, so the modified Gradle configuration and new dependencies resolve. `flutter build apk --release` cannot run here: `android/app/build.gradle.kts` requires the production keystore via `android/key.properties`, which is git-ignored and only present in CI. R8's first real run therefore happens in the "Build signed Android release" workflow; extend `proguard-rules.pro` there if a plugin is stripped.
- REA: four CLI operations on the XAPK produced Evidence (Flutter build identification, Dart AOT snapshot/string pool, artifact inventory, decoded Android resources). The Dart AOT string pool is what identified the `fieldmanager_hrms_flutter` module map.

## Incident during the pass (disclosed)

While testing whether an unrelated pre-existing `sol_final_auth_edges_test.dart` failure was caused by my changes, a `git stash pop` of an *old, unrelated* stash (`stash@{0}: WIP on main: ea81c8a`) partially applied before aborting. Recovery: the stray files it introduced (`lib/features/admin/`, `field_officer_activity_screen.dart`, `adaptive_dropdown.dart`) were moved to `/tmp/ciss-stash-quarantine/` (recoverable), and the tracked files it overwrote (`Memory.md`, `ios/Runner/Info.plist`, `android/app/src/debug/AndroidManifest.xml`, `app_role.dart`, `ciss_error.dart`, three auth screens, `test/app_role_test.dart`, `test/attendance_flow_verification_test.dart`) were restored from HEAD. `adaptive_dropdown.dart` turned out to be legitimate redesign work and was restored to its original path. The stash entry itself is untouched, and the final analyzer + 392-test run confirms the tree is consistent.

## Open items (unchanged from the earlier gap report)

Play Integrity/RASP attestation, screen-capture protection, dynamic forms, server-side pagination, attendance regularization, and Play/Shorebird distribution.
