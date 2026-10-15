import 'dart:async';

import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/models/report_models.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fo_large_text_test.dart' show dashboardSnapshot;
import 'support/guard_redesign_fixtures.dart';

/// Operations (work orders) is pushed from More and from work-order
/// notifications, and only this repository call feeds its three states.
class _PendingWorkOrdersRepository extends NoNetworkRepository {
  _PendingWorkOrdersRepository(this.completer);

  final Completer<List<WorkOrderModel>> completer;

  @override
  Future<List<WorkOrderModel>> fetchFieldOfficerWorkOrders() => completer.future;
}

const _screenSize = Size(411, 914);
const _systemInsets = EdgeInsets.fromLTRB(8, 48, 8, 24);

GuardProfileModel _syntheticGuard() => GuardProfileModel(
  id: 'fixture-1',
  fullName: 'Sample Employee',
  employeeId: 'TEST-001',
  clientName: 'Sample Client',
  district: 'Sample District',
  phoneNumber: '0000000000',
  status: 'Active',
);

void _useInsetViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screenSize;
  const systemPadding = FakeViewPadding(left: 8, top: 48, right: 8, bottom: 24);
  tester.view.padding = systemPadding;
  tester.view.viewPadding = systemPadding;
  addTearDown(tester.view.reset);
}

void _expectSafeBounds(WidgetTester tester, Finder content) {
  final rect = tester.getRect(content);
  expect(rect.top, greaterThanOrEqualTo(_systemInsets.top));
  expect(
    rect.bottom,
    lessThanOrEqualTo(_screenSize.height - _systemInsets.bottom),
  );
  expect(rect.top, lessThanOrEqualTo(_systemInsets.top + 20));
  expect(rect.left, greaterThanOrEqualTo(_systemInsets.left));
  expect(
    rect.right,
    lessThanOrEqualTo(_screenSize.width - _systemInsets.right),
  );
}

Future<void> _pumpDirectory(
  WidgetTester tester, {
  required Future<List<GuardProfileModel>> future,
}) async {
  _useInsetViewport(tester);
  await tester.pumpWidget(
    guardTestApp(
      screen: const FieldOfficerGuardsScreen(),
      role: AppRole.fieldOfficer,
      overrides: <Override>[
        fieldOfficerGuardsProvider.overrideWith((ref) => future),
      ],
    ),
  );
  await tester.pump();
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required Future<FieldOfficerDashboardSnapshot> future,
}) async {
  _useInsetViewport(tester);
  await tester.pumpWidget(
    guardTestApp(
      screen: const FieldOfficerDashboardScreen(),
      role: AppRole.fieldOfficer,
      overrides: <Override>[
        fieldOfficerDashboardProvider.overrideWith((ref) => future),
      ],
    ),
  );
  await tester.pump();
}

Future<void> _pumpWorkOrders(
  WidgetTester tester, {
  required Completer<List<WorkOrderModel>> completer,
}) async {
  _useInsetViewport(tester);
  await tester.pumpWidget(
    guardTestApp(
      screen: const FieldOfficerWorkOrdersScreen(),
      role: AppRole.fieldOfficer,
      overrides: <Override>[
        mobileRepositoryProvider.overrideWithValue(
          _PendingWorkOrdersRepository(completer),
        ),
      ],
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadInterFont);

  group('field officer system insets', () {
    testWidgets('directory loading respects status and navigation insets', (
      tester,
    ) async {
      final pending = Completer<List<GuardProfileModel>>();
      await _pumpDirectory(tester, future: pending.future);
      _expectSafeBounds(tester, find.byType(Column).first);
      expect(
        tester.getTopLeft(find.text('Employee Directory')).dy,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('directory error respects status and navigation insets', (
      tester,
    ) async {
      final pending = Completer<List<GuardProfileModel>>();
      await _pumpDirectory(tester, future: pending.future);
      pending.completeError(Exception('Fixture error'));
      await tester.pump();
      await tester.pump();
      _expectSafeBounds(tester, find.byType(Column).first);
      expect(
        tester.getTopLeft(find.text('Employee Directory')).dy,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('directory data scrollable respects system insets once', (
      tester,
    ) async {
      await _pumpDirectory(
        tester,
        future: Future.value(<GuardProfileModel>[_syntheticGuard()]),
      );
      final list = find.byType(ListView).first;
      _expectSafeBounds(tester, list);
      expect(
        tester.getTopLeft(find.text('Employee Directory')).dy,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('dashboard loading respects status and navigation insets', (
      tester,
    ) async {
      final pending = Completer<FieldOfficerDashboardSnapshot>();
      await _pumpDashboard(tester, future: pending.future);
      _expectSafeBounds(tester, find.byType(Column).first);
      expect(
        tester.getTopLeft(find.text('Field Officer')).dy,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('dashboard error respects status and navigation insets', (
      tester,
    ) async {
      final pending = Completer<FieldOfficerDashboardSnapshot>();
      await _pumpDashboard(tester, future: pending.future);
      pending.completeError(Exception('Fixture error'));
      await tester.pump();
      await tester.pump();
      _expectSafeBounds(tester, find.byType(Column).first);
      expect(
        tester.getTopLeft(find.text('Field Officer')).dy,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('dashboard loaded scrollable has one safe inset boundary', (
      tester,
    ) async {
      await _pumpDashboard(tester, future: Future.value(dashboardSnapshot()));
      final list = find.byType(ListView).first;
      _expectSafeBounds(tester, list);
      expect(tester.getRect(list).top, closeTo(48, 0.5));
    });

    testWidgets('operations loading respects status and navigation insets', (
      tester,
    ) async {
      final pending = Completer<List<WorkOrderModel>>();
      await _pumpWorkOrders(tester, completer: pending);
      _expectSafeBounds(tester, find.byType(Column).first);
      expect(
        tester.getTopLeft(find.text('Operations')).dy,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('operations error respects status and navigation insets', (
      tester,
    ) async {
      final pending = Completer<List<WorkOrderModel>>();
      await _pumpWorkOrders(tester, completer: pending);
      pending.completeError(Exception('Fixture error'));
      await tester.pump();
      await tester.pump();
      _expectSafeBounds(tester, find.byType(Column).first);
      expect(
        tester.getTopLeft(find.text('Operations')).dy,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('operations list respects status and navigation insets', (
      tester,
    ) async {
      final pending = Completer<List<WorkOrderModel>>();
      await _pumpWorkOrders(tester, completer: pending);
      pending.complete(<WorkOrderModel>[]);
      await tester.pump();
      final list = find.byType(ListView).first;
      _expectSafeBounds(tester, list);
      expect(tester.getRect(list).top, closeTo(48, 0.5));
    });
  });
}
