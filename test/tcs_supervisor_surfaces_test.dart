import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_assignments_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/widgets/work_order_willingness_sheet.dart';
import 'support/guard_redesign_fixtures.dart';

class SchedulingRepository extends NoNetworkRepository {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<List<GuardAssignment>> fetchGuardAssignments({
    String? from,
    String? to,
  }) async => [];
  @override
  Future<List<FieldOfficerSiteOption>> fetchFieldOfficerSites({
    String? district,
  }) async => [
    const FieldOfficerSiteOption(
      id: 's1',
      siteName: 'Central post',
      district: 'Ernakulam',
      clientName: 'Other client',
      clientId: 'c1',
    ),
  ];
  @override
  Future<List<GuardProfileModel>> fetchFieldOfficerGuards({
    String? district,
    bool includeInactive = false,
  }) async =>
      ['a', 'b']
          .map(
            (id) => GuardProfileModel.fromJson({
              'name': 'Guard $id',
              'clientName': 'TCS',
              'tcsCategory': 'permanent',
              'status': 'Active',
            }, id: 'employee-doc-$id'),
          )
          .toList();
  @override
  Future<GuardAssignment> createGuardAssignment(
    Map<String, dynamic> body,
  ) async {
    calls.add(body);
    if (body['employeeDocId'] == 'employee-doc-b') {
      throw StateError('Guard b unavailable');
    }
    return GuardAssignment({'id': 'a1', 'version': 1});
  }

  @override
  Future<WorkOrderWillingness> fetchWorkOrderWillingness(String id) async =>
      WorkOrderWillingness(
        workOrderId: id,
        willingCount: 1,
        unavailableCount: 1,
        responses: [
          {
            'employeeDocId': 'employee-doc-a',
            'name': 'Guard a',
            'response': 'willing',
            'gender': 'Male',
            'employeeId': 'CISS/A',
          },
          {
            'employeeDocId': 'employee-doc-b',
            'name': 'Guard b',
            'response': 'unavailable',
            'gender': 'Male',
          },
        ],
      );
}

class CancellingRepository extends NoNetworkRepository {
  CancellingRepository(this.assignment);
  final GuardAssignment assignment;
  final bodies = <Map<String, dynamic>>[];
  bool failFirst = true;
  @override
  Future<List<GuardAssignment>> fetchGuardAssignments({
    String? from,
    String? to,
  }) async => [assignment];
  @override
  Future<GuardAssignment> updateGuardAssignment(
    String id,
    Map<String, dynamic> body,
  ) async {
    bodies.add(body);
    if (failFirst) {
      failFirst = false;
      throw StateError('Cancellation transport failure');
    }
    return GuardAssignment({
      'id': id,
      'version': (body['expectedVersion'] as int) + 1,
      'status': body['status'] ?? 'assigned',
      'guardName': assignment.guardName,
      'siteName': assignment.siteName,
      'date': assignment.date,
    });
  }
}

void main() {
  setUpAll(loadInterFont);
  testWidgets(
    'regular relieving form validates and reports each create result',
    (tester) async {
      final repo = SchedulingRepository();
      await tester.pumpWidget(
        guardTestApp(
          screen: const FieldOfficerAssignmentsScreen(),
          overrides: [mobileRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule duty'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create assignments'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create assignments'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(find.text('Select a site'), findsWidgets);
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central post · Ernakulam').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Duty date'),
        '2026-10-20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Shift label'),
        'Night',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Start time (HH:mm)'),
        '22:00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'End time (HH:mm)'),
        '06:00',
      );
      await tester.ensureVisible(find.text('Ends next day'));
      await tester.tap(find.text('Ends next day'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guard a'));
      await tester.tap(find.text('Guard a'));
      await tester.ensureVisible(find.text('Guard b'));
      await tester.tap(find.text('Guard b'));
      await tester.ensureVisible(find.text('Create assignments'));
      await tester.tap(find.text('Create assignments'));
      await tester.pumpAndSettle();
      expect(repo.calls.length, 2);
      expect(repo.calls.first['employeeDocId'], 'employee-doc-a');
      expect(repo.calls.first['crossesMidnight'], true);
      expect(
        repo.calls.first.keys,
        containsAll([
          'siteId',
          'date',
          'shiftLabel',
          'startTime',
          'endTime',
          'type',
          'clientRequestId',
        ]),
      );
      expect(repo.calls.first.containsKey('guardUid'), false);
      expect(find.text('Guard a: saved'), findsOneWidget);
      expect(find.textContaining('Guard b: not saved'), findsOneWidget);
    },
  );
  testWidgets(
    'scoped responses select employee document id and leave unavailable manual',
    (tester) async {
      final repo = SchedulingRepository();
      Set<String>? selected;
      await tester.pumpWidget(
        guardTestApp(
          screen: Scaffold(
            body: WorkOrderWillingnessSheet(
              workOrderId: 'e1',
              onSelect: (ids) => selected = ids,
            ),
          ),
          overrides: [mobileRepositoryProvider.overrideWithValue(repo)],
          role: AppRole.fieldOfficer,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Guard a'), findsOneWidget);
      expect(find.text('Guard b'), findsOneWidget);
      await tester.tap(find.text('Guard a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review exam roster'));
      await tester.pumpAndSettle();
      expect(selected, {'employee-doc-a'});
      expect(
        find.text('Unavailable guards can still be assigned manually.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cancellation retries reuse the same request UUID and expected version',
    (tester) async {
      final repo = CancellingRepository(
        GuardAssignment({
          'id': 'a1',
          'version': 3,
          'status': 'assigned',
          'guardName': 'Guard a',
          'siteName': 'Central post',
          'date': '2026-10-20',
        }),
      );
      await tester.pumpWidget(
        guardTestApp(
          screen: const FieldOfficerAssignmentsScreen(),
          overrides: [mobileRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Guard a · Central post'), findsOneWidget);
      Future<void> cancel() async {
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel assignment').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel assignment').last);
        await tester.pumpAndSettle();
      }

      await cancel();
      expect(repo.bodies, hasLength(1));
      expect(find.textContaining('not saved'), findsWidgets);
      await cancel();
      expect(repo.bodies, hasLength(2));
      expect(repo.bodies.last['status'], 'cancelled');
      expect(repo.bodies.last['expectedVersion'], 3);
      expect(
        repo.bodies.last['clientRequestId'],
        repo.bodies.first['clientRequestId'],
      );
      expect(repo.bodies.last['clientRequestId'], isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  // Device QA reported unattributed large-text overflows plus explicit 1.8
  // truncations on the field-officer duty surfaces this workstream owns.
  testWidgets('scheduled duties list and editor hold at 1.8 text', (
    tester,
  ) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const FieldOfficerAssignmentsScreen(),
        scale: 1.8,
        overrides: [
          mobileRepositoryProvider.overrideWithValue(SchedulingRepository()),
        ],
        role: AppRole.fieldOfficer,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Schedule duty'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Create assignments'), findsOneWidget);
    expectRenderedInFull(tester, find.text('Create assignments'));
  });
  testWidgets('willingness sheet holds and stays readable at 1.8 text', (
    tester,
  ) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: Scaffold(
          body: WorkOrderWillingnessSheet(workOrderId: 'e1', onSelect: (_) {}),
        ),
        scale: 1.8,
        overrides: [
          mobileRepositoryProvider.overrideWithValue(SchedulingRepository()),
        ],
        role: AppRole.fieldOfficer,
      ),
    );
    await tester.pumpAndSettle();
    final sheetContext = tester.element(find.byType(WorkOrderWillingnessSheet));
    await ProviderScope.containerOf(
      sheetContext,
    ).read(authSessionProvider.future);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Unavailable guards can still be assigned manually.'),
      findsOneWidget,
    );
    expect(find.text('Review exam roster'), findsOneWidget);
  });
}
