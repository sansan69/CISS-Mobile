import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/guard/presentation/screens/guard_attendance_screen.dart';
import '../../features/guard/presentation/screens/guard_dashboard_screen.dart';
import '../../features/guard/presentation/screens/guard_evaluations_screen.dart';
import '../../features/guard/presentation/screens/guard_incidents_screen.dart';
import '../../features/guard/presentation/screens/guard_payslips_screen.dart';
import '../../features/guard/presentation/screens/guard_profile_screen.dart';
import '../../features/guard/presentation/screens/guard_training_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_reports_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';

/// Preloads data for adjacent tabs so switching feels instant.
///
/// Call `preloadForGuardTab(index)` when a guard tab is selected — it will
/// eagerly fetch data for the neighbouring tabs in the background.
class PreloadController {
  PreloadController(this._ref);

  final Ref _ref;
  int _lastGuardTab = 0;
  int _lastFOTab = 0;

  // ── Guard tab providers ────────────────────────────────────────────────────

  final List<ProviderBase<Object?>> _guardProviders = [
    guardDashboardProvider,
    attendanceSitesProvider,
    guardTrainingProvider,
    guardPayslipsProvider,
    // Tab 4 is "More" — preload profile + incidents
    guardProfileProvider,
    guardIncidentsProvider,
    guardEvaluationsProvider,
  ];

  // ── Field officer tab providers ────────────────────────────────────────────

  final List<ProviderBase<Object?>> _foProviders = [
    fieldOfficerDashboardProvider,
    fieldOfficerWorkOrdersProvider,
    fieldOfficerGuardsProvider,
    fieldOfficerGuardAttendanceProvider,
    fieldOfficerVisitReportsProvider,
    fieldOfficerTrainingReportsProvider,
  ];

  /// Preload guard tab data. Called when the user taps a guard tab.
  void preloadForGuardTab(int index) {
    if (index == _lastGuardTab) return;
    _lastGuardTab = index;

    final neighbours = _guardNeighbours(index);
    for (final i in neighbours) {
      _warmProvider(_guardProviders[i]);
    }
  }

  /// Preload field officer tab data.
  void preloadForFieldOfficerTab(int index) {
    if (index == _lastFOTab) return;
    _lastFOTab = index;

    final neighbours = _foNeighbours(index);
    for (final i in neighbours) {
      _warmProvider(_foProviders[i]);
    }
  }

  /// Eagerly preload all guard data (called after login).
  void preloadAllGuard() {
    for (final provider in _guardProviders) {
      _warmProvider(provider);
    }
  }

  /// Eagerly preload all field officer data (called after login).
  void preloadAllFieldOfficer() {
    for (final provider in _foProviders) {
      _warmProvider(provider);
    }
  }

  void _warmProvider(ProviderBase<Object?> provider) {
    try {
      _ref.read(provider);
    } catch (_) {
      // Provider may throw if dependencies aren't ready (e.g. no auth token).
      // That's fine — it'll retry when the user navigates there.
    }
  }

  List<int> _guardNeighbours(int index) {
    switch (index) {
      case 0:
        return [1, 4];
      case 1:
        return [0, 2];
      case 2:
        return [1, 3];
      case 3:
        return [2, 4];
      case 4:
        return [0, 4, 5, 6];
      default:
        return [];
    }
  }

  List<int> _foNeighbours(int index) {
    switch (index) {
      case 0:
        return [1, 3];
      case 1:
        return [0, 2];
      case 2:
        return [1, 3];
      case 3:
        return [2, 4];
      case 4:
        return [3, 5];
      case 5:
        return [0, 4];
      default:
        return [];
    }
  }
}

final preloadControllerProvider = Provider<PreloadController>((ref) {
  return PreloadController(ref);
});
