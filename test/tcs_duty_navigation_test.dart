import 'package:ciss_mobile/core/fcm/duty_notification_destination.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/models/report_models.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/widgets/work_order_willingness_sheet.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/features/guard/presentation/widgets/duty_detail_sheet.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

/// Notification navigation for duty records: the destination resolves per
/// owner/role, and the screen it opens must land on that exact record.
class DutyRepository extends NoNetworkRepository {
  @override
  Future<List<WorkOrderModel>> fetchFieldOfficerWorkOrders() async =>
      <WorkOrderModel>[
        const WorkOrderModel(
          id: 'exam-1',
          siteId: 's1',
          siteName: 'District examination centre',
          clientId: 'c1',
          clientName: 'TCS',
          district: 'Ernakulam',
          examName: 'Graduate examination',
          examCode: 'GE-1',
          dateLabel: '20 Oct 2026',
          totalManpowerLabel: '10',
          totalManpower: 10,
          assignedCount: 2,
        ),
      ];

  @override
  Future<WorkOrderWillingness> fetchWorkOrderWillingness(String id) async =>
      WorkOrderWillingness(
        workOrderId: id,
        willingCount: 1,
        unavailableCount: 0,
        responses: <Map<String, dynamic>>[
          <String, dynamic>{
            'employeeDocId': 'employee-doc-a',
            'employeeName': 'Guard a',
            'response': 'willing',
          },
        ],
      );
}

GuardDuty duty() => GuardDuty.fromJson(<String, dynamic>{
  'id': 'exam-1',
  'kind': 'exam',
  'status': 'open',
  'workOrderId': 'exam-1',
  'siteName': 'District examination centre',
  'examName': 'Graduate examination',
  'date': '2026-10-20',
  'canRespond': true,
  'willingnessVersion': 1,
});

AuthSession guardSession() => const AuthSession(
  role: AppRole.guard,
  displayName: 'Guard',
  primaryId: 'CISS/A',
  uid: 'auth-a',
  employeeDocId: 'employee-doc-a',
);
AuthSession officerSession() => const AuthSession(
  role: AppRole.fieldOfficer,
  displayName: 'Officer',
  primaryId: 'FO-1',
  uid: 'auth-a',
  employeeDocId: 'employee-doc-a',
);

const Map<String, dynamic> guardPayload = <String, dynamic>{
  'type': 'duty_assigned',
  'recipientUid': 'auth-a',
  'recipientRole': 'guard',
  'assignmentId': 'exam-1',
};

const Map<String, dynamic> willingnessPayload = <String, dynamic>{
  'routeKind': 'work_order_willingness',
  'recipientUid': 'auth-a',
  'recipientRole': 'fieldOfficer',
  'workOrderId': 'exam-1',
};

void main() {
  testWidgets('guard duty notification opens that record from a cold start', (
    tester,
  ) async {
    final destination = DutyNotificationDestination.resolve(
      guardPayload,
      guardSession(),
    );
    expect(destination?.role, AppRole.guard);
    await tester.pumpWidget(
      guardTestApp(
        screen: GuardDutiesScreen(initialDutyId: destination!.recordId),
        overrides: <Override>[
          mobileRepositoryProvider.overrideWithValue(DutyRepository()),
          guardDutiesProvider.overrideWith((ref) async => <GuardDuty>[duty()]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DutyDetailSheet), findsOneWidget);
    expect(find.text('Graduate examination'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown duty record explains itself and opens nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(initialDutyId: 'exam-404'),
        overrides: <Override>[
          mobileRepositoryProvider.overrideWithValue(DutyRepository()),
          guardDutiesProvider.overrideWith((ref) async => <GuardDuty>[duty()]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DutyDetailSheet), findsNothing);
    expect(find.text('Duty no longer available'), findsOneWidget);
  });

  testWidgets(
    'field officer willingness notification opens the scoped work order',
    (tester) async {
      final destination = DutyNotificationDestination.resolve(
        willingnessPayload,
        officerSession(),
      );
      expect(destination?.role, AppRole.fieldOfficer);
      await tester.pumpWidget(
        guardTestApp(
          screen: FieldOfficerWorkOrdersScreen(
            initialWorkOrderId: destination!.recordId,
          ),
          overrides: <Override>[
            mobileRepositoryProvider.overrideWithValue(DutyRepository()),
          ],
          role: AppRole.fieldOfficer,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkOrderWillingnessSheet), findsOneWidget);
      expect(find.text('1 willing · 0 unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown work order explains itself and opens nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      guardTestApp(
        screen: const FieldOfficerWorkOrdersScreen(
          initialWorkOrderId: 'exam-404',
        ),
        overrides: <Override>[
          mobileRepositoryProvider.overrideWithValue(DutyRepository()),
        ],
        role: AppRole.fieldOfficer,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkOrderWillingnessSheet), findsNothing);
    expect(find.text('Work order no longer available'), findsOneWidget);
  });

  testWidgets('a duty payload never routes under the wrong active role', (
    tester,
  ) async {
    expect(
      DutyNotificationDestination.resolve(guardPayload, officerSession()),
      isNull,
    );
    expect(
      DutyNotificationDestination.resolve(willingnessPayload, guardSession()),
      isNull,
    );
    expect(DutyNotificationDestination.resolve(guardPayload, null), isNull);
  });

  test('guard profile provider is not required for the duty feed', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        mobileRepositoryProvider.overrideWithValue(DutyRepository()),
        guardDutiesProvider.overrideWith((ref) async => <GuardDuty>[duty()]),
        guardProfileProvider.overrideWith(
          (ref) async => throw StateError('profile unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(guardDutiesProvider.future)).single.workOrderId,
      'exam-1',
    );
    await expectLater(
      container.read(guardProfileProvider.future),
      throwsA(isA<StateError>()),
    );
  });
}
