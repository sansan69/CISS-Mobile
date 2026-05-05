# CISS Mobile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Flutter mobile app for guards and field officers that connects to the live CISS backend, supports separate login flows, and covers attendance, profile, incidents, training, payslips, leave, work orders, and reporting.

**Architecture:** Keep the Flutter app fully isolated from the web repo, but share the same backend services, Firebase project, and public API base URL. The web app remains the admin/client control plane, while Flutter becomes the mobile daily-operations client. Use role-based routing, env-driven config, and feature modules that map directly to the CISS webapp domains.

**Tech Stack:** Flutter, Riverpod, go_router, Firebase Auth, Firebase Core, dio, geolocator, image_picker, url_launcher, intl, JSON serializable models, local offline storage in a later phase.

---

## 1. Current repo contract

**Files:**
- Create: `/Users/mymac/Documents/CISS-Mobile/Memory.md`
- Create: `/Users/mymac/Documents/CISS-Mobile/mobile.env`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/firebase_options.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/core/brand.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/README.md`

- [ ] **Step 1: Keep the mobile repo isolated**

Document the split so the Flutter app remains outside the webapp folder and does not depend on the Next.js repository path structure.

```text
/Users/mymac/Documents/CISS-Mobile
```

- [ ] **Step 2: Keep only public config in the mobile repo**

Copy only values required to run the Flutter client:

```env
CISS_API_BASE_URL=https://cisskerala.site
CISS_COMPANY_NAME=CISS Workforce
CISS_COMPANY_TAGLINE=Security workforce management platform
CISS_COMPANY_SUPPORT_EMAIL=admin@cisskerala.app
CISS_COMPANY_PORTAL_URL=https://cisskerala.site
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
```

Do not copy server-only Firebase admin secrets into the Android app.

- [ ] **Step 3: Keep the mobile startup contract stable**

Use this run command for all mobile verification:

```bash
cd /Users/mymac/Documents/CISS-Mobile
flutter run --dart-define-from-file=mobile.env
```

---

## 2. App shell and branding

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/app/app.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/app/theme/app_theme.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/screen_scaffold.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/brand_banner.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/shared/widgets/company_contact_card.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/core/brand.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/assets/ciss-logo.png`

- [ ] **Step 1: Add branded tokens**

Define:

```dart
const String kCompanyName = String.fromEnvironment(
  'CISS_COMPANY_NAME',
  defaultValue: 'CISS Workforce',
);
const String kCompanyTagline = String.fromEnvironment(
  'CISS_COMPANY_TAGLINE',
  defaultValue: 'Security workforce management platform',
);
const String kCompanySupportEmail = String.fromEnvironment(
  'CISS_COMPANY_SUPPORT_EMAIL',
  defaultValue: 'admin@cisskerala.app',
);
const String kCompanyPortalUrl = String.fromEnvironment(
  'CISS_COMPANY_PORTAL_URL',
  defaultValue: 'https://cisskerala.site',
);
const String kCompanyLogoAsset = 'assets/ciss-logo.png';
```

- [ ] **Step 2: Refresh the design language**

Keep the app:
- clean
- mobile-first
- brand-forward
- Material 3
- calm blue/gold palette

Use the logo, company name, and support language in the mobile surfaces where it improves trust:
- login hub
- role login pages
- guard dashboard
- field officer dashboard
- support/help surfaces

- [ ] **Step 3: Keep page chrome consistent**

Update the reusable app shell so every major mobile page has:
- logo
- company name
- page title
- optional subtitle

---

## 3. Auth and role separation

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/login_hub_screen.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/role_login_screen.dart`
- Create: `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/presentation/auth_gate_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/app/router/app_router.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/auth/application/auth_controller.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/core/network/mobile_repository.dart`

- [ ] **Step 1: Keep three role entry points**

Routes:

```text
/login
/login/guard
/login/field-officer
```

Behavior:
- `/login` shows role selection
- guard login accepts employee ID or phone + PIN
- field officer login accepts email + password

- [ ] **Step 2: Enforce role checks after login**

Guard login must only complete if Firebase claims identify a guard account.
Field officer login must only complete if Firebase claims identify a field officer account.

If the selected portal does not match the user role, sign out and show a clear error.

- [ ] **Step 3: Keep auth state routing simple**

After login:
- guard -> guard shell
- field officer -> field officer shell
- unauthenticated -> login hub

- [ ] **Step 4: Keep the auth model shared**

Use one Firebase auth backend, not two separate auth systems.

---

## 4. Guard app modules

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/guard_shell.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_dashboard_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_attendance_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_profile_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_training_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_payslips_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_leave_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_evaluations_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/guard/presentation/screens/guard_incidents_screen.dart`

- [ ] **Step 1: Build the guard home dashboard**

Show:
- next shift
- attendance summary
- client/site
- leave balance
- evaluation score
- recent attendance
- support/contact card

- [ ] **Step 2: Build guard attendance**

Attendance flow:
- detect location
- show site/duty-point/shift context
- capture photo
- capture QR or other site proof when required
- submit attendance
- show history and current status

Future-ready requirements:
- offline draft
- retry on connectivity failure
- device location warning when location services are off

- [ ] **Step 3: Build guard profile**

Show:
- employee identity
- client assignment
- site assignment
- duty point assignment
- contact details
- documents
- QR profile card

- [ ] **Step 4: Build guard training**

Show:
- assigned modules
- viewing progress
- quiz/evaluation access
- acknowledgements

- [ ] **Step 5: Build guard payslips**

Show:
- monthly slips
- gross
- deductions
- net pay
- downloadable document

- [ ] **Step 6: Build guard leave**

Show:
- balances
- request form
- request history
- status tracking

- [ ] **Step 7: Build guard evaluations**

Show:
- scores
- assessment history
- pass/fail status
- notes

- [ ] **Step 8: Build guard incidents**

Show:
- incident create form
- photo upload
- location
- severity
- category
- history and status

---

## 5. Field officer app modules

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/field_officer_shell.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/screens/field_officer_work_orders_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/screens/field_officer_guards_screen.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/lib/features/field_officer/presentation/screens/field_officer_reports_screen.dart`

- [ ] **Step 1: Build the field officer dashboard**

Show:
- assigned districts
- assigned sites
- pending visit reports
- pending training reports
- active work orders
- guard summary

- [ ] **Step 2: Build field officer work orders**

Show:
- date grouped rows
- center/site
- exam duty names
- manpower counts
- assignment status
- detail view

Keep TCS work orders separate from non-TCS operational sites in the backend model.

- [ ] **Step 3: Build guard directory for field officers**

Show:
- guards under assigned districts/sites
- profile details
- attendance status
- quick lookup

- [ ] **Step 4: Build visit reports**

Show:
- visit report list
- new report form
- site selection
- guards present/absent
- observations
- action items
- photo attachments

- [ ] **Step 5: Build training reports**

Show:
- training session list
- new report form
- attendees
- topic
- duration
- evidence upload

---

## 6. Shared domain models

**Files:**
- Create or modify:
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/app_role.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/auth_session.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/guard_profile.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/attendance_models.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/training_models.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/payroll_models.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/report_models.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/incident_models.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/leave_models.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/models/mobile_dashboard_models.dart`

- [ ] **Step 1: Freeze the mobile contract**

Keep the mobile models aligned with the webapp concepts:
- employee
- site
- duty point
- shift
- attendance record
- leave request
- report
- incident
- payroll entry
- training module
- evaluation

- [ ] **Step 2: Keep JSON serialization explicit**

Every model should have a clear JSON contract so it can consume the web backend safely.

- [ ] **Step 3: Keep role-specific fields separate**

Guard-only and field-officer-only fields must not be mixed into one ambiguous shape.

---

## 7. Mobile API layer

**Files:**
- Create or modify:
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/network/api_config.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/network/api_client.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/network/providers.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/network/mobile_repository.dart`

- [ ] **Step 1: Keep the API base URL env-driven**

Use:

```dart
static const String baseUrl = String.fromEnvironment(
  'CISS_API_BASE_URL',
  defaultValue: 'https://cisskerala.site',
);
```

- [ ] **Step 2: Keep auth headers centralized**

Every secured request should use the Firebase ID token from the current user.

- [ ] **Step 3: Keep backend calls grouped by feature**

Add repository methods for:
- guard dashboard
- guard profile
- guard attendance
- guard incidents
- guard training
- guard payslips
- guard leave
- field officer dashboard
- field officer work orders
- field officer guards
- field officer visit reports
- field officer training reports

- [ ] **Step 4: Keep public endpoints separate**

Use unauthenticated public endpoints only for:
- initial employee lookup
- guard QR login bootstrap where required
- public attendance precheck

---

## 8. Firestore and storage contracts

**Files:**
- Align the mobile client with the existing backend collections and document shapes.

- [ ] **Step 1: Keep the main role mappings**

Use the same live backend collections already used by the web app.

Expected Firebase scopes:
- `employees`
- `attendanceLogs`
- `attendanceState`
- `sites`
- `clients`
- `clientUsers`
- `workOrders`
- `fieldOfficerReports`
- `trainingReports`
- `trainingModules`
- `trainingAssignments`
- `incidentReports`
- `leaveRequests`
- `payrollCycles`
- `payrollEntries`

- [ ] **Step 2: Preserve storage paths**

The mobile app must read and upload files to the same Firebase Storage buckets used by the web app for:
- profile photos
- signatures
- identity documents
- attendance photos
- incident photos
- training evidence
- report attachments

- [ ] **Step 3: Keep access control server-led**

Do not let mobile code bypass server-side checks for:
- guard attendance
- assignment validation
- report ownership
- client scoping
- portal login role checks

---

## 9. Offline, sync, and field reliability

**Files:**
- Create later:
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/offline/`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/sync/`

- [ ] **Step 1: Add offline draft save**

Support draft save for:
- attendance
- visit reports
- training reports
- incident reports

- [ ] **Step 2: Add retry queue**

Queue failed writes and retry when network returns.

- [ ] **Step 3: Add sync status UI**

Show:
- pending
- syncing
- synced
- failed

- [ ] **Step 4: Keep conflict handling explicit**

If a record already exists server-side, show the user the conflict rather than silently overwriting.

---

## 10. Notifications and device features

**Files:**
- Later create or modify:
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/fcm/`
  - `/Users/mymac/Documents/CISS-Mobile/lib/hooks/use_haptics.dart`
  - `/Users/mymac/Documents/CISS-Mobile/lib/core/location/`

- [ ] **Step 1: Add push notifications**

Use FCM for:
- attendance prompts
- assignment updates
- report acknowledgements
- incident escalation

- [ ] **Step 2: Add location checks**

Attendance should warn the user when GPS/location services are off.

- [ ] **Step 3: Add optional QR and camera support**

Use the camera for:
- QR scanning
- photo proof
- report attachments

---

## 11. QA and release

**Files:**
- Modify: `/Users/mymac/Documents/CISS-Mobile/test/widget_test.dart`
- Modify: `/Users/mymac/Documents/CISS-Mobile/README.md`

- [ ] **Step 1: Add widget coverage**

Keep tests for:
- login hub
- guard login screen
- field officer login screen
- branded shell rendering

- [ ] **Step 2: Run static checks**

Run:

```bash
flutter analyze
flutter test
```

Expected:
- no analyzer issues
- tests pass

- [ ] **Step 3: Run live mobile verification**

Verify on device or emulator:
- guard login
- field officer login
- attendance flow
- dashboard rendering
- company branding
- contact links

- [ ] **Step 4: Package for release**

Prepare Android build using the standalone mobile repo only.

---

## 12. Delivery order

Implement in this order:

1. App shell and auth separation
2. Guard dashboard and attendance
3. Guard profile, training, payslips, leave, incidents
4. Field officer dashboard and work orders
5. Field officer guards and reports
6. Offline queue and sync
7. Notifications and location safety
8. Release QA and packaging

---

## Self-check

- Every phase has a clear file set.
- Guard and field officer flows are separate.
- The mobile repo stays isolated from the web repo.
- Public config is copied; admin secrets are not.
- The plan matches the current app direction and the live backend contract.
