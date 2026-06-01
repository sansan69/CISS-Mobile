# Graph Report - CISS-Mobile  (2026-05-06)

## Corpus Check
- 118 files · ~114,685 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 937 nodes · 1230 edges · 39 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 49 edges
2. `package:flutter_riverpod/flutter_riverpod.dart` - 41 edges
3. `../../app/theme/app_tokens.dart` - 36 edges
4. `../../../../../core/network/providers.dart` - 15 edges
5. `../../../../shared/widgets/state_block.dart` - 14 edges
6. `../../../../shared/widgets/status_chip.dart` - 14 edges
7. `package:google_fonts/google_fonts.dart` - 12 edges
8. `../../../../../shared/widgets/screen_scaffold.dart` - 11 edges
9. `../../../../core/network/ciss_error.dart` - 10 edges
10. `package:dio/dio.dart` - 9 edges

## Surprising Connections (you probably didn't know these)
- `my_application_dispose()` --calls--> `dispose`  [INFERRED]
  linux/runner/my_application.cc → lib/shared/widgets/camera_capture_screen.dart
- `OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/flutter/generated_plugin_registrant.cc
- `OnCreate()` --calls--> `Show()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/runner/win32_window.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `wWinMain()` --calls--> `SetQuitOnClose()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/win32_window.cpp

## Communities

### Community 0 - "Community 0"
Cohesion: 0.03
Nodes (93): ../../../core/auth/saved_accounts_service.dart, ../../../../../core/cache/skeleton_widgets.dart, ../../../core/models/auth_session.dart, ../../../core/models/guard_pin_status.dart, ../../../../../core/models/guard_profile.dart, ../../../../../core/models/leave_models.dart, ../../../../../core/models/payroll_models.dart, ../../../../../core/models/training_models.dart (+85 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (73): ../../app/router/app_router.dart, dart:async, dart:convert, ../../features/auth/application/auth_controller.dart, ../../features/field_officer/field_officer_tab_provider.dart, ../../features/guard/guard_tab_provider.dart, ../models/app_role.dart, ../network/mobile_repository.dart (+65 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (73): ../../app/theme/app_tokens.dart, ../../core/brand.dart, dart:ui, package:flutter/material.dart, package:url_launcher/url_launcher.dart, portal_primitives.dart, BouncingScrollPhysics, CissScrollBehavior (+65 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (67): api_config.dart, ../../../../../core/models/attendance_models.dart, ../../../../../core/models/incident_models.dart, ../../../core/qr/qr_parser.dart, ../../core/sync/providers.dart, ../../../core/utils/date_format.dart, dart:io, guard_attendance_screen.dart (+59 more)

### Community 4 - "Community 4"
Cohesion: 0.03
Nodes (59): app/app.dart, ../../app/theme/theme_mode_controller.dart, ../application/auth_controller.dart, ../../core/auth/biometric_service.dart, core/fcm/providers.dart, ../../../../../core/location/background_tracking_service.dart, ../../../core/models/app_role.dart, ../../../../../core/offline/draft_service.dart (+51 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (55): ../../../core/cache/preload_controller.dart, ../../../../../core/fcm/notification_service.dart, ../../field_officer_tab_provider.dart, package:intl/intl.dart, screens/field_officer_attendance_screen.dart, screens/field_officer_dashboard_screen.dart, screens/field_officer_guards_screen.dart, screens/field_officer_reports_screen.dart (+47 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (55): ../../../../../core/models/mobile_dashboard_models.dart, field_officer_dashboard_screen.dart, field_officer_guard_detail_screen.dart, ../../../../shared/widgets/portal_primitives.dart, ../../../../../shared/widgets/sync_status_badge.dart, build, _clearDate, Column (+47 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (46): dart:typed_data, field_officer_work_orders_screen.dart, package:image_picker/image_picker.dart, _AddPhotoButton, build, _buildPhotoSection, _buildTrainingForm, _buildVisitForm (+38 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (41): app_tokens.dart, ../../../../../core/location/live_location_service.dart, dart:math, package:flutter_map/flutter_map.dart, package:google_fonts/google_fonts.dart, package:latlong2/latlong.dart, buildCissTheme, IconThemeData (+33 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (38): ../../auth/application/auth_controller.dart, ../../../../../core/haptics.dart, ../../../../core/network/ciss_error.dart, ../../features/attendance_qr/qr_attendance_flow.dart, ../../features/auth/presentation/auth_gate_screen.dart, ../../features/auth/presentation/guard_pin_setup_screen.dart, ../../features/auth/presentation/login_hub_screen.dart, ../../features/auth/presentation/permission_onboarding_screen.dart (+30 more)

### Community 10 - "Community 10"
Cohesion: 0.06
Nodes (34): api_client.dart, mobile_repository.dart, ../models/attendance_models.dart, ../models/auth_session.dart, ../models/guard_pin_status.dart, ../models/guard_profile.dart, ../models/incident_models.dart, ../models/leave_models.dart (+26 more)

### Community 11 - "Community 11"
Cohesion: 0.06
Nodes (35): ../../../../../core/models/report_models.dart, _AssignGuardsSheet, _AssignGuardsSheetState, build, _buildSiteRow, DateFormat, _DateGroupedOrders, _dateHeaderLabel (+27 more)

### Community 12 - "Community 12"
Cohesion: 0.09
Nodes (25): RegisterPlugins(), FlutterWindow(), OnCreate(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 13 - "Community 13"
Cohesion: 0.07
Nodes (18): fl_register_plugins(), package:camera/camera.dart, main(), my_application_activate(), my_application_dispose(), my_application_new(), build, CameraCaptureScreen (+10 more)

### Community 14 - "Community 14"
Cohesion: 0.11
Nodes (23): ../../features/field_officer/presentation/screens/field_officer_attendance_screen.dart, ../../features/field_officer/presentation/screens/field_officer_dashboard_screen.dart, ../../features/field_officer/presentation/screens/field_officer_guards_screen.dart, ../../features/field_officer/presentation/screens/field_officer_reports_screen.dart, ../../features/field_officer/presentation/screens/field_officer_work_orders_screen.dart, ../../features/guard/presentation/screens/guard_attendance_screen.dart, ../../features/guard/presentation/screens/guard_dashboard_screen.dart, ../../features/guard/presentation/screens/guard_evaluations_screen.dart (+15 more)

### Community 15 - "Community 15"
Cohesion: 0.14
Nodes (11): package:ciss_mobile/core/models/app_role.dart, package:ciss_mobile/core/models/attendance_models.dart, package:ciss_mobile/features/auth/presentation/guard_pin_setup_screen.dart, package:ciss_mobile/features/auth/presentation/login_hub_screen.dart, package:ciss_mobile/features/auth/presentation/role_login_screen.dart, package:flutter_test/flutter_test.dart, main, main (+3 more)

### Community 16 - "Community 16"
Cohesion: 0.17
Nodes (11): attendance_models.dart, leave_models.dart, report_models.dart, FieldOfficerAttendanceEntry, FieldOfficerAttendanceSite, FieldOfficerAttendanceSummary, FieldOfficerDashboardSnapshot, FieldOfficerDistrictAttendance (+3 more)

### Community 17 - "Community 17"
Cohesion: 0.29
Nodes (2): FlutterAppDelegate, AppDelegate

### Community 18 - "Community 18"
Cohesion: 0.29
Nodes (6): AttendanceHintModel, AttendanceRecordModel, DutyPointModel, PublicAttendanceEmployeeModel, ShiftTemplateModel, SiteOptionModel

### Community 19 - "Community 19"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), NSWindow, MainFlutterWindow

### Community 20 - "Community 20"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 21 - "Community 21"
Cohesion: 0.4
Nodes (4): FieldOfficerSiteOption, TrainingReportModel, VisitReportModel, WorkOrderModel

### Community 22 - "Community 22"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 23 - "Community 23"
Cohesion: 0.67
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 24 - "Community 24"
Cohesion: 0.67
Nodes (1): GeneratedPluginRegistrant

### Community 25 - "Community 25"
Cohesion: 0.67
Nodes (1): MainActivity

### Community 26 - "Community 26"
Cohesion: 0.67
Nodes (1): CissMobileApplication

### Community 27 - "Community 27"
Cohesion: 0.67
Nodes (2): app_role.dart, AuthSession

### Community 28 - "Community 28"
Cohesion: 0.67
Nodes (2): EvaluationModel, TrainingAssignmentModel

### Community 29 - "Community 29"
Cohesion: 0.67
Nodes (2): LeaveBalanceModel, LeaveRequestModel

### Community 30 - "Community 30"
Cohesion: 0.67
Nodes (2): _normalizeQrText, parseEmployeeQrText

### Community 31 - "Community 31"
Cohesion: 0.67
Nodes (2): copyWith, OfflineRequest

### Community 32 - "Community 32"
Cohesion: 0.67
Nodes (3): CISS Mobile (Flutter), Field Officer Mobile Flow, Guard Mobile Flow

### Community 33 - "Community 33"
Cohesion: 1.0
Nodes (1): ApiConfig

### Community 34 - "Community 34"
Cohesion: 1.0
Nodes (1): formatAttendanceDateTime

### Community 35 - "Community 35"
Cohesion: 1.0
Nodes (1): PayslipSummaryModel

### Community 36 - "Community 36"
Cohesion: 1.0
Nodes (1): GuardPinStatus

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (1): IncidentModel

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (1): GuardProfileModel

## Knowledge Gaps
- **678 isolated node(s):** `main`, `ProviderScope`, `package:ciss_mobile/features/auth/presentation/login_hub_screen.dart`, `package:ciss_mobile/features/auth/presentation/guard_pin_setup_screen.dart`, `package:ciss_mobile/features/auth/presentation/role_login_screen.dart` (+673 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 17`** (7 nodes): `FlutterAppDelegate`, `AppDelegate.swift`, `AppDelegate.swift`, `AppDelegate`, `.application()`, `.applicationShouldTerminateAfterLastWindowClosed()`, `.applicationSupportsSecureRestorableState()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 20`** (5 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 22`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 23`** (3 nodes): `GeneratedPluginRegistrant.m`, `GeneratedPluginRegistrant`, `-registerWithRegistry`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (3 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (3 nodes): `MainActivity.kt`, `MainActivity`, `.onCreate()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 26`** (3 nodes): `CissMobileApplication.kt`, `CissMobileApplication`, `.onCreate()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 27`** (3 nodes): `app_role.dart`, `auth_session.dart`, `AuthSession`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 28`** (3 nodes): `training_models.dart`, `EvaluationModel`, `TrainingAssignmentModel`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (3 nodes): `leave_models.dart`, `LeaveBalanceModel`, `LeaveRequestModel`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 30`** (3 nodes): `qr_parser.dart`, `_normalizeQrText`, `parseEmployeeQrText`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (3 nodes): `offline_request.dart`, `copyWith`, `OfflineRequest`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (2 nodes): `api_config.dart`, `ApiConfig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (2 nodes): `date_format.dart`, `formatAttendanceDateTime`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 35`** (2 nodes): `payroll_models.dart`, `PayslipSummaryModel`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (2 nodes): `guard_pin_status.dart`, `GuardPinStatus`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (2 nodes): `incident_models.dart`, `IncidentModel`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (2 nodes): `guard_profile.dart`, `GuardProfileModel`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 2` to `Community 0`, `Community 1`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 11`, `Community 13`, `Community 15`?**
  _High betweenness centrality (0.269) - this node is a cross-community bridge._
- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 1` to `Community 0`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 10`, `Community 11`, `Community 14`, `Community 15`?**
  _High betweenness centrality (0.179) - this node is a cross-community bridge._
- **Why does `../../app/theme/app_tokens.dart` connect `Community 2` to `Community 0`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 11`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **What connects `main`, `ProviderScope`, `package:ciss_mobile/features/auth/presentation/login_hub_screen.dart` to the rest of the system?**
  _678 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._