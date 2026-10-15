# CISS-AMS parity + hardening plan — 15 October 2026

Source of the comparison: REA analysis of `CISS-AMS_5.0.4_APKPure.xapk` (see `docs/superpowers/reports/2026-10-15-ciss-ams-rea-analysis.md`) plus the earlier industry-gap report. Everything below is client-side and verifiable in this repo; nothing needs a backend contract change or a store publish.

## Scope (each item fully implemented and tested)

1. **Localization foundation (en / hi / ml)** — mirrors AMS `locale/language_{en,hi,ar,fr}.dart` + `language_screen.dart`. Adds a language scope with English fallback, a persisted language controller, a Language screen in More, and localized bottom-navigation labels for both portals.
2. **Tracking health + permissions** — mirrors AMS `service/permission_service.dart` and `disable_battery_optimization`. Adds `ACCESS_BACKGROUND_LOCATION` and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, a Tracking health card in More that reports background-location, battery-exemption and notification state with one-tap fixes.
3. **Cached network images** — mirrors AMS `cached_network_image`. Replaces raw `NetworkImage` avatars/photos so roster scrolling does not re-download.
4. **Unread badge on the bottom navigation** — mirrors AMS `badges`; surfaces the existing notification unread count on the portal that owns the inbox.
5. **PDF muster-roll export** — mirrors AMS `api/pdf_api.dart`; keeps the existing text share and adds a real PDF built from the on-screen attendance summary.
6. **Release hardening** — R8/minify + resource shrinking + obfuscation with split debug info, and `targetSdk 36` to match AMS and current Play policy.

## Explicitly out of this pass (documented, not silently dropped)

Play Integrity/RASP, screen-capture protection, dynamic form/checklist engine, in-app chat, server-side pagination (needs a backend cursor contract), attendance regularization workflow (needs a backend endpoint), Play/Shorebird distribution.

## Verification gate

`flutter analyze` clean, full `flutter test` suite green including new tests for items 1–5, plus a release APK build proving the hardened Gradle configuration.
