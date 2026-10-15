import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/offline/willingness_queue.dart';

class MemoryStore implements WillingnessStore {
  List<Map<String, dynamic>> rows = [];
  @override
  Future<List<Map<String, dynamic>>> read() async =>
      rows.map((e) => Map<String, dynamic>.from(e)).toList();
  @override
  Future<void> write(List<Map<String, dynamic>> value) async {
    rows = value.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

Future<WillingnessOperation> choose(
  WillingnessQueue q, [
  WillingnessStatus response = WillingnessStatus.willing,
]) => q.choose(
  ownerUid: 'auth-a',
  apiBaseUrl: 'https://a.invalid',
  workOrderId: 'exam-1',
  response: response,
  expectedVersion: 0,
);
DioException failure(int code) => DioException(
  requestOptions: RequestOptions(path: ''),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: ''),
    statusCode: code,
    data: {'code': 'version_conflict', 'error': 'Duty closed'},
  ),
);
void main() {
  test(
    'new choice after receipt uses acknowledged version even before feed refresh',
    () async {
      final q = WillingnessQueue(MemoryStore());
      await q.load();
      await choose(q);
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send:
            (op) async => WillingnessReceipt(response: op.response, version: 1),
      );
      final successor = await choose(q, WillingnessStatus.unavailable);
      expect(successor.expectedVersion, 1);
    },
  );

  test(
    'version conflict preserves current server answer with persisted rejection',
    () async {
      final store = MemoryStore();
      final q = WillingnessQueue(store);
      await q.load();
      await choose(q);
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send:
            (op) async =>
                throw DioException(
                  requestOptions: RequestOptions(path: ''),
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: RequestOptions(path: ''),
                    statusCode: 409,
                    data: {
                      'code': 'version_conflict',
                      'error': 'Changed on another device',
                      'willingness': {'response': 'unavailable', 'version': 7},
                    },
                  ),
                ),
      );
      final restarted = WillingnessQueue(store);
      await restarted.load();
      expect(
        restarted.forOwner('auth-a', 'https://a.invalid').single.serverVersion,
        7,
      );
    },
  );
  test('transport retries preserve request body UUID and CAS', () async {
    final q = WillingnessQueue(MemoryStore());
    await q.load();
    final op = await choose(q);
    await q.process(
      owner: () => 'auth-a',
      origin: () => 'https://a.invalid',
      send:
          (op) async =>
              throw DioException(
                requestOptions: RequestOptions(path: ''),
                type: DioExceptionType.connectionTimeout,
              ),
    );
    await q.process(
      owner: () => 'auth-a',
      origin: () => 'https://a.invalid',
      send: (retry) async {
        expect(retry.id, op.id);
        expect(retry.expectedVersion, 0);
        return WillingnessReceipt(response: retry.response, version: 1);
      },
    );
  });
  test('capacity failure retains every pending request', () async {
    final q = WillingnessQueue(MemoryStore());
    await q.load();
    for (var i = 0; i < WillingnessQueue.capacity; i++) {
      await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://a.invalid',
        workOrderId: 'exam-$i',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      );
    }
    await expectLater(
      q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://a.invalid',
        workOrderId: 'one-more',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      q.forOwner('auth-a', 'https://a.invalid').length,
      WillingnessQueue.capacity,
    );
  });

  test(
    'durable restart coalesces unsent choices and isolates original owner and origin',
    () async {
      final store = MemoryStore();
      final q = WillingnessQueue(store);
      await q.load();
      final a = await choose(q);
      final b = await choose(q, WillingnessStatus.unavailable);
      expect(a.id, isNot(b.id));
      final restarted = WillingnessQueue(store);
      await restarted.load();
      expect(
        restarted.forOwner('auth-a', 'https://a.invalid').single.response,
        WillingnessStatus.unavailable,
      );
      expect(restarted.forOwner('auth-b', 'https://a.invalid'), isEmpty);
      expect(restarted.forOwner('auth-a', 'https://b.invalid'), isEmpty);
      var sends = 0;
      await restarted.process(
        owner: () => 'auth-b',
        origin: () => 'https://a.invalid',
        send: (op) async {
          sends++;
          return WillingnessReceipt(response: op.response, version: 1);
        },
      );
      expect(sends, 0);
    },
  );
  test(
    'inflight predecessor receipt rebases successor without deleting newer choice',
    () async {
      final q = WillingnessQueue(MemoryStore());
      await q.load();
      final first = await choose(q);
      final latch = Completer<WillingnessReceipt>();
      final sent = <WillingnessOperation>[];
      final processing = q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send: (op) {
          sent.add(op);
          return sent.length == 1
              ? latch.future
              : Future.value(
                WillingnessReceipt(response: op.response, version: 2),
              );
        },
      );
      await Future<void>.delayed(Duration.zero);
      final next = await choose(q, WillingnessStatus.unavailable);
      latch.complete(
        const WillingnessReceipt(
          response: WillingnessStatus.willing,
          version: 1,
        ),
      );
      await processing;
      expect(sent.map((e) => e.id), [first.id, next.id]);
      expect(sent.last.expectedVersion, 1);
      expect(q.forOwner('auth-a', 'https://a.invalid').single.state, 'saved');
    },
  );
  for (final status in [401, 429, 500]) {
    test('$status retains pending UUID through retry', () async {
      final q = WillingnessQueue(MemoryStore());
      await q.load();
      final op = await choose(q);
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send: (o) async => throw failure(status),
      );
      expect(q.forOwner('auth-a', 'https://a.invalid').single.state, 'pending');
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send: (o) async {
          expect(o.id, op.id);
          return WillingnessReceipt(response: o.response, version: 1);
        },
      );
      expect(q.forOwner('auth-a', 'https://a.invalid').single.state, 'saved');
    });
  }
  for (final status in [400, 403, 404, 409]) {
    test('$status persists terminal rejection without retry', () async {
      final store = MemoryStore();
      final q = WillingnessQueue(store);
      await q.load();
      await choose(q);
      var sends = 0;
      Future<WillingnessReceipt> send(WillingnessOperation op) async {
        sends++;
        throw failure(status);
      }

      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send: send,
      );
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send: send,
      );
      final restarted = WillingnessQueue(store);
      await restarted.load();
      expect(sends, 1);
      expect(
        restarted.forOwner('auth-a', 'https://a.invalid').single.state,
        'rejected',
      );
      expect(
        restarted.forOwner('auth-a', 'https://a.invalid').single.reason,
        'Duty closed',
      );
    });
  }
  test('session switch during a send prevents dispatch of successor', () async {
    final q = WillingnessQueue(MemoryStore());
    await q.load();
    await choose(q);
    var uid = 'auth-a';
    final latch = Completer<WillingnessReceipt>();
    var sends = 0;
    final processing = q.process(
      owner: () => uid,
      origin: () => 'https://a.invalid',
      send: (o) {
        sends++;
        return latch.future;
      },
    );
    await Future<void>.delayed(Duration.zero);
    await choose(q, WillingnessStatus.unavailable);
    uid = 'auth-b';
    latch.complete(
      const WillingnessReceipt(response: WillingnessStatus.willing, version: 1),
    );
    await processing;
    expect(sends, 1);
    expect(q.forOwner('auth-a', 'https://a.invalid').single.state, 'pending');
  });

  test(
    'one receipt retires only the acknowledged duty and keeps the rest pending',
    () async {
      final q = WillingnessQueue(MemoryStore());
      await q.load();
      await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://a.invalid',
        workOrderId: 'exam-1',
        response: WillingnessStatus.willing,
        expectedVersion: 0,
      );
      final second = await q.choose(
        ownerUid: 'auth-a',
        apiBaseUrl: 'https://a.invalid',
        workOrderId: 'exam-2',
        response: WillingnessStatus.unavailable,
        expectedVersion: 4,
      );
      final sent = <String>[];
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send: (op) async {
          sent.add(op.workOrderId);
          if (op.workOrderId == 'exam-2') {
            throw DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.connectionError,
            );
          }
          return WillingnessReceipt(
            response: op.response,
            version: op.expectedVersion + 1,
          );
        },
      );
      expect(sent, <String>['exam-1', 'exam-2']);
      expect(
        q
            .forOwner('auth-a', 'https://a.invalid')
            .map((e) => '${e.workOrderId}:${e.state}'),
        <String>['exam-1:saved', 'exam-2:pending'],
      );
      expect(q.forOwner('auth-a', 'https://a.invalid').last.id, second.id);
      sent.clear();
      await q.process(
        owner: () => 'auth-a',
        origin: () => 'https://a.invalid',
        send: (op) async {
          sent.add(op.workOrderId);
          return WillingnessReceipt(
            response: op.response,
            version: op.expectedVersion + 1,
          );
        },
      );
      expect(sent, <String>['exam-2']);
    },
  );
}
