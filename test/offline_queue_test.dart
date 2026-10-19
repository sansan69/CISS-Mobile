import 'dart:convert';
import 'dart:io';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late OfflineQueue queue;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('outbox-test');
    Hive.init(directory.path);
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'read'
                  ? base64UrlEncode(List.filled(32, 7))
                  : null,
        );
    queue = OfflineQueue();
    await queue.init();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Future<void> add() => queue.enqueue(
    path: '/api/attendance/submit',
    method: 'POST',
    body: {'employeeDocId': 'guard'},
  );
  test(
    'concurrent enqueues have durable monotonic sequence and replay identity',
    () async {
      await Future.wait([add(), add(), add()]);
      final rows = queue.getQueuedRequests();
      expect(rows.map((r) => r.sequence), [1, 2, 3]);
      expect(rows.every((r) => r.body['clientRequestId'] == r.id), isTrue);
      await queue.clear();
      await add();
      expect(queue.getQueuedRequests().single.sequence, 4);
    },
  );
  test('malformed legacy rows cannot abort queue migration', () async {
    await Hive.box<Map>(
      OfflineQueue.boxName,
    ).put('bad', {1: 'non-string key', 'sequence': 'bad'});
    await queue.init();
    await add();
    expect(
      queue.getQueuedRequests().where(
        (r) => r.path == '/api/attendance/submit',
      ),
      hasLength(1),
    );
  });

  test('legacy rows without owner and origin are quarantined', () async {
    await Hive.box<Map>(OfflineQueue.boxName).put('legacy', {
      'id': 'legacy',
      'path': '/api/guard/leave',
      'method': 'POST',
      'body': <String, dynamic>{},
      'createdAt': DateTime.utc(2026).toIso8601String(),
    });
    await queue.init();
    final row = queue.getQueuedRequests().singleWhere((r) => r.id == 'legacy');
    expect(row.state, 'quarantined');
    expect(row.ownerUid, isNull);
    expect(row.origin, isNull);
  });

  test(
    'enqueued rows capture the lazy identity and normalized origin',
    () async {
      queue.bindIdentity(
        () async => const OfflineQueueIdentity(
          ownerUid: 'guard-a',
          origin: 'HTTPS://CISSKERALA.SITE/',
        ),
      );
      await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
      final row = queue.getQueuedRequests().single;
      expect(row.ownerUid, 'guard-a');
      expect(row.origin, 'https://cisskerala.site');
    },
  );

  test(
    'authenticated attendance and break rows share one guard stream',
    () async {
      queue.bindIdentity(
        () async => const OfflineQueueIdentity(
          ownerUid: 'guard-a',
          origin: 'https://cisskerala.site',
        ),
      );
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {
          'employeeDocId': 'employee-a',
          'siteId': 'site-a',
          'status': 'In',
        },
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

      expect(queue.getQueuedRequests().map((r) => r.streamKey).toSet(), {
        'guard-attendance:guard-a',
      });
    },
  );

  test(
    'ack survives restart and rejects stay visible without retrying',
    () async {
      await add();
      final row = queue.getQueuedRequests().single;
      await queue.acknowledge(row.id, DateTime.utc(2026, 10, 18));
      expect(queue.lastAcknowledgedAt, DateTime.utc(2026, 10, 18));
      await add();
      await queue.updateRequest(
        queue.getQueuedRequests().single.copyWith(
          state: 'rejected',
          lastError: 'outside_capture_window',
        ),
      );
      expect(queue.pendingCount, 0);
      expect(queue.rejectedCount, 1);
      expect(queue.lastFailureReason, 'outside_capture_window');
      await Hive.close();
      await queue.init();
      expect(queue.lastAcknowledgedAt, DateTime.utc(2026, 10, 18));
    },
  );
}
