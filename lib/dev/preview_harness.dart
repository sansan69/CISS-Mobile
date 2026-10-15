import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_tokens.dart';
import '../app/theme/app_theme.dart';
import '../core/models/app_role.dart';
import '../core/models/auth_session.dart';
import '../core/models/mobile_dashboard_models.dart';
import '../core/models/duty_models.dart';
import '../core/network/providers.dart';
import '../features/guard/application/duty_willingness_controller.dart';
import '../features/field_officer/presentation/screens/field_officer_assignments_screen.dart';
import '../features/field_officer/presentation/widgets/work_order_willingness_sheet.dart';
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
import '../features/guard/presentation/screens/guard_duties_screen.dart';
import '../features/guard/presentation/screens/guard_evaluations_screen.dart';
import '../features/guard/presentation/screens/guard_incidents_screen.dart';
import '../features/guard/presentation/screens/guard_leave_screen.dart';
import '../features/guard/presentation/screens/guard_patrol_screen.dart';
import '../features/guard/presentation/screens/guard_payslips_screen.dart';
import '../features/guard/presentation/screens/guard_profile_screen.dart';
import '../features/guard/presentation/screens/guard_training_screen.dart';
import 'mock_data.dart';
import 'preview_safety.dart';

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

class _LoadingSessionNotifier extends AuthSessionNotifier {
  @override
  Future<AuthSession?> build() => Completer<AuthSession?>().future;
}

List<Override> _guardOverrides() => <Override>[
  ...previewSafetyOverrides(fixtureSession: _mockSession),
  guardDashboardProvider.overrideWith(
    (ref) async => mockGuardDashboardVariant(),
  ),
  guardProfileProvider.overrideWith((ref) async => mockGuardProfile),
  guardDutiesProvider.overrideWith(
    (ref) async => [
      GuardDuty.fromJson({
        'id': 'assignment_preview',
        'kind': 'assigned',
        'status': 'assigned',
        'siteName': mockGuardDashboard.nextShiftSiteName,
        'date': mockGuardDashboard.nextShiftDate,
        'shiftLabel': mockGuardDashboard.nextShiftLabel,
      }),
    ],
  ),
  attendanceSitesProvider.overrideWith((ref) async => mockAttendanceSites),
  attendanceHistoryProvider.overrideWith((ref) async => mockAttendanceHistory),
  recentAttendanceHistoryProvider.overrideWith(
    (ref) async => mockAttendanceHistory,
  ),
  guardPayslipsProvider.overrideWith((ref) async => mockPayslips),
  guardIncidentsProvider.overrideWith((ref) async => mockIncidents),
  guardEvaluationsProvider.overrideWith((ref) async => mockEvaluations),
  guardTrainingProvider.overrideWith((ref) async => mockTrainingAssignments),
  guardPatrolStatusProvider.overrideWith((ref) async => mockPatrolStatus),
  guardLeaveProvider.overrideWith((ref) async => mockLeaveOverview),
  guardTabIndexProvider.overrideWith((ref) => 0),
];

List<Override> _foOverrides() => <Override>[
  ...previewSafetyOverrides(fixtureSession: _mockFoSession),
  mobileRepositoryProvider.overrideWithValue(ReadOnlyDutyPreviewRepository()),
  fieldOfficerAssignmentsProvider.overrideWith((ref) async => mockAssignments),
  workOrderWillingnessProvider.overrideWith(
    (ref, id) async => mockWorkOrderWillingness(id),
  ),
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
    _PreviewEntry('Auth', 'Auth Gate (loading)', _authGate, <Override>[
      ...previewSafetyOverrides(),
      authSessionProvider.overrideWith(_LoadingSessionNotifier.new),
    ]),

    // Guard
    _PreviewEntry(
      'Guard',
      'Shell (4-tab nav)',
      GuardShell.new,
      _guardOverrides(),
    ),
    _PreviewEntry(
      'Guard',
      'Dashboard',
      GuardDashboardScreen.new,
      _guardOverrides(),
    ),
    for (final fixture in <(String, GuardDashboardSnapshot)>[
      ('Home — no assignment', mockGuardDashboardVariant(noAssignment: true)),
      ('Home — duty unavailable', mockGuardDashboardVariant(unavailable: true)),
      ('Home — long content', mockGuardDashboardVariant(longContent: true)),
    ])
      _PreviewEntry('Guard', fixture.$1, GuardDashboardScreen.new, <Override>[
        ..._guardOverrides(),
        guardDashboardProvider.overrideWith((ref) async => fixture.$2),
        guardDutiesProvider.overrideWith(
          (ref) async =>
              fixture.$2.nextShiftSiteName == null
                  ? []
                  : [
                    mockTcsDuty(
                      assigned: true,
                      status: 'assigned',
                      longContent: fixture.$1.contains('long'),
                    ),
                  ],
        ),
      ]),
    _PreviewEntry(
      'Guard',
      'Home — loading',
      GuardDashboardScreen.new,
      <Override>[
        ..._guardOverrides(),
        guardDashboardProvider.overrideWith(
          (ref) => Completer<GuardDashboardSnapshot>().future,
        ),
      ],
    ),
    _PreviewEntry('Guard', 'Home — error', GuardDashboardScreen.new, <Override>[
      ..._guardOverrides(),
      guardDashboardProvider.overrideWith(
        (ref) async => throw Exception('Preview dashboard unavailable'),
      ),
    ]),
    _PreviewEntry(
      'Guard',
      'Upcoming duty',
      GuardDutiesScreen.new,
      _guardOverrides(),
    ),
    for (final state in [
      'eligible TCS',
      'cancelled',
      'closed',
      'long content',
      'permanent',
      'category not set',
      'pending response',
      'rejected response',
    ])
      _PreviewEntry('Guard', 'Duty — $state', GuardDutiesScreen.new, <Override>[
        ..._guardOverrides(),
        guardDutiesProvider.overrideWith(
          (ref) async => [
            mockTcsDuty(
              status:
                  state == 'cancelled'
                      ? 'cancelled'
                      : state == 'closed'
                      ? 'closed'
                      : state == 'permanent'
                      ? 'assigned'
                      : 'open',
              assigned: state == 'permanent',
              longContent: state == 'long content',
              categoryNotSet: state == 'category not set',
            ),
          ],
        ),
        guardProfileProvider.overrideWith(
          (ref) async => mockTcsProfile(
            category:
                state == 'permanent'
                    ? 'permanent'
                    : state == 'category not set'
                    ? null
                    : 'adhoc',
          ),
        ),
        if (state == 'pending response' || state == 'rejected response')
          dutyResponseProvider.overrideWith(
            (ref, id) => mockWillingnessState(
              state == 'pending response' ? 'pending' : 'rejected',
            ),
          ),
      ]),
    _PreviewEntry(
      'Guard',
      'Duty — no assignment',
      GuardDutiesScreen.new,
      <Override>[
        ..._guardOverrides(),
        guardDutiesProvider.overrideWith((ref) async => []),
      ],
    ),
    _PreviewEntry(
      'Guard',
      'Duty — rejected result, missing duty',
      GuardDutiesScreen.new,
      <Override>[
        ..._guardOverrides(),
        guardDutiesProvider.overrideWith((ref) async => []),
        dutyResponseHistoryProvider.overrideWith(
          (ref) => [
            mockWillingnessState(
              'rejected',
              reason:
                  'Responses closed before this queued response reached the server.',
            ),
          ],
        ),
      ],
    ),
    _PreviewEntry(
      'Guard',
      'Duty — pending result, feed error',
      GuardDutiesScreen.new,
      <Override>[
        ..._guardOverrides(),
        guardDutiesProvider.overrideWith(
          (ref) async => throw StateError('Fixture feed unavailable'),
        ),
        dutyResponseHistoryProvider.overrideWith(
          (ref) => [
            mockWillingnessState(
              'pending',
              reason: 'Your response has not been saved yet.',
            ),
          ],
        ),
      ],
    ),
    _PreviewEntry('Guard', 'Duty — loading', GuardDutiesScreen.new, <Override>[
      ..._guardOverrides(),
      guardDutiesProvider.overrideWith(
        (ref) => Completer<List<GuardDuty>>().future,
      ),
    ]),
    _PreviewEntry('Guard', 'Duty — error', GuardDutiesScreen.new, <Override>[
      ..._guardOverrides(),
      guardDutiesProvider.overrideWith(
        (ref) async => throw StateError('Fixture feed unavailable'),
      ),
    ]),
    _PreviewEntry(
      'Guard',
      'Duty — unavailable',
      GuardDutiesScreen.new,
      <Override>[
        ..._guardOverrides(),
        guardDutiesProvider.overrideWith(
          (ref) async => throw StateError('Fixture feed unavailable'),
        ),
      ],
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

    _PreviewEntry(
      'Guard',
      'Home — eligible TCS',
      GuardDashboardScreen.new,
      <Override>[
        ..._guardOverrides(),
        guardDutiesProvider.overrideWith((ref) async => [mockTcsDuty()]),
        guardProfileProvider.overrideWith((ref) async => mockTcsProfile()),
      ],
    ),
    // Field Officer
    _PreviewEntry(
      'FO',
      'Scheduled duties',
      FieldOfficerAssignmentsScreen.new,
      _foOverrides(),
    ),
    _PreviewEntry(
      'FO',
      'Willing responses',
      () => Scaffold(
        appBar: AppBar(title: const Text('Preview responses')),
        body: WorkOrderWillingnessSheet(
          workOrderId: 'preview_exam',
          onSelect: (_) {},
        ),
      ),
      _foOverrides(),
    ),
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
      appBar: AppBar(
        title: const Text('Design Preview'),
        actions: const <Widget>[_PreviewThemeButton()],
      ),
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
                  key: ValueKey('preview-${e.group}-${e.label}'),
                  title: Text(e.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PreviewSurface(entry: e),
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

final _previewThemeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.light,
);
final _previewLargeTextProvider = StateProvider<bool>((ref) => false);

class _PreviewThemeButton extends ConsumerWidget {
  const _PreviewThemeButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Toggle preview theme',
    icon: Icon(
      ref.watch(_previewThemeProvider) == ThemeMode.dark
          ? Icons.light_mode_outlined
          : Icons.dark_mode_outlined,
    ),
    onPressed:
        () =>
            ref.read(_previewThemeProvider.notifier).state =
                ref.read(_previewThemeProvider) == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
  );
}

class _PreviewSurface extends ConsumerStatefulWidget {
  const _PreviewSurface({required this.entry});
  final _PreviewEntry entry;
  @override
  ConsumerState<_PreviewSurface> createState() => _PreviewSurfaceState();
}

class _PreviewSurfaceState extends ConsumerState<_PreviewSurface> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 48,
      title: Text(
        widget.entry.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'Toggle large preview text',
          icon: const Icon(Icons.text_fields_rounded),
          onPressed:
              () =>
                  ref.read(_previewLargeTextProvider.notifier).state =
                      !ref.read(_previewLargeTextProvider),
        ),
        const _PreviewThemeButton(),
        IconButton(
          tooltip: 'Close preview',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
    // Screens pushed from a fixture remain descendants of its provider scope.
    body: ProviderScope(
      overrides: widget.entry.overrides,
      child: NavigatorPopHandler<void>(
        onPopWithResult: (_) {
          _navigatorKey.currentState?.maybePop();
        },
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute:
              (_) => MaterialPageRoute<void>(
                builder: (_) => widget.entry.builder(),
              ),
        ),
      ),
    ),
  );
}

/// Standalone entry: `flutter run -t lib/dev/preview_harness.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(previewHarnessApp());
}

Widget previewHarnessApp() {
  if (!kDebugMode) throw UnsupportedError('Design previews are debug-only.');
  return ProviderScope(
    overrides: previewSafetyOverrides(),
    child: const _PreviewApp(),
  );
}

class _PreviewApp extends ConsumerWidget {
  const _PreviewApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'CISS Workforce Design Preview',
    debugShowCheckedModeBanner: false,
    theme: buildCissTheme(Brightness.light),
    darkTheme: buildCissTheme(Brightness.dark),
    themeMode: ref.watch(_previewThemeProvider),
    builder: (context, child) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final style = (isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarDividerColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          );
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: style,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler:
                ref.watch(_previewLargeTextProvider)
                    ? const TextScaler.linear(1.8)
                    : MediaQuery.textScalerOf(context),
          ),
          child: child!,
        ),
      );
    },
    home: const PreviewHarnessScreen(),
  );
}
