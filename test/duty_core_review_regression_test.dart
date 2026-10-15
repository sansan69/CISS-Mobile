import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/offline/willingness_queue.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_profile_screen.dart';
import 'support/guard_redesign_fixtures.dart';
import 'support/duty_core_review_support.dart';

class SwitchAdapter implements HttpClientAdapter {
  SwitchAdapter(this.auth);
  final Auth auth;
  final sent = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? cancel,
  ) async {
    sent.add(o.headers['Authorization'].toString());
    final first = sent.length == 1;
    if (first) auth.uid = 'auth-b';
    return ResponseBody.fromString(
      jsonEncode(
        first
            ? {'error': 'Expired token'}
            : {
              'success': true,
              'willingness': {'response': 'willing', 'version': 1},
            },
      ),
      first ? 401 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('A willingness must not retry using B token after a 401', () async {
    final auth = Auth();
    final client = ApiClient(
      baseUrl: 'https://a.invalid',
      authTokenProvider: () => auth.currentUser!.getIdToken(),
      authTokenRefreshProvider: () => auth.currentUser!.getIdToken(true),
    );
    final adapter = SwitchAdapter(auth);
    client.dio.httpClientAdapter = adapter;
    final repo = MobileRepository(client, auth, Region());
    final q = WillingnessQueue(Store());
    final operation = await q.choose(
      ownerUid: 'auth-a',
      apiBaseUrl: 'https://a.invalid',
      workOrderId: 'exam-1',
      response: WillingnessStatus.willing,
      expectedVersion: 0,
    );
    await q.process(
      owner: () => auth.uid,
      origin: () => repo.dutyApiBaseUrl,
      send:
          (op) => repo.setDutyWillingness(
            workOrderId: op.workOrderId,
            response: op.response,
            clientRequestId: op.id,
            expectedVersion: op.expectedVersion,
            expectedOwnerUid: op.ownerUid,
            expectedApiBaseUrl: op.apiBaseUrl,
          ),
    );
    expect(adapter.sent, ['Bearer token-auth-a']);
    final result = q.forOwner('auth-a', 'https://a.invalid').single;
    expect(result.id, operation.id);
    expect(result.body, operation.body);
    expect(result.state, 'pending');
    expect(result.reason, contains('deployment changed'));
  });
  test(
    'identity change while acquiring the first token never dispatches',
    () async {
      final auth = Auth();
      final token = Completer<String?>();
      final client = ApiClient(
        baseUrl: 'https://a.invalid',
        authTokenProvider: () => token.future,
      );
      final adapter = SwitchAdapter(auth);
      client.dio.httpClientAdapter = adapter;
      final request = client.dio.post<dynamic>(
        '/api/guard/duties/exam-1/willingness',
        data: {
          'response': 'willing',
          'clientRequestId': 'stable-id',
          'expectedVersion': 0,
        },
        options: Options(
          extra: {kApiRequestIdentityGuard: () async => auth.uid == 'auth-a'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      auth.uid = 'auth-b';
      token.complete('token-auth-a');
      await expectLater(
        request,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(adapter.sent, isEmpty);
    },
  );
  test(
    'successfully synced duties must not exhaust runnable spool capacity',
    () async {
      final q = WillingnessQueue(Store());
      for (var i = 0; i < WillingnessQueue.capacity; i++) {
        await q.choose(
          ownerUid: 'auth-a',
          apiBaseUrl: 'https://a.invalid',
          workOrderId: 'exam-$i',
          response: WillingnessStatus.willing,
          expectedVersion: 0,
        );
      }
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send:
            (op) async => WillingnessReceipt(response: op.response, version: 1),
      );
      await expectLater(
        q.choose(
          ownerUid: 'auth-a',
          apiBaseUrl: 'https://a.invalid',
          workOrderId: 'new-exam',
          response: WillingnessStatus.willing,
          expectedVersion: 0,
        ),
        completes,
      );
      expect(
        q
            .forOwner('auth-a', 'https://a.invalid')
            .where((r) => r.state == 'saved'),
        hasLength(WillingnessQueue.savedHistoryCapacity),
      );
      expect(
        q
            .forOwner('auth-a', 'https://a.invalid')
            .where((r) => r.state == 'pending'),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'terminal cancelled duty rejection remains visible when feed removes duty',
    (tester) async {
      final q = WillingnessQueue(Store());
      await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://a.invalid',
        workOrderId: 'cancelled-exam',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      );
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send:
            (op) async =>
                throw DioException(
                  requestOptions: RequestOptions(path: ''),
                  response: Response(
                    requestOptions: RequestOptions(path: ''),
                    statusCode: 409,
                    data: {'error': 'Duty cancelled', 'code': 'duty_closed'},
                  ),
                ),
      );
      await tester.pumpWidget(
        guardTestApp(
          screen: const GuardDutiesScreen(),
          overrides: [
            mobileRepositoryProvider.overrideWithValue(Repo()),
            authSessionProvider.overrideWith(Session.new),
            guardProfileProvider.overrideWith(
              (ref) async => throw StateError('no profile'),
            ),
            guardDutiesProvider.overrideWith((ref) async => []),
            willingnessQueueProvider.overrideWith((ref) => q),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Response not sent'), findsOneWidget);
      expect(find.text('Duty cancelled'), findsOneWidget);
      expect(find.text('Refresh duties'), findsOneWidget);
      await tester.tap(find.text('Refresh duties'));
      await tester.pumpAndSettle();
      expect(
        q.forOwner('auth-a', 'https://a.invalid').single.state,
        'rejected',
      );
    },
  );

  testWidgets(
    'pending result remains visible and scoped when duty feed fails',
    (tester) async {
      final q = WillingnessQueue(Store());
      await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://a.invalid',
        workOrderId: 'pending-exam',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      );
      await q.choose(
        ownerUid: 'auth-b',
        apiBaseUrl: 'https://a.invalid',
        workOrderId: 'other-owner-exam',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      );
      await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://b.invalid',
        workOrderId: 'other-origin-exam',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      );
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send:
            (op) async =>
                throw DioException(
                  requestOptions: RequestOptions(path: ''),
                  type: DioExceptionType.connectionError,
                ),
      );
      await tester.pumpWidget(
        guardTestApp(
          screen: const GuardDutiesScreen(),
          overrides: [
            mobileRepositoryProvider.overrideWithValue(Repo()),
            authSessionProvider.overrideWith(Session.new),
            guardProfileProvider.overrideWith(
              (ref) async => throw StateError('no profile'),
            ),
            guardDutiesProvider.overrideWith(
              (ref) async => throw StateError('feed offline'),
            ),
            willingnessQueueProvider.overrideWith((ref) => q),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Response pending'), findsOneWidget);
      expect(find.textContaining('not saved yet'), findsOneWidget);
      expect(find.text('Sync pending response'), findsOneWidget);
      expect(find.text('Refresh duties'), findsOneWidget);
    },
  );
}
