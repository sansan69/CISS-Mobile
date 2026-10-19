import 'dart:convert';
import 'dart:io';

import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/sync/sync_service.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'support/guard_redesign_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService.chunked', () {
    test('splits a large batch into size-capped chunks', () {
      final items = List<int>.generate(500, (i) => i);
      final chunks = SyncService.chunked(items, 200).toList();
      expect(chunks.map((c) => c.length).toList(), [200, 200, 100]);
      expect(chunks.first.first, 0);
      expect(chunks.last.last, 499);
    });

    test('returns a single chunk when the batch fits', () {
      final chunks = SyncService.chunked([1, 2, 3], 200).toList();
      expect(chunks, [
        [1, 2, 3],
      ]);
    });

    test('returns nothing for an empty batch', () {
      expect(SyncService.chunked(const <int>[], 200), isEmpty);
    });
  });

  Future<OfflineQueue> boundQueue({String owner = 'guard-a'}) async {
    final queue = OfflineQueue();
    await queue.init();
    queue.bindIdentity(
      () async => OfflineQueueIdentity(
        ownerUid: owner,
        origin: 'https://cisskerala.site',
      ),
    );
    return queue;
  }

  /// Task 5 hand-off: the durable willingness spool is drained by the sync
  /// service, but generic attendance/photo/tracking behaviour must be
  /// untouched — nothing new is evicted, reordered or given up on.
  group('SyncService duty willingness hand-off', () {
    late Directory folder;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('ciss-sync-');
      Hive.init(folder.path);
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'read'
                    ? base64UrlEncode(List<int>.filled(32, 7))
                    : null,
          );
      addTearDown(() async {
        await Hive.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await folder.delete(recursive: true);
      });
    });

    test(
      'retry deadlines preserve order, never evict, and replay uses one identity',
      () async {
        final queue = await boundQueue();
        for (var i = 0; i < 2; i++) {
          await queue.enqueue(
            path: '/test',
            method: 'POST',
            body: {'order': i},
          );
        }
        final first = queue.getQueuedRequests().first;
        await queue.updateRequest(first.copyWith(retryCount: 25));
        var now = DateTime.utc(2026, 10, 18);
        final recorder = RecordingAdapter(status: 503);
        final client = ApiClient(
          baseUrl: 'https://cisskerala.site',
          authTokenProvider: () async => 'token',
        );
        client.dio.httpClientAdapter = recorder;
        final service = SyncService(
          RecordingRepository(client),
          queue,
          TrackingBuffer(),
          now: () => now,
          jitter: () => 0.5,
        );
        await service.processQueue();
        expect(recorder.sent, hasLength(1));
        expect(queue.getQueuedRequests().first.retryCount, 26);
        await service.processQueue();
        expect(recorder.sent, hasLength(1));
        now = now.add(const Duration(minutes: 6));
        recorder.status = 200;
        await service.processQueue();
        expect(recorder.sent, hasLength(3));
        expect(queue.getQueuedRequests(), isEmpty);
        expect(queue.lastAcknowledgedAt, now);
        await service.processQueue();
        expect(recorder.sent, hasLength(3));
      },
    );

    test(
      'jitter stays bounded and terminal rejection stays reviewable',
      () async {
        expect(SyncService.retryDelay(2, 0), const Duration(seconds: 2));
        expect(SyncService.retryDelay(2, 1), const Duration(seconds: 6));
        final queue = await boundQueue();
        await queue.enqueue(path: '/test', method: 'POST', body: {});
        final client = ApiClient(
          baseUrl: 'https://cisskerala.site',
          authTokenProvider: () async => 'token',
        );
        final recorder = RecordingAdapter(status: 409);
        client.dio.httpClientAdapter = recorder;
        final service = SyncService(
          RecordingRepository(client),
          queue,
          TrackingBuffer(),
        );
        await service.processQueue();
        await service.processQueue();
        expect(recorder.sent, hasLength(1));
        expect(queue.rejectedCount, 1);
      },
    );

    test('attendance retry on site A blocks site B and break stop', () async {
      final queue = await boundQueue();
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {
          'employeeDocId': 'employee-a',
          'siteId': 'site-a',
          'status': 'In',
        },
      );
      final first = queue.getQueuedRequests().first;
      await queue.updateRequest(
        first.copyWith(
          nextAttemptAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {
          'employeeDocId': 'employee-a',
          'siteId': 'site-b',
          'status': 'Out',
        },
      );
      await queue.enqueue(
        path: '/api/mobile/attendance/break',
        method: 'POST',
        body: {'action': 'stop'},
      );
      final client = ApiClient(
        baseUrl: 'https://cisskerala.site',
        authTokenProvider: () async => 'token',
      );
      final recorder = RecordingAdapter();
      client.dio.httpClientAdapter = recorder;
      await SyncService(
        RecordingRepository(client),
        queue,
        TrackingBuffer(),
      ).processQueue();

      expect(recorder.sent, isEmpty);
    });

    test('break stop retry blocks a later attendance out', () async {
      final queue = await boundQueue();
      await queue.enqueue(
        path: '/api/mobile/attendance/break',
        method: 'POST',
        body: {'action': 'stop'},
      );
      final first = queue.getQueuedRequests().first;
      await queue.updateRequest(
        first.copyWith(
          nextAttemptAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {
          'employeeDocId': 'employee-a',
          'siteId': 'site-b',
          'status': 'Out',
        },
      );
      final client = ApiClient(
        baseUrl: 'https://cisskerala.site',
        authTokenProvider: () async => 'token',
      );
      final recorder = RecordingAdapter();
      client.dio.httpClientAdapter = recorder;
      await SyncService(
        RecordingRepository(client),
        queue,
        TrackingBuffer(),
      ).processQueue();

      expect(recorder.sent, isEmpty);
    });

    test(
      'photo replay keeps the capture attempt and persists upload before HTTP retry',
      () async {
        final queue = await boundQueue();
        await queue.enqueue(
          path: '/api/attendance/submit',
          method: 'POST',
          body: {
            'employeeDocId': 'g1',
            'siteId': 's1',
            'attendanceAttemptId': 'capture-1',
            'photoDataUrl': 'data:image/jpeg;base64,AA==',
          },
        );
        final client = ApiClient(
          baseUrl: 'https://cisskerala.site',
          authTokenProvider: () async => 'token',
        );
        final adapter = RecordingAdapter(status: 503);
        client.dio.httpClientAdapter = adapter;
        final repo = PhotoRepository(client);
        var now = DateTime.utc(2026, 10, 18);
        final service = SyncService(
          repo,
          queue,
          TrackingBuffer(),
          now: () => now,
          jitter: () => 0.5,
        );
        await service.processQueue();
        expect(repo.attempts, ['capture-1']);
        expect(
          queue.getQueuedRequests().single.body.containsKey('photoDataUrl'),
          isFalse,
        );
        expect(
          queue.getQueuedRequests().single.body['photoStoragePath'],
          'employees/g1/attendance/capture-1/photo.jpg',
        );
        adapter.status = 200;
        now = now.add(const Duration(minutes: 6));
        await service.processQueue();
        expect(repo.attempts, ['capture-1']);
        expect(queue.pendingCount, 0);
      },
    );

    test('replay reuses an already uploaded photo URL', () async {
      final queue = await boundQueue();
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {
          'employeeDocId': 'g1',
          'siteId': 's1',
          'attendanceAttemptId': 'capture-1',
          'photoUrl': 'https://storage.example/already-uploaded.jpg',
          'photoStoragePath': 'employees/g1/attendance/capture-1/photo.jpg',
          'photoDataUrl': 'data:image/jpeg;base64,AA==',
        },
      );
      final client = ApiClient(
        baseUrl: 'https://cisskerala.site',
        authTokenProvider: () async => 'token',
      );
      final adapter = RecordingAdapter();
      client.dio.httpClientAdapter = adapter;
      final repo = PhotoRepository(client);
      await SyncService(repo, queue, TrackingBuffer()).processQueue();

      expect(repo.attempts, isEmpty);
      expect(adapter.sent, hasLength(1));
      final body = adapter.sent.single.data as Map<String, dynamic>;
      expect(body['photoUrl'], 'https://storage.example/already-uploaded.jpg');
      expect(
        body['photoStoragePath'],
        'employees/g1/attendance/capture-1/photo.jpg',
      );
      expect(body.containsKey('photoDataUrl'), isFalse);
      expect(queue.pendingCount, 0);
    });

    test(
      'runs the duty hand-off before generic requests and keeps attendance queued',
      () async {
        final order = <String>[];
        final queue = await boundQueue();
        await queue.enqueue(
          path: '/api/attendance/submit',
          method: 'POST',
          body: <String, dynamic>{
            'employeeDocId': 'employee-doc-a',
            'siteId': 'site-a',
          },
        );
        final queuedId = queue.getQueuedRequests().single.id;
        final service = SyncService(
          MarkerRepository(order),
          queue,
          TrackingBuffer(),
          syncWillingness: () async => order.add('duty'),
        );

        await service.processQueue();

        expect(order, <String>['duty', 'generic-request']);
        expect(queue.getQueuedRequests().single.id, queuedId);
        expect(queue.getQueuedRequests().single.path, '/api/attendance/submit');
      },
    );

    test(
      'a failing duty hand-off does not drop or skip the generic queue',
      () async {
        final order = <String>[];
        final queue = await boundQueue();
        await queue.enqueue(
          path: '/api/attendance/submit',
          method: 'POST',
          body: <String, dynamic>{'employeeDocId': 'employee-doc-a'},
        );
        final queuedId = queue.getQueuedRequests().single.id;
        final service = SyncService(
          MarkerRepository(order),
          queue,
          TrackingBuffer(),
          syncWillingness:
              () async => throw StateError('duty spool unavailable'),
        );

        await service.processQueue();

        expect(order, <String>['generic-request']);
        final remaining = queue.getQueuedRequests();
        expect(remaining.single.id, queuedId);
        expect(remaining.single.retryCount, 1);
      },
    );

    test('duty hand-off alone leaves an empty generic queue empty', () async {
      var handoffs = 0;
      final queue = OfflineQueue();
      await queue.init();
      final service = SyncService(
        MarkerRepository(<String>[]),
        queue,
        TrackingBuffer(),
        syncWillingness: () async => handoffs++,
      );

      await service.processQueue();

      expect(handoffs, 1);
      expect(queue.getQueuedRequests(), isEmpty);
    });

    test(
      'legacy construction without the duty hook still drains the generic queue',
      () async {
        final order = <String>[];
        final queue = await boundQueue();
        await queue.enqueue(
          path: '/api/attendance/submit',
          method: 'POST',
          body: <String, dynamic>{'employeeDocId': 'employee-doc-a'},
        );
        final service = SyncService(
          MarkerRepository(order),
          queue,
          TrackingBuffer(),
        );

        await service.processQueue();

        expect(order, <String>['generic-request']);
        expect(queue.getQueuedRequests(), hasLength(1));
      },
    );
  });

  /// The spool file outlives logout and the account that wrote it, so a flush
  /// must only ever deliver the samples the signed-in guard captured for the
  /// backend those credentials belong to.
  group('SyncService tracking spool ownership', () {
    const String origin = 'https://cisskerala.site';
    const String guardA = 'employee-doc-a';
    const String guardB = 'employee-doc-b';

    late Directory folder;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('ciss-tracking-');
      Hive.init(folder.path);
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'read'
                    ? base64UrlEncode(List<int>.filled(32, 7))
                    : null,
          );
      addTearDown(() async {
        await Hive.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await folder.delete(recursive: true);
      });
    });

    Future<SyncService> signedInAs(
      String owner,
      TrackingBuffer spool,
      RecordingAdapter recorder,
    ) async {
      final queue = await boundQueue(owner: owner);
      final client = ApiClient(
        baseUrl: origin,
        authTokenProvider: () async => 'guard-token',
      );
      client.dio.httpClientAdapter = recorder;
      return SyncService(
        RecordingRepository(client, uid: owner),
        queue,
        spool,
        trackingOwner: () async => owner,
      );
    }

    test(
      'delivers the signed-in guard\'s own samples and clears them',
      () async {
        final spool = TrackingBuffer(directory: folder);
        await spool.init();
        await spool.add({'latitude': 10.0}, owner: guardA, origin: origin);
        final recorder = RecordingAdapter();

        await (await signedInAs(guardA, spool, recorder)).processQueue();

        expect(recorder.sent, hasLength(1));
        final body = recorder.sent.single.data as Map<String, dynamic>;
        expect((body['samples'] as List<dynamic>).single, {'latitude': 10.0});
        expect(await spool.readPending(), isEmpty);
      },
    );

    test(
      'never posts another guard\'s samples under the current token',
      () async {
        final spool = TrackingBuffer(directory: folder);
        await spool.init();
        // Captured while guard A owned this phone, then A signed out.
        await spool.add({'latitude': 10.0}, owner: guardA, origin: origin);
        final recorder = RecordingAdapter();

        await (await signedInAs(guardB, spool, recorder)).processQueue();

        expect(recorder.sent, isEmpty);
        final retained = await spool.readPending();
        expect(retained.single.owner, guardA);
        expect(retained.single.sample['latitude'], 10.0);
      },
    );

    test('never posts a legacy sample that carries no owner', () async {
      final spool = TrackingBuffer(directory: folder);
      await spool.init();
      await spool.add({'latitude': 10.0});
      final recorder = RecordingAdapter();

      await (await signedInAs(guardA, spool, recorder)).processQueue();

      expect(recorder.sent, isEmpty);
      expect((await spool.readPending()).single.isAttributed, isFalse);
    });

    test('retains samples captured for a different backend origin', () async {
      final spool = TrackingBuffer(directory: folder);
      await spool.init();
      await spool.add(
        {'latitude': 10.0},
        owner: guardA,
        origin: 'https://other-region.example',
      );
      final recorder = RecordingAdapter();

      await (await signedInAs(guardA, spool, recorder)).processQueue();

      expect(recorder.sent, isEmpty);
      expect(
        (await spool.readPending()).single.origin,
        'https://other-region.example',
      );
    });

    test('retires a permanent rejection and keeps a retryable one', () async {
      final spool = TrackingBuffer(directory: folder);
      await spool.init();
      await spool.add({'latitude': 1.0}, owner: guardA, origin: origin);
      await spool.add({'latitude': 2.0}, owner: guardA, origin: origin);
      final recorder = RecordingAdapter(
        body:
            '{"accepted":1,"rejected":1,"results":['
            '{"index":0,"accepted":true,"retryable":false},'
            '{"index":1,"accepted":false,"code":"transient","retryable":true}'
            ']}',
      );

      await (await signedInAs(guardA, spool, recorder)).processQueue();

      final retained = await spool.readPending();
      expect(
        retained.single.sample['latitude'],
        2.0,
        reason: 'A transient rejection must stay queued for the next pass',
      );
    });

    test('drops a sample the server rejected on its own merits', () async {
      final spool = TrackingBuffer(directory: folder);
      await spool.init();
      await spool.add({'latitude': 1.0}, owner: guardA, origin: origin);
      final recorder = RecordingAdapter(
        body:
            '{"accepted":0,"rejected":1,"results":['
            '{"index":0,"accepted":false,"code":"rejected_by_rule",'
            '"retryable":false}]}',
      );

      await (await signedInAs(guardA, spool, recorder)).processQueue();

      expect(await spool.readPending(), isEmpty);
    });
  });
}

/// Records tracking batch requests without reaching the network.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter({
    this.body = '{"accepted":1,"rejected":0}',
    this.status = 200,
  });
  int status;

  final String body;
  final List<RequestOptions> sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A signed-in guard whose only live client is the recording adapter.
class RecordingRepository extends NoNetworkRepository {
  RecordingRepository(this.client, {this.uid = 'guard-a'});

  final ApiClient client;
  final String uid;

  @override
  User? get currentUser => SyncTestUser(uid);

  @override
  ApiClient get apiClient => client;

  @override
  Future<Map<String, String>> authHeaders() async => <String, String>{
    'Authorization': 'Bearer guard-token',
  };

  @override
  String get dutyApiBaseUrl => 'https://cisskerala.site';
}

/// Records when the generic HTTP client is reached, then fails closed: the
/// duty spool must never introduce a live client of its own.
class MarkerRepository extends NoNetworkRepository {
  MarkerRepository(this.order);
  final List<String> order;

  @override
  String get dutyApiBaseUrl => 'https://cisskerala.site';
  @override
  User? get currentUser => SyncTestUser('guard-a');

  @override
  ApiClient get apiClient {
    order.add('generic-request');
    throw StateError('No live client in this test');
  }
}

class PhotoRepository extends RecordingRepository {
  PhotoRepository(super.client);
  final attempts = <String?>[];
  @override
  Future<Map<String, dynamic>> uploadAttendancePhoto({
    required String employeeDocId,
    required String dataUrl,
    required String siteId,
    String? attemptId,
    String? verificationToken,
    bool authenticated = true,
    Future<bool> Function()? identityGuard,
  }) async {
    attempts.add(attemptId);
    return {
      'url': 'https://storage.example/photo.jpg',
      'path': 'employees/$employeeDocId/attendance/$attemptId/photo.jpg',
    };
  }
}

class SyncTestUser implements User {
  SyncTestUser(this.uid);
  @override
  final String uid;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token-$uid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
