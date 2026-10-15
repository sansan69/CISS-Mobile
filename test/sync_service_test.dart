import 'dart:convert';
import 'dart:io';

import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/sync/sync_service.dart';
import 'package:dio/dio.dart';
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
      'runs the duty hand-off before generic requests and keeps attendance queued',
      () async {
        final order = <String>[];
        final queue = OfflineQueue();
        await queue.init();
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
        final queue = OfflineQueue();
        await queue.init();
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
        final queue = OfflineQueue();
        await queue.init();
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
      final queue = OfflineQueue();
      await queue.init();
      final client = ApiClient(
        baseUrl: origin,
        authTokenProvider: () async => 'guard-token',
      );
      client.dio.httpClientAdapter = recorder;
      return SyncService(
        RecordingRepository(client),
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
  });
}

/// Records tracking batch requests without reaching the network.
class RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    return ResponseBody.fromString(
      '{"accepted":1,"rejected":0}',
      200,
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
  RecordingRepository(this.client);

  final ApiClient client;

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
  ApiClient get apiClient {
    order.add('generic-request');
    throw StateError('No live client in this test');
  }
}
