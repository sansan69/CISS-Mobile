# CISS Mobile

Standalone Flutter app for guard and field officer operations.

## What this repo contains

- Guard login, attendance, profile, training, payslips, leave, evaluations, and incidents
- Field officer dashboard, work orders, guards, and reports
- Firebase client configuration wired from this repo only
- API base URL pointing to the live CISS backend

## Local run

```bash
flutter pub get
flutter run --dart-define-from-file=mobile.env
```

## Backend wiring

This app uses the same live CISS backend as the web app:

- API base: `https://cisskerala.site`
- Firebase project: `ciss-workforce`

The runtime config is stored in `mobile.env` so the mobile codebase stays isolated from the web app while still sharing the same backend values.

## Notes

- Public Firebase client values are stored in `mobile.env`.
- Admin SDK credentials stay in the web/backend repo only.
- The mobile app defaults to the same Firebase project if `mobile.env` is not supplied, but the file should be used for normal runs.
