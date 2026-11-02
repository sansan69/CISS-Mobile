# CISS-Mobile audit & remediation — 2026-10-22

This directory is the evidence base and deliverable set for a complete audit of the CISS-Mobile Flutter app at branch `wip/redesign-1.0.21` (HEAD `edfec10`, plus uncommitted redesign work), version `1.0.22+22`.

## Read this first

- **[`CISS-Mobile-audit-2026-10-22.md`](CISS-Mobile-audit-2026-10-22.md)** — the consolidated report: executive summary, architecture/feature inventory, 34 findings with severity/evidence/remediation/verification, threat model, P0→P3 roadmap, verification results, and open backend questions.
- **[`findings.csv`](findings.csv)** — machine-readable finding index (ID, severity, area, title, confidence, key evidence).
- **[`remediation-2026-10-22.md`](remediation-2026-10-22.md)** — what was fixed, verification evidence, migration notes, and the remaining backend/legal/Xcode/architecture work.

## Severity summary

| Severity | Count | IDs |
|---|---:|---|
| High | 5 | F-01, F-02, F-03, F-13, F-14 |
| High (conditional) | 2 | F-04 (backend throttling), F-15 (if iOS is a target) |
| Medium | 18 | F-05…F-08, F-16…F-18, F-22…F-32 |
| Low | 6 | F-09…F-11, F-19, F-20, F-33 |
| Info | 3 | F-12, F-21, F-34 |

**Overall risk after remediation: Medium. All client-side code-level High findings (F-01, F-02, F-03, F-13) are closed, and the coupled Medium/Low items F-05 and F-09 are fixed. F-04 needs backend confirmation, F-14 needs a tagged release, and F-15 needs Xcode signing. See the remediation report for the current status of every finding.**

## Area reports (raw specialist output)

These are the detailed, per-area audits used to build the consolidated report. They retain their own IDs and severities; the consolidated report reconciles duplicates and adjusts two severities with an explicit note (AQ-01 → F-27 Medium; AQ-02/ADP-01 → F-01 High).

| File | Scope | Findings |
|---|---|---|
| [`areas/platform-and-release.md`](areas/platform-and-release.md) | Android/iOS config, signing, updater, CI, dependencies, build verification | 13 (3 High / 6 Medium / 3 Low / 1 Info) |
| [`areas/auth-data-privacy.md`](areas/auth-data-privacy.md) | Auth/session, biometrics, storage, cache/queue, location privacy, API trust | 12 (3 High / 5 Medium / 2 Low / 2 Info) |
| [`areas/architecture-quality.md`](areas/architecture-quality.md) | Layering, Riverpod, routing, resilience, UI/a11y, performance, coverage | 16 (1 Critical / 4 High / 10 Medium / 1 Low) |

## Evidence

| File | What it is |
|---|---|
| [`evidence/launch2.png`](evidence/launch2.png) | Release APK on a clean API 36 emulator: notification permission prompt appears before login |
| [`evidence/launch3.png`](evidence/launch3.png) | Region selector (Kerala) |
| [`evidence/login_hub.png`](evidence/login_hub.png) | Login hub (Guard / Field Officer) |

## Verification at a glance

- `dart analyze`: 0 errors, 3 warnings (exit 0)
- `flutter analyze` (CI gate): **exit 1** on the same 3 warnings
- `flutter test`: **167/167 pass**
- Coverage: **15.3%** (2,742 / 17,911 coverable lines)
- `flutter build apk --release`: success, 86.7 MB, valid v2 signature
- `flutter build appbundle --release`: success, 45.3 MB
- `targetSdk 34` / `minSdk 24` / `versionCode 22`
- Dependencies: 204 locked, **0 OSV advisories**, 35 outdated
- Runtime: clean launch → notification prompt → region select → login hub; no authenticated flows tested (no credentials)

## Reproduce

See §10 and Appendix B of the consolidated report for the exact commands. Nothing in this directory changes product code or configuration; the audit was read-only apart from creating these files and `coverage/` (git-ignored).

## Limitations

No backend/Firestore rules, no Play Console, no authenticated test accounts, no iOS toolchain (Xcode/CocoaPods absent), no instrumentation, no interception proxy, and no load testing. Findings that depend on server behaviour are marked **server-side assumption** in the reports and listed as open questions in §11 of the consolidated report.
