import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_patrol_activity_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_reports_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_tools_screens.dart';
import '../../features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import '../../features/field_officer/presentation/widgets/work_order_revision_banner.dart';
import '../../features/guard/presentation/screens/guard_attendance_screen.dart';
import '../../features/guard/presentation/screens/guard_dashboard_screen.dart';
import '../../features/guard/presentation/screens/guard_duties_screen.dart';
import '../../features/guard/presentation/screens/guard_evaluations_screen.dart';
import '../../features/guard/presentation/screens/guard_incidents_screen.dart';
import '../../features/guard/presentation/screens/guard_patrol_screen.dart';
import '../../features/guard/presentation/screens/guard_payslips_screen.dart';
import '../../features/guard/presentation/screens/guard_profile_screen.dart';
import '../../features/guard/presentation/screens/guard_training_leaderboard_screen.dart';
import '../../features/guard/presentation/screens/guard_training_screen.dart';

/// Every non-autoDispose `FutureProvider` whose cached value belongs to one
/// signed-in account.
///
/// These providers keep their last resolved value for the lifetime of the
/// `ProviderScope`. Without an explicit reset a sign-out, or account A -> B
/// change, would keep serving the previous account's dashboard, profile,
/// attendance and reports from that cache until the 15 minute
/// `RefreshController` pass (audit NEW-02). They are listed once, here, so the
/// reset is a single registry rather than scattered invalidations.
///
/// New account-scoped providers must be added to this list; device-scoped ones
/// (e.g. region selection) must not.
final List<ProviderOrFamily> accountScopedProviders = <ProviderOrFamily>[
  // Guard portal.
  guardDashboardProvider,
  guardProfileProvider,
  attendanceSitesProvider,
  attendanceHistoryProvider,
  guardIncidentsProvider,
  guardEvaluationsProvider,
  guardTrainingProvider,
  guardTrainingLeaderboardProvider,
  guardPatrolStatusProvider,
  guardDutiesProvider,
  guardPayslipsProvider,
  // Field officer portal.
  fieldOfficerDashboardProvider,
  fieldOfficerGuardAttendanceProvider,
  fieldOfficerGuardAttendanceHistoryProvider,
  fieldOfficerAttendanceSitesProvider,
  fieldOfficerIncidentsProvider,
  fieldOfficerSitesProvider,
  fieldOfficerVisitReportsProvider,
  fieldOfficerTrainingReportsProvider,
  fieldOfficerWorkOrdersProvider,
  fieldOfficerWorkOrderRevisionsProvider,
  fieldOfficerGuardsProvider,
  fieldOfficerPatrolActivityProvider,
];

/// Drops every cached account-scoped value so the next read refetches for the
/// current identity. Safe to call while any of them is watched: watchers simply
/// rebuild from a fresh `AsyncLoading`/resolved state.
void invalidateAccountScopedProviders(Ref ref) {
  for (final provider in accountScopedProviders) {
    try {
      ref.invalidate(provider);
    } catch (_) {
      // One provider refusing to invalidate (e.g. already disposed) must never
      // block clearing the rest of the account's cache.
    }
  }
}
