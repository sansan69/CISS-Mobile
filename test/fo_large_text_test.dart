import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/models/report_models.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_duties_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import 'package:ciss_mobile/features/field_officer/field_officer_tab_provider.dart';
import 'package:ciss_mobile/shared/widgets/metric_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

/// Mirrors the numbers the device QA pass saw on the FO dashboard, where
/// `MY GUARDS 340` split across two lines and `Required`/`Assigned` were cut to
/// `Req…`/`Assi…` at 1.8 text.
FieldOfficerDashboardSnapshot dashboardSnapshot() =>
    FieldOfficerDashboardSnapshot(
      name: 'Anitha Nair',
      stateCode: 'KL',
      assignedDistricts: const <String>['Thiruvananthapuram'],
      totalGuards: 340,
      activeGuards: 300,
      totalSitesInScope: 12,
      attendanceSummary: const FieldOfficerAttendanceSummary(
        date: '2026-10-14',
        checkedInToday: 289,
        onDutyNow: 241,
        districts: <FieldOfficerDistrictAttendance>[],
      ),
      todayOverview: const FieldOfficerTodayOverview(
        sitesScheduled: 12,
        dutiesScheduled: 18,
        requiredGuards: 96,
        assignedGuards: 84,
        unassignedGuards: 12,
        sitesWithoutAttendance: 2,
        visitReportsToday: 4,
        trainingReportsToday: 1,
        pendingSiteReports: 2,
        underAssignedSites: 5,
      ),
      todaySites: const <FieldOfficerTodaySiteBrief>[],
      attendanceSites: const <FieldOfficerAttendanceSite>[],
      upcomingWorkOrders: const <WorkOrderModel>[],
      recentVisitReports: const <VisitReportModel>[],
      recentTrainingReports: const <TrainingReportModel>[],
      recentWorkOrders: const <WorkOrderModel>[],
    );

Future<void> pumpDashboard(WidgetTester tester, {required double scale}) async {
  usePhoneViewport(tester);
  await tester.pumpWidget(
    guardTestApp(
      screen: const FieldOfficerDashboardScreen(),
      scale: scale,
      overrides: <Override>[
        fieldOfficerDashboardProvider.overrideWith(
          (ref) async => dashboardSnapshot(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadInterFont);

  group('field officer dashboard stat tiles', () {
    testWidgets('1.0 text keeps three metric cards in one row', (tester) async {
      await pumpDashboard(tester, scale: 1);
      final rects = <Rect>[
        for (var index = 0; index < 3; index++)
          tester.getRect(find.byType(MetricCard).at(index)),
      ];
      for (final rect in rects) {
        expect(rect.top, rects.first.top);
        expect(rect.width, closeTo(rects.first.width, 0.5));
      }
      // The five overview tiles are one row at 1.0, including the widest label
      // that is already ellipsized today ("Unassign…").
      final tiles = <Finder>[
        find.text('Sites'),
        find.text('Duties'),
        find.text('Required'),
        find.text('Assigned'),
        find.text('Unassigned'),
      ];
      final tops = tiles.map((f) => tester.getRect(f).top).toSet();
      expect(tops, hasLength(1));
    });

    testWidgets('1.8 text keeps the guard count on one line', (tester) async {
      await pumpDashboard(tester, scale: 1.8);
      expect(tester.takeException(), isNull);
      expect(renderedLineCount(tester, find.text('340')), 1);
      final cards = <Rect>[
        for (var index = 0; index < 3; index++)
          tester.getRect(find.byType(MetricCard).at(index)),
      ];
      expect(cards.first.width, greaterThan(cards.first.height));
    });

    testWidgets('1.8 text keeps the overview labels readable', (tester) async {
      await pumpDashboard(tester, scale: 1.8);
      for (final label in <String>['Sites', 'Duties', 'Required', 'Assigned']) {
        expectRenderedInFull(tester, find.text(label));
      }
    });
  });

  group('field officer duties tab strip', () {
    testWidgets('tab labels fit their strip at 1.8 text', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        guardTestApp(
          screen: const FieldOfficerDutiesScreen(),
          scale: 1.8,
          overrides: <Override>[
            fieldOfficerWorkOrdersProvider.overrideWith(
              (ref) async => const <WorkOrderModel>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectRenderedInFull(tester, find.text('Work Orders'));
      expectRenderedInFull(tester, find.text('Attendance'));
    });
  });

  testWidgets('Employee Directory quick action selects the provider tab', (
    tester,
  ) async {
    usePhoneViewport(tester);
    usePhoneViewport(tester);
    final container = ProviderContainer(
      overrides: [
        fieldOfficerDashboardProvider.overrideWith(
          (ref) async => dashboardSnapshot(),
        ),
        fieldOfficerGuardsProvider.overrideWith(
          (ref) async => const <GuardProfileModel>[],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 800)),
            child: const FieldOfficerDashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Employee Directory'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expectRenderedInFull(tester, find.text('Employee Directory'));
    await tester.tap(find.text('Employee Directory'));
    await tester.pumpAndSettle();
    expect(
      container.read(fieldOfficerTabIndexProvider),
      fieldOfficerEmployeesTabIndex,
    );
  });
}
