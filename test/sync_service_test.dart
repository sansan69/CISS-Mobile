import 'dart:convert';
import 'dart:io';

import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/sync/sync_service.dart';
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
