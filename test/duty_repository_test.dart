import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';

class Auth implements FirebaseAuth {
  @override
  User? get currentUser => TestUser();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestUser implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'local-test-token';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class Region implements RegionService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('willingness sends exactly frozen body and returns receipt', () async {
    final client = ApiClient(
      baseUrl: 'https://test.invalid',
      authTokenProvider: () async => null,
    );
    RequestOptions? sent;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent = o;
          h.resolve(
            Response(
              requestOptions: o,
              data: {
                'success': true,
                'willingness': {'response': 'willing', 'version': 3},
                'replayed': true,
              },
            ),
          );
        },
      ),
    );
    final dynamic repo = MobileRepository(client, Auth(), Region());
    final WillingnessReceipt result = await repo.setDutyWillingness(
      workOrderId: 'exam-1',
      response: WillingnessStatus.willing,
      clientRequestId: 'uuid',
      expectedVersion: 2,
    );
    expect(sent!.path, '/api/guard/duties/exam-1/willingness');
    expect(sent!.data, {
      'response': 'willing',
      'clientRequestId': 'uuid',
      'expectedVersion': 2,
    });
    expect(result.version, 3);
    expect(result.replayed, true);
  });
  test(
    'business HTTP failure retains status and structured response',
    () async {
      final client = ApiClient(
        baseUrl: 'https://test.invalid',
        authTokenProvider: () async => null,
      );
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (o, h) => h.reject(
                DioException(
                  requestOptions: o,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: o,
                    statusCode: 409,
                    data: {
                      'code': 'version_conflict',
                      'error': 'Changed elsewhere',
                    },
                  ),
                ),
              ),
        ),
      );
      final dynamic repo = MobileRepository(client, Auth(), Region());
      await expectLater(
        repo.setDutyWillingness(
          workOrderId: 'exam-1',
          response: WillingnessStatus.willing,
          clientRequestId: 'uuid',
          expectedVersion: 2,
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
    },
  );
  test('guard feed and FO scoped assignments use API DTOs', () async {
    final client = ApiClient(
      baseUrl: 'https://test.invalid',
      authTokenProvider: () async => null,
    );
    final paths = <String>[];
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          paths.add(o.path);
          h.resolve(
            Response(
              requestOptions: o,
              data: {
                'duties': [
                  {
                    'id': 'e1',
                    'kind': 'exam',
                    'status': 'open',
                    'canRespond': true,
                    'willingnessVersion': 2,
                  },
                ],
                'assignments': [
                  {'id': 'a1', 'version': 1},
                ],
              },
            ),
          );
        },
      ),
    );
    final dynamic repo = MobileRepository(client, Auth(), Region());
    expect((await repo.fetchGuardDuties()).single.canRespond, true);
    expect((await repo.fetchGuardAssignments()).single.id, 'a1');
    expect(paths, ['/api/guard/duties', '/api/field-officer/assignments']);
  });

  test('assignment create and update send the frozen body only', () async {
    final client = ApiClient(
      baseUrl: 'https://test.invalid',
      authTokenProvider: () async => null,
    );
    final sent = <RequestOptions>[];
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          h.resolve(
            Response(
              requestOptions: o,
              data: {
                'assignment': {
                  'id': 'a1',
                  'version': o.method == 'POST' ? 1 : 2,
                  'status':
                      o.data is Map
                          ? o.data['status'] ?? 'assigned'
                          : 'assigned',
                },
              },
            ),
          );
        },
      ),
    );
    final dynamic repo = MobileRepository(client, Auth(), Region());
    final created = await repo.createGuardAssignment({
      'employeeDocId': 'employee-doc-a',
      'siteId': 's1',
      'date': '2026-10-20',
      'shiftLabel': 'Night',
      'startTime': '22:00',
      'endTime': '06:00',
      'crossesMidnight': true,
      'type': 'relieving',
      'clientRequestId': 'uuid-1',
    });
    expect(sent.last.path, '/api/field-officer/assignments');
    expect(sent.last.method, 'POST');
    expect(sent.last.data, {
      'employeeDocId': 'employee-doc-a',
      'siteId': 's1',
      'date': '2026-10-20',
      'shiftLabel': 'Night',
      'startTime': '22:00',
      'endTime': '06:00',
      'crossesMidnight': true,
      'type': 'relieving',
      'clientRequestId': 'uuid-1',
    });
    expect(created.version, 1);
    final updated = await repo.updateGuardAssignment('a1', {
      'expectedVersion': 1,
      'clientRequestId': 'uuid-2',
      'status': 'cancelled',
    });
    expect(sent.last.path, '/api/field-officer/assignments/a1');
    expect(sent.last.method, 'PATCH');
    expect(sent.last.data, {
      'expectedVersion': 1,
      'clientRequestId': 'uuid-2',
      'status': 'cancelled',
    });
    expect(updated.status, 'cancelled');
    expect(updated.version, 2);
  });

  test('willingness list decodes scoped counts and responses', () async {
    final client = ApiClient(
      baseUrl: 'https://test.invalid',
      authTokenProvider: () async => null,
    );
    RequestOptions? sent;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent = o;
          h.resolve(
            Response(
              requestOptions: o,
              data: {
                'workOrderId': 'exam-1',
                'willingCount': 2,
                'unavailableCount': 1,
                'responses': [
                  {
                    'employeeDocId': 'employee-doc-a',
                    'employeeId': 'CISS/A',
                    'name': 'Guard a',
                    'gender': 'Male',
                    'tcsCategory': 'adhoc',
                    'response': 'willing',
                    'version': 3,
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final dynamic repo = MobileRepository(client, Auth(), Region());
    final dynamic value = await repo.fetchWorkOrderWillingness('exam-1');
    expect(sent!.path, '/api/field-officer/work-orders/exam-1/willingness');
    expect(value.workOrderId, 'exam-1');
    expect(value.willingCount, 2);
    expect(value.unavailableCount, 1);
    expect(value.responses.single['employeeDocId'], 'employee-doc-a');
  });

  test(
    'guard feed tolerates unknown keys and fails closed on closed duties',
    () async {
      final duty = GuardDuty.fromJson({
        'id': 'e1',
        'kind': 'exam',
        'status': 'cancelled',
        'canRespond': true,
        'willingnessVersion': 4,
        'phone': '9999999999',
        'guards': [
          {'name': 'Other guard', 'phone': '8888888888'},
        ],
        'importProvenance': 'biometric.xlsx',
      });
      expect(duty.canRespond, false);
      expect(duty.status, 'cancelled');
      expect(duty.siteName, '');
      final exposed = <Object?>[
        duty.id,
        duty.clientName,
        duty.siteName,
        duty.date,
        duty.shiftLabel,
        duty.examName,
        duty.siteId,
        duty.district,
        duty.status,
        duty.startsAt,
        duty.endsAt,
        duty.workOrderId,
        duty.examCode,
        duty.respondBy,
        duty.ineligibilityReason,
        duty.willingness,
        duty.kind,
        duty.relieving,
      ];
      expect(
        exposed.whereType<String>().any(
          (value) => value.contains('9999999999'),
        ),
        false,
      );
      final assigned = GuardDuty.fromJson({
        'id': 'a1',
        'kind': 'assigned',
        'status': 'assigned',
        'canRespond': true,
      });
      expect(assigned.canRespond, false);
    },
  );
}
