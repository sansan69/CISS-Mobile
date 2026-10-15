import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/offline/willingness_queue.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'support/guard_redesign_fixtures.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'duty_willingness_queue_test.dart' show MemoryStore;

class Session extends AuthSessionNotifier {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    role: AppRole.guard,
    displayName: 'Guard',
    primaryId: 'CISS/A',
    uid: 'auth-a',
    employeeDocId: 'employee-doc-a',
  );
  void publish(String uid) {
    state = AsyncData(
      AuthSession(
        role: AppRole.guard,
        displayName: 'Guard',
        primaryId: 'CISS/A',
        uid: uid,
      ),
    );
  }
}

class FieldOfficerSession extends AuthSessionNotifier {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    role: AppRole.fieldOfficer,
    displayName: 'Officer',
    primaryId: 'FO-1',
    uid: 'auth-a',
    employeeDocId: 'employee-doc-a',
  );
}

class DutyRepo extends NoNetworkRepository {
  String uid = 'auth-a';
  final sent = <String>[];
  Object? failWith;
  @override
  User? get currentUser => DutyUser(uid);
  @override
  String get dutyApiBaseUrl => 'https://a.invalid';
  @override
  Future<WillingnessReceipt> setDutyWillingness({
    required String workOrderId,
    required WillingnessStatus response,
    required String clientRequestId,
    required int expectedVersion,
    String? expectedOwnerUid,
    String? expectedApiBaseUrl,
    Future<bool> Function()? isCurrentOperation,
  }) async {
    sent.add(clientRequestId);
    final failure = failWith;
    if (failure != null) throw failure;
    return WillingnessReceipt(response: response, version: expectedVersion + 1);
  }
}

class ThrowingStore implements WillingnessStore {
  @override
  Future<List<Map<String, dynamic>>> read() async => [];
  @override
  Future<void> write(List<Map<String, dynamic>> rows) async =>
      throw StateError('duty spool unavailable');
}

class DutyUser implements User {
  DutyUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

GuardDuty fixture() => GuardDuty.fromJson({
  'id': 'e1',
  'workOrderId': 'e1',
  'kind': 'exam',
  'status': 'open',
  'canRespond': true,
  'willingnessVersion': 1,
});
DioException businessFailure(int status, Map<String, dynamic> data) =>
    DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: status,
        data: data,
      ),
    );
ProviderContainer containerFor(
  DutyRepo repo,
  WillingnessQueue queue, {
  List<Override> extra = const <Override>[],
}) {
  final current = fixture();
  return ProviderContainer(
    overrides: [
      remoteConfigProvider.overrideWith(() => FixedConfig()),
      authSessionProvider.overrideWith(Session.new),
      mobileRepositoryProvider.overrideWithValue(repo),
      willingnessQueueProvider.overrideWith((ref) => queue),
      guardDutiesProvider.overrideWith((ref) async => [current]),
      ...extra,
    ],
  );
}

void main() {
  test(
    'rejects stale feed object before enqueue on account/deployment refresh',
    () async {
      final repo = DutyRepo();
      final queue = WillingnessQueue(MemoryStore());
      final current = fixture();
      final container = ProviderContainer(
        overrides: [
          remoteConfigProvider.overrideWith(() => FixedConfig()),
          authSessionProvider.overrideWith(Session.new),
          mobileRepositoryProvider.overrideWithValue(repo),
          willingnessQueueProvider.overrideWith((ref) => queue),
          guardDutiesProvider.overrideWith((ref) async => [current]),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authSessionProvider.future);
      await container.read(guardDutiesProvider.future);
      await expectLater(
        container
            .read(dutyWillingnessControllerProvider)
            .choose(fixture(), WillingnessStatus.willing),
        throwsA(isA<StateError>()),
      );
      expect(repo.sent, isEmpty);
      expect(queue.forOwner('auth-a', 'https://a.invalid'), isEmpty);
    },
  );
  test(
    'server receipt creates saved state while owner switch hides it',
    () async {
      final repo = DutyRepo();
      final queue = WillingnessQueue(MemoryStore());
      final current = fixture();
      final container = ProviderContainer(
        overrides: [
          remoteConfigProvider.overrideWith(() => FixedConfig()),
          authSessionProvider.overrideWith(Session.new),
          mobileRepositoryProvider.overrideWithValue(repo),
          willingnessQueueProvider.overrideWith((ref) => queue),
          guardDutiesProvider.overrideWith((ref) async => [current]),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authSessionProvider.future);
      await container.read(guardDutiesProvider.future);
      await container
          .read(dutyWillingnessControllerProvider)
          .choose(current, WillingnessStatus.willing);
      expect(container.read(dutyResponseProvider('e1'))?.state, 'saved');
      (container.read(authSessionProvider.notifier) as Session).publish(
        'auth-b',
      );
      repo.uid = 'auth-b';
      await container.pump();
      expect(container.read(dutyResponseProvider('e1')), null);
      expect(
        queue.forOwner('auth-a', 'https://a.invalid').single.state,
        'saved',
      );
    },
  );

  test('transport failure stays pending and never claims saved', () async {
    final repo =
        DutyRepo()
          ..failWith = DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          );
    final queue = WillingnessQueue(MemoryStore());
    final container = containerFor(repo, queue);
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);
    final current = (await container.read(guardDutiesProvider.future)).single;
    await container
        .read(dutyWillingnessControllerProvider)
        .choose(current, WillingnessStatus.willing);
    final response = container.read(dutyResponseProvider('e1'));
    expect(repo.sent, hasLength(1));
    expect(response?.state, 'pending');
    expect(response?.reason, contains('not saved'));
  });

  test(
    'terminal business rejection is visible with the server answer',
    () async {
      final repo =
          DutyRepo()
            ..failWith = businessFailure(409, {
              'code': 'version_conflict',
              'error': 'Duty closed',
              'willingness': {'response': 'unavailable', 'version': 7},
            });
      final queue = WillingnessQueue(MemoryStore());
      final container = containerFor(repo, queue);
      addTearDown(container.dispose);
      await container.read(authSessionProvider.future);
      final current = (await container.read(guardDutiesProvider.future)).single;
      await container
          .read(dutyWillingnessControllerProvider)
          .choose(current, WillingnessStatus.willing);
      final response = container.read(dutyResponseProvider('e1'));
      expect(response?.state, 'rejected');
      expect(response?.reason, 'Duty closed');
      expect(response?.serverVersion, 7);
      expect(response?.serverResponse, WillingnessStatus.unavailable);
    },
  );

  test('durable spool failure never queues or reports a response', () async {
    final repo = DutyRepo();
    final queue = WillingnessQueue(ThrowingStore());
    final container = containerFor(repo, queue);
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);
    final current = (await container.read(guardDutiesProvider.future)).single;
    await expectLater(
      container
          .read(dutyWillingnessControllerProvider)
          .choose(current, WillingnessStatus.willing),
      throwsA(isA<StateError>()),
    );
    expect(queue.forOwner('auth-a', 'https://a.invalid'), isEmpty);
    expect(container.read(dutyResponseProvider('e1')), null);
    expect(repo.sent, isEmpty);
  });

  test('field officer session cannot queue a guard response', () async {
    final repo = DutyRepo();
    final queue = WillingnessQueue(MemoryStore());
    final container = ProviderContainer(
      overrides: [
        remoteConfigProvider.overrideWith(() => FixedConfig()),
        authSessionProvider.overrideWith(FieldOfficerSession.new),
        mobileRepositoryProvider.overrideWithValue(repo),
        willingnessQueueProvider.overrideWith((ref) => queue),
        guardDutiesProvider.overrideWith((ref) async => [fixture()]),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);
    final current = (await container.read(guardDutiesProvider.future)).single;
    await expectLater(
      container
          .read(dutyWillingnessControllerProvider)
          .choose(current, WillingnessStatus.willing),
      throwsA(isA<StateError>()),
    );
    expect(repo.sent, isEmpty);
    expect(queue.forOwner('auth-a', 'https://a.invalid'), isEmpty);
  });

  test('workOrders off keeps a response out of the spool', () async {
    final repo = DutyRepo();
    final queue = WillingnessQueue(MemoryStore());
    final container = containerFor(
      repo,
      queue,
      extra: [
        remoteConfigProvider.overrideWith(
          () => FixedConfig({'workOrders': false}),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);
    final current = (await container.read(guardDutiesProvider.future)).single;
    await expectLater(
      container
          .read(dutyWillingnessControllerProvider)
          .choose(current, WillingnessStatus.willing),
      throwsA(isA<StateError>()),
    );
    expect(repo.sent, isEmpty);
    expect(queue.forOwner('auth-a', 'https://a.invalid'), isEmpty);
  });
}
