import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_tokens.dart';
import '../app/theme/app_theme.dart';
import '../core/models/app_role.dart';
import '../core/models/auth_session.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_gate_screen.dart';
import '../features/auth/presentation/login_hub_screen.dart';
import '../features/auth/presentation/role_login_screen.dart';
import '../features/field_officer/field_officer_tab_provider.dart';
import '../features/field_officer/presentation/field_officer_shell.dart';
import '../features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import '../features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import '../features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import '../features/field_officer/presentation/screens/field_officer_reports_screen.dart';
import '../features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import '../features/field_officer/presentation/screens/field_officer_patrol_activity_screen.dart';
import '../features/guard/guard_tab_provider.dart';
import '../features/guard/presentation/guard_shell.dart';
import '../features/guard/presentation/screens/guard_attendance_screen.dart';
import '../features/guard/presentation/screens/guard_dashboard_screen.dart';
import '../features/guard/presentation/screens/guard_evaluations_screen.dart';
import '../features/guard/presentation/screens/guard_incidents_screen.dart';
import '../features/guard/presentation/screens/guard_leave_screen.dart';
import '../features/guard/presentation/screens/guard_patrol_screen.dart';
import '../features/guard/presentation/screens/guard_payslips_screen.dart';
import '../features/guard/presentation/screens/guard_profile_screen.dart';
import '../features/guard/presentation/screens/guard_training_screen.dart';
import 'mock_data.dart';

/// Debug-only preview harness.
///
/// Renders every app screen with mock data so design/visual issues can be
/// inspected on a device without a live backend. Guarded by [kDebugMode] and
/// never referenced from production navigation.

final AuthSession _mockSession = AuthSession(
  role: AppRole.guard,
  displayName: 'Rahul Kumar',
  primaryId: 'CISS-1042',
  uid: 'mock-uid-guard',
  email: 'rahul.kumar@example.com',
  employeeDocId: 'emp_1042',
  assignedDistricts: const <String>[mockDistrict],
  clientName: mockClientName,
  district: mockDistrict,
  stateCode: 'KL',
);

final AuthSession _mockFoSession = AuthSession(
  role: AppRole.fieldOfficer,
  displayName: 'Anitha Nair',
  primaryId: 'FO-009',
  uid: 'mock-uid-fo',
  email: 'anitha.nair@example.com',
  assignedDistricts: const <String>[mockDistrict, 'Kollam'],
  stateCode: 'KL',
);

class _MockSessionNotifier extends AuthSessionNotifier {
  _MockSessionNotifier(this._session);
  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

List<Override> _guardOverrides() => <Override>[
  authSessionProvider.overrideWith(() => _MockSessionNotifier(_mockSession)),
  guardDashboardProvider.overrideWith((ref) async => mockGuardDashboard),
  guardProfileProvider.overrideWith((ref) async => mockGuardProfile),
  attendanceSitesProvider.overrideWith((ref) async => mockAttendanceSites),
  attendanceHistoryProvider.overrideWith((ref) async => mockAttendanceHistory),
  guardPayslipsProvider.overrideWith((ref) async => mockPayslips),
  guardIncidentsProvider.overrideWith((ref) async => mockIncidents),
  guardEvaluationsProvider.overrideWith((ref) async => mockEvaluations),
  guardTrainingProvider.overrideWith((ref) async => mockTrainingAssignments),
  guardPatrolStatusProvider.overrideWith((ref) async => mockPatrolStatus),
  guardLeaveProvider.overrideWith((ref) async => mockLeaveOverview),
  guardTabIndexProvider.overrideWith((ref) => 0),
];

List<Override> _foOverrides() => <Override>[
  authSessionProvider.overrideWith(() => _MockSessionNotifier(_mockFoSession)),
  fieldOfficerDashboardProvider.overrideWith(
    (ref) async => mockFieldOfficerDashboard,
  ),
  fieldOfficerWorkOrdersProvider.overrideWith((ref) async => mockWorkOrders),
  fieldOfficerGuardsProvider.overrideWith(
    (ref) async => mockFieldOfficerGuards,
  ),
  fieldOfficerGuardAttendanceProvider.overrideWith(
    (ref) async => mockFieldOfficerAttendance,
  ),
  fieldOfficerGuardAttendanceHistoryProvider.overrideWith(
    (ref) async => mockFieldOfficerAttendance,
  ),
  fieldOfficerVisitReportsProvider.overrideWith(
    (ref) async => mockVisitReports,
  ),
  fieldOfficerTrainingReportsProvider.overrideWith(
    (ref) async => mockTrainingReports,
  ),
  fieldOfficerTabIndexProvider.overrideWith((ref) => 0),
];

typedef _PreviewBuilder = Widget Function();

class _PreviewEntry {
  const _PreviewEntry(this.group, this.label, this.builder, this.overrides);
  final String group;
  final String label;
  final _PreviewBuilder builder;
  final List<Override> overrides;
}

class PreviewHarnessScreen extends StatelessWidget {
  const PreviewHarnessScreen({super.key});

  static final List<_PreviewEntry> _entries = <_PreviewEntry>[
    // Auth
    _PreviewEntry('Auth', 'Login Hub', LoginHubScreen.new, const <Override>[]),
    _PreviewEntry('Auth', 'Guard Login', _guardLogin, const <Override>[]),
    _PreviewEntry('Auth', 'Field Officer Login', _foLogin, const <Override>[]),
    _PreviewEntry('Auth', 'Auth Gate (loading)', _authGate, const <Override>[]),

    // Guard
    _PreviewEntry(
      'Guard',
      'Shell (3-tab nav)',
      GuardShell.new,
      _guardOverrides(),
    ),
    _PreviewEntry(
      'Guard',
      'Dashboard',
      GuardDashboardScreen.new,
      _guardOverrides(),
    ),
    _PreviewEntry(
      'Guard',
      'Attendance / Duty',
      GuardAttendanceScreen.new,
      _guardOverrides(),
    ),
    _PreviewEntry('Guard', 'More', GuardMoreScreen.new, _guardOverrides()),
    _PreviewEntry(
      'Guard',
      'Profile',
      GuardProfileScreen.new,
      _guardOverrides(),
    ),
    _PreviewEntry('Guard', 'Leave', GuardLeaveScreen.new, _guardOverrides()),
    _PreviewEntry('Guard', 'Patrol', GuardPatrolScreen.new, _guardOverrides()),
    _PreviewEntry(
      'Guard',
      'Payslips',
      GuardPayslipsScreen.new,
      _guardOverrides(),
    ),
    _PreviewEntry(
      'Guard',
      'Incidents',
      GuardIncidentsScreen.new,
      _guardOverrides(),
    ),
    _PreviewEntry(
      'Guard',
      'Evaluations',
      GuardEvaluationsScreen.new,
      _guardOverrides(),
    ),
    _PreviewEntry(
      'Guard',
      'Training',
      GuardTrainingScreen.new,
      _guardOverrides(),
    ),

    // Field Officer
    _PreviewEntry('FO', 'Shell', FieldOfficerShell.new, _foOverrides()),
    _PreviewEntry(
      'FO',
      'Dashboard',
      FieldOfficerDashboardScreen.new,
      _foOverrides(),
    ),
    _PreviewEntry(
      'FO',
      'Work Orders',
      FieldOfficerWorkOrdersScreen.new,
      _foOverrides(),
    ),
    _PreviewEntry('FO', 'Guards', FieldOfficerGuardsScreen.new, _foOverrides()),
    _PreviewEntry(
      'FO',
      'Patrol Activity',
      FieldOfficerPatrolActivityScreen.new,
      <Override>[
        ..._foOverrides(),
        fieldOfficerPatrolActivityProvider.overrideWith(
          (ref) async => mockPatrolActivitiesPayload,
        ),
      ],
    ),
    _PreviewEntry(
      'FO',
      'Guard Attendance',
      FieldOfficerGuardAttendanceScreen.new,
      _foOverrides(),
    ),
    _PreviewEntry(
      'FO',
      'Reports',
      FieldOfficerReportsScreen.new,
      _foOverrides(),
    ),
    _PreviewEntry('FO', 'More', FieldOfficerMoreScreen.new, _foOverrides()),
  ];

  static Widget _guardLogin() => const RoleLoginScreen.guard();
  static Widget _foLogin() => const RoleLoginScreen.fieldOfficer();
  static Widget _authGate() => const AuthGateScreen();

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final groups = <String, List<_PreviewEntry>>{};
    for (final e in _entries) {
      groups.putIfAbsent(e.group, () => <_PreviewEntry>[]).add(e);
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(title: const Text('Design Preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          for (final entry in groups.entries) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.inkMuted,
                ),
              ),
            ),
            for (final e in entry.value)
              Card(
                child: ListTile(
                  title: Text(e.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => ProviderScope(
                                overrides: e.overrides,
                                child: e.builder(),
                              ),
                        ),
                      ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Standalone entry: `flutter run -t lib/dev/preview_harness.dart`.
void main() {
  runApp(previewHarnessApp());
}

/// Convenience wrapper to launch the harness full-screen from main() in debug.
Widget previewHarnessApp() {
  return ProviderScope(
    child: MaterialApp(
      title: 'CISS Workforce Design Preview',
      debugShowCheckedModeBanner: false,
      theme: buildCissTheme(Brightness.light),
      darkTheme: buildCissTheme(Brightness.dark),
      home: const PreviewHarnessScreen(),
    ),
  );
}
