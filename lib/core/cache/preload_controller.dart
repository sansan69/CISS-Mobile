import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/providers.dart';
import '../../features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import '../../features/guard/presentation/screens/guard_attendance_screen.dart';
import '../../features/guard/presentation/screens/guard_dashboard_screen.dart';
import '../../features/guard/presentation/screens/guard_profile_screen.dart';

/// Pre-warms the Riverpod provider cache after login to reduce skeleton
/// screen FOUC on guard/FO dashboards.
class PreloadController {
  PreloadController(this._ref);

  final Ref _ref;

  void preloadAllGuard() {
    unawaited(_safe('guard dashboard', () => _ref.read(guardDashboardProvider.future)));
    unawaited(_safe('guard profile', () => _ref.read(guardProfileProvider.future)));
    unawaited(_safe('attendance sites', () => _ref.read(attendanceSitesProvider.future)));
    unawaited(_safe('attendance history', () => _ref.read(attendanceHistoryProvider.future)));
  }

  void preloadAllFieldOfficer() {
    unawaited(_safe('FO dashboard', () => _ref.read(fieldOfficerDashboardProvider.future)));
    unawaited(_safe('FO work orders', () => _ref.read(fieldOfficerWorkOrdersProvider.future)));
    unawaited(_safe('FO guards', () => _ref.read(fieldOfficerGuardsProvider.future)));
  }

  void preloadAllClient() {
    final repo = _ref.read(mobileRepositoryProvider);
    unawaited(_safe('client dashboard', repo.fetchClientDashboard));
    unawaited(_safe('client guards', () => repo.fetchClientGuards('')));
    unawaited(_safe('client attendance', () => repo.fetchClientAttendance('')));
    unawaited(_safe('client work orders', () => repo.fetchClientWorkOrders('')));
  }

  Future<void> _safe(String label, Future<Object?> Function() loader) async {
    try {
      await loader();
    } catch (error) {
      debugPrint('PreloadController: $label preload skipped: $error');
    }
  }
}

final preloadControllerProvider =
    Provider<PreloadController>((ref) => PreloadController(ref));
