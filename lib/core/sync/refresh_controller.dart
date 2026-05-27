import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_reports_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import '../../features/guard/presentation/screens/guard_attendance_screen.dart';
import '../../features/guard/presentation/screens/guard_dashboard_screen.dart';
import '../../features/guard/presentation/screens/guard_incidents_screen.dart';
import '../../features/guard/presentation/screens/guard_profile_screen.dart';

/// Periodically invalidates key dashboard and list providers to keep data fresh.
class RefreshController {
  RefreshController(this._ref);

  final Ref _ref;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      if (kDebugMode) {
        print('RefreshController: Triggering background refresh...');
      }
      _refreshAll();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _refreshAll() {
    // Stagger invalidations to avoid thundering herd.
    final providers = <ProviderBase<Object?>>[
      guardDashboardProvider,
      attendanceSitesProvider,
      guardProfileProvider,
      guardIncidentsProvider,
      fieldOfficerDashboardProvider,
      fieldOfficerGuardAttendanceProvider,
      fieldOfficerGuardsProvider,
      fieldOfficerWorkOrdersProvider,
      fieldOfficerVisitReportsProvider,
      fieldOfficerTrainingReportsProvider,
    ];

    for (var i = 0; i < providers.length; i++) {
      Timer(Duration(milliseconds: i * 200), () {
        _ref.invalidate(providers[i]);
      });
    }
  }
}

final refreshControllerProvider = Provider<RefreshController>((ref) {
  final controller = RefreshController(ref);
  controller.start();
  ref.onDispose(() => controller.stop());
  return controller;
});
