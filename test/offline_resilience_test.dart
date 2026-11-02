import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/offline/offline_request.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/core/sync/providers.dart';
import 'package:ciss_mobile/core/sync/sync_service.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/shared/widgets/sync_status_badge.dart';

const String _uid = 'uid-guard-offline-000000000001';
final DateTime _t0 = DateTime.utc(2026, 10, 22, 9);

void main() {
  group('SyncService queue resilience (F-22)', () {
    late _MemoryQueue queue;
    late _MutableAuth auth;
    late _FakeTrackingBuffer tracking;

    SyncService build({
      DateTime Function()? clock,
      OfflineRequestProcessor? processor,
    }) {
      final client = ApiClient(authTokenProvider: () async => 'token');
      final repository = MobileRepository(
        client,
        auth,
        _FakeRegionService(),
        log: (_) {},
      );
      return SyncService(
        repository,
        queue,
        tracking,
        clock: clock,
        random: _ZeroRandom(),
        requestProcessor: processor,
      );
    }

    setUp(() {
      queue = _MemoryQueue();
      auth = _MutableAuth(_uid);
      tracking = _FakeTrackingBuffer();
    });

    test('a signed-out pass skips account work and still drains public attendance',
        () async {
      auth.user = null;
      queue.requests.add(_request('account'));
      queue.requests.add(
        _request(
          'public',
          uid: OfflineQueue.anonymousOwnerUid,
          body: <String, dynamic>{'attendanceVerificationToken': 'proof'},
        ),
      );

      final calls = <String>[];
      final service = build(
        clock: () => _t0,
        processor: (request) async {
          calls.add(request.id);
          return true;
        },
      );

      await service.processQueue();

      expect(calls, <String>['public']);
      expect(queue.single('account').retryCount, 0);
    });

    test('processes due entries and skips not-yet-due ones without sleeping',
        () async {
      final calls = <String>[];
      queue.requests.add(
        _request('backed-off', nextAttemptAt: _t0.add(const Duration(minutes: 5))),
      );
      queue.requests.add(_request('due'));

      final service = build(
        clock: () => _t0,
        processor: (request) async {
          calls.add(request.id);
          return true;
        },
      );

      final stopwatch = Stopwatch()..start();
      await service.processQueue();
      stopwatch.stop();

      // The backed-off entry is skipped, the later entry still attempts.
      expect(calls, <String>['due']);
      expect(queue.ids, <String>['backed-off']);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('failure persists exponential backoff instead of sleeping in the loop',
        () async {
      var now = _t0;
      queue.requests.add(_request('failing'));
      final service = build(
        clock: () => now,
        processor: (_) async => false,
      );

      await service.processQueue();

      var stored = queue.single('failing');
      expect(stored.retryCount, 1);
      expect(stored.blocked, isFalse);
      expect(
        stored.nextAttemptAt,
        _t0.add(SyncService.backoffBase),
        reason: 'first retry waits the base delay (zero jitter injected)',
      );

      // Same clock: not due, so no second attempt and no counter inflation.
      await service.processQueue();
      expect(queue.single('failing').retryCount, 1);

      // Once due, the delay doubles.
      now = stored.nextAttemptAt!;
      await service.processQueue();
      stored = queue.single('failing');
      expect(stored.retryCount, 2);
      expect(
        stored.nextAttemptAt,
        now.add(SyncService.backoffBase * 2),
      );
    });

    test('abandons A-owned entries when the account switches mid-pass', () async {
      queue.requests.add(_request('a-1'));
      queue.requests.add(_request('a-2'));

      final calls = <String>[];
      final service = build(
        clock: () => _t0,
        processor: (request) async {
          calls.add(request.id);
          if (request.id == 'a-1') {
            // Account A signs out, B signs in and A's queue is purged while
            // the first attempt is still awaiting.
            auth.user = _FakeUser('uid-guard-b-000000000002');
            queue.requests.removeWhere((entry) => entry.uid == _uid);
            await Future<void>.delayed(Duration.zero);
          }
          return true;
        },
      );

      await service.processQueue();

      expect(calls, <String>['a-1']);
      expect(queue.requests, isEmpty);
    });

    test('backoff is capped at maxBackoff', () async {
      queue.requests.add(_request('failing', retryCount: 10));
      final service = build(
        clock: () => _t0,
        processor: (_) async => false,
      );

      await service.processQueue();

      final stored = queue.single('failing');
      expect(stored.blocked, isFalse);
      expect(stored.retryCount, 11);
      expect(
        stored.nextAttemptAt,
        _t0.add(SyncService.maxBackoff),
        reason: '2^10 * 30s is clamped to the 15 minute cap',
      );
    });

    test('marks blocked after max attempts and keeps the entry on disk', () async {
      queue.requests.add(
        _request('poison', retryCount: SyncService.maxRetryAttempts - 1),
      );
      var calls = 0;
      final service = build(
        clock: () => _t0,
        processor: (_) async {
          calls += 1;
          return false;
        },
      );

      await service.processQueue();

      final blocked = queue.single('poison');
      expect(blocked.blocked, isTrue);
      expect(blocked.retryCount, SyncService.maxRetryAttempts);
      expect(queue.ids, <String>['poison'], reason: 'never silently deleted');
      expect(calls, 1);

      // A blocked entry is never retried again, even much later.
      final later = build(
        clock: () => _t0.add(const Duration(days: 3)),
        processor: (_) async {
          calls += 1;
          return true;
        },
      );
      await later.processQueue();
      expect(calls, 1);
      expect(queue.ids, <String>['poison']);
    });

    test('blocks an over-limit legacy entry without another attempt',
        () async {
      queue.requests.add(
        _request('legacy-over-limit', retryCount: SyncService.maxRetryAttempts),
      );
      var calls = 0;
      final service = build(
        clock: () => _t0,
        processor: (_) async {
          calls += 1;
          return true;
        },
      );

      await service.processQueue();

      expect(calls, 0);
      final stored = queue.single('legacy-over-limit');
      expect(stored.blocked, isTrue);
      expect(queue.ids, <String>['legacy-over-limit']);
    });

    test('blocks persisted leave POST and PATCH entries without dispatching',
        () async {
      queue.requests.addAll(<OfflineRequest>[
        _request('legacy-leave-post', path: '/api/guard/leave', method: 'POST'),
        _request(
          'legacy-leave-patch',
          path: '/api/guard/leave?source=offline',
          method: 'PATCH',
        ),
      ]);
      var calls = 0;
      final service = build(
        clock: () => _t0,
        processor: (_) async {
          calls += 1;
          return true;
        },
      );

      await service.processQueue();

      expect(calls, 0, reason: 'retired endpoints must stop before dispatch');
      expect(queue.ids, <String>['legacy-leave-post', 'legacy-leave-patch']);
      for (final request in queue.requests) {
        expect(request.blocked, isTrue);
        expect(request.lastError, contains('retired leave feature'));
        final persisted = OfflineRequest.fromJson(request.toJson());
        expect(persisted.blocked, isTrue);
        expect(persisted.lastError, request.lastError);
      }
    });

    test('does not replay or mutate the queue while signed out', () async {
      auth.user = null;
      queue.requests.add(_request('waiting', retryCount: 3));
      var calls = 0;
      final service = build(
        clock: () => _t0,
        processor: (_) async {
          calls += 1;
          return false;
        },
      );

      await service.processQueue();

      expect(calls, 0);
      final stored = queue.single('waiting');
      expect(stored.retryCount, 3, reason: 'not authenticated is not a retry');
      expect(stored.lastError, isNull);
      expect(queue.ids, <String>['waiting']);
    });

    test('drains a public attendance submission while signed out', () async {
      auth.user = null;
      queue.requests.add(
        _request(
          'public-attendance',
          uid: OfflineQueue.anonymousOwnerUid,
          body: <String, dynamic>{
            'employeeId': 'EMP-1',
            'attendanceVerificationToken': 'short-lived-proof',
          },
        ),
      );
      final calls = <String>[];
      final service = build(
        clock: () => _t0,
        processor: (request) async {
          calls.add(request.id);
          return true;
        },
      );

      await service.processQueue();

      expect(
        calls,
        <String>['public-attendance'],
        reason: 'the anonymous bucket replays without a bearer token',
      );
      expect(queue.ids, isEmpty, reason: 'a delivered entry is removed once');
    });

    test('a failing public attendance entry still backs off while signed out',
        () async {
      auth.user = null;
      queue.requests.add(
        _request(
          'public-attendance',
          uid: OfflineQueue.anonymousOwnerUid,
          body: <String, dynamic>{
            'employeeId': 'EMP-1',
            'attendanceVerificationToken': 'short-lived-proof',
          },
        ),
      );
      final service = build(
        clock: () => _t0,
        processor: (_) async => false,
      );

      await service.processQueue();

      final stored = queue.single('public-attendance');
      expect(stored.retryCount, 1, reason: 'a real attempt is booked');
      expect(stored.nextAttemptAt, _t0.add(SyncService.backoffBase));

      // Same clock: the entry is backed off, so the pass does not hammer it.
      await service.processQueue();
      expect(queue.single('public-attendance').retryCount, 1);
    });

    test('a signed-out pass never touches account-scoped entries', () async {
      auth.user = null;
      queue.requests.addAll(<OfflineRequest>[
        _request(
          'public-attendance',
          uid: OfflineQueue.anonymousOwnerUid,
          createdAt: _t0.subtract(const Duration(minutes: 1)),
          body: <String, dynamic>{
            'employeeId': 'EMP-1',
            'attendanceVerificationToken': 'short-lived-proof',
          },
        ),
        _request('account-scoped', path: '/api/guard/incidents'),
      ]);
      final calls = <String>[];
      final service = build(
        clock: () => _t0,
        processor: (request) async {
          calls.add(request.id);
          return true;
        },
      );

      await service.processQueue();

      expect(calls, <String>['public-attendance']);
      expect(queue.ids, <String>['account-scoped']);
      expect(queue.single('account-scoped').retryCount, 0);
    });

    test('stops mid-pass when the session ends', () async {
      queue.requests.add(_request('a'));
      queue.requests.add(_request('b'));
      final service = build(
        clock: () => _t0,
        processor: (request) async {
          if (request.id == 'a') {
            auth.user = null;
            return false;
          }
          return true;
        },
      );

      await service.processQueue();

      expect(queue.ids, <String>['a', 'b']);
      expect(queue.single('a').retryCount, 0);
    });

    test('a trigger during a pass causes exactly one more pass', () async {
      final gate = Completer<void>();
      var calls = 0;
      queue.requests.add(_request('first'));
      final service = build(
        clock: () => _t0,
        processor: (_) async {
          calls += 1;
          if (calls == 1) {
            // A new entry is queued while the first pass is in flight.
            queue.requests.add(_request('second'));
            await gate.future;
          }
          return true;
        },
      );

      final first = service.processQueue();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1, reason: 'first pass is in flight');
      // Connectivity fires several times during the pass.
      unawaited(service.processQueue());
      unawaited(service.processQueue());
      gate.complete();
      await first;

      expect(calls, 2, reason: 'the second entry was processed by the rerun');
      expect(service.completedPasses, 2, reason: 'exactly one extra pass');
      expect(queue.requests, isEmpty);
    });

    testWidgets('foreground timer flushes every three minutes',
        (tester) async {
      var calls = 0;
      var now = _t0;
      queue.requests.add(_request('timer'));
      final service = build(
        clock: () => now,
        processor: (_) async {
          calls += 1;
          return false;
        },
      );
      addTearDown(service.stop);

      service.start();
      await tester.pump();
      expect(SyncService.foregroundFlushInterval, const Duration(minutes: 3));

      final afterStartup = calls;
      // Once the persisted backoff is due, the foreground timer retries without
      // needing a connectivity flap.
      now = now.add(SyncService.foregroundFlushInterval);
      await tester.pump(SyncService.foregroundFlushInterval);
      await tester.pump();
      expect(calls, greaterThan(afterStartup));
      service.stop();
    });

    testWidgets('resume flushes the queue', (tester) async {
      var calls = 0;
      queue.requests.add(_request('resume'));
      final service = build(
        clock: () => _t0,
        processor: (_) async {
          calls += 1;
          return false;
        },
      );
      addTearDown(service.stop);

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      expect(calls, 0, reason: 'paused does not flush');

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(calls, 1);
    });
  });

  group('OfflineRequest backoff state', () {
    test('round-trips nextAttemptAt and blocked through JSON', () {
      final request = _request(
        'r1',
        retryCount: 4,
        blocked: true,
        nextAttemptAt: _t0,
      );
      final decoded = OfflineRequest.fromJson(request.toJson());
      expect(decoded.retryCount, 4);
      expect(decoded.blocked, isTrue);
      expect(decoded.nextAttemptAt, _t0);
    });

    test('legacy entries without the new fields stay due', () {
      final legacy = OfflineRequest.fromJson(<String, dynamic>{
        'id': 'legacy',
        'path': '/api/attendance/submit',
        'method': 'POST',
        'body': <String, dynamic>{},
        'createdAt': _t0.toIso8601String(),
      });
      expect(legacy.blocked, isFalse);
      expect(legacy.nextAttemptAt, isNull);
      expect(legacy.isDue(_t0), isTrue);
    });

    test('copyWith can clear the backoff when an entry becomes blocked', () {
      final due = _request('r2', nextAttemptAt: _t0);
      expect(due.copyWith(blocked: true, clearNextAttemptAt: true).nextAttemptAt,
          isNull);
    });
  });

  group('OfflineQueue health counters (F-22)', () {
    late Directory dir;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('ciss_queue_health');
      Hive.init(dir.path);
      await Hive.openBox<Map>(OfflineQueue.boxName);
    });

    tearDown(() async {
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('counts pending separately from blocked entries', () async {
      final queue = OfflineQueue();
      await queue.setOwner(_uid);
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: <String, dynamic>{'reason': 'blocked one'},
      );

      expect(queue.pendingCount, 1);
      expect(queue.blockedCount, 0);

      final request = queue.getQueuedRequests().single;
      await queue.updateRequest(
        request.copyWith(
          blocked: true,
          retryCount: SyncService.maxRetryAttempts,
        ),
      );

      expect(queue.pendingCount, 0);
      expect(queue.blockedCount, 1);
      expect(
        queue.getQueuedRequests(),
        hasLength(1),
        reason: 'blocked entries stay on disk for inspection',
      );
    });

    test('a deferred enqueue does not adopt the next account', () async {
      final queue = OfflineQueue();
      await queue.setOwner(_uid);

      final pending = queue.enqueue(
        path: '/api/guard/patrol',
        method: 'POST',
        body: <String, dynamic>{'i': 1},
      );
      // Ownership moves before the serialized write runs.
      await queue.setOwner('uid-guard-b-000000000002');

      await expectLater(
        pending,
        throwsA(isA<OfflineQueueOwnerChangedError>()),
      );
      expect(queue.queueSize, 0);
    });

    test('rejects non-public work queued while signed out', () async {
      final queue = OfflineQueue();
      await queue.setOwner(null);

      await expectLater(
        queue.enqueue(
          path: '/api/guard/patrol',
          method: 'POST',
          body: <String, dynamic>{'i': 1},
        ),
        throwsA(isA<OfflineQueueAnonymousError>()),
      );

      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: <String, dynamic>{'attendanceVerificationToken': 'proof'},
      );
      expect(queue.queueSize, 1);
    });

    test('refuses a 101st entry and preserves all existing work', () async {
      final queue = OfflineQueue();
      await queue.setOwner(_uid);

      for (var i = 0; i < OfflineQueue.maxQueueSize; i++) {
        await queue.enqueue(
          path: '/api/guard/patrol',
          method: 'POST',
          body: <String, dynamic>{'i': i},
        );
      }

      await expectLater(
        queue.enqueue(
          path: '/api/guard/patrol',
          method: 'POST',
          body: <String, dynamic>{'i': OfflineQueue.maxQueueSize},
        ),
        throwsA(isA<OfflineQueueFullError>()),
      );

      expect(queue.queueSize, OfflineQueue.maxQueueSize);
      expect(queue.pendingCount, OfflineQueue.maxQueueSize);
      expect(queue.evictedCount, 0);
    });
  });

  group('SyncStatusBadge queue health (F-22)', () {
    Future<void> pumpBadge(
      WidgetTester tester, {
      required _MemoryQueue queue,
      required bool offline,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            offlineQueueProvider.overrideWith((ref) => queue),
            sessionOfflineProvider.overrideWithValue(offline),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(actions: const <Widget>[SyncStatusBadge()]),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }

    testWidgets('is invisible for an empty online queue', (tester) async {
      await pumpBadge(tester, queue: _MemoryQueue(), offline: false);
      expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);
      expect(find.textContaining('pending'), findsNothing);
    });

    testWidgets('shows pending actions and the offline grace state',
        (tester) async {
      final queue = _MemoryQueue()..requests.add(_request('pending'));
      await pumpBadge(tester, queue: queue, offline: true);
      expect(find.text('Offline · 1 pending'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('uses danger styling when entries are blocked or dropped',
        (tester) async {
      final queue = _MemoryQueue()
        ..requests.addAll(<OfflineRequest>[
          _request('pending'),
          _request('blocked', blocked: true),
        ]);
      await pumpBadge(tester, queue: queue, offline: false);
      expect(find.text('1 pending · 1 blocked'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });
}

OfflineRequest _request(
  String id, {
  String path = '/api/attendance/submit',
  String method = 'POST',
  int retryCount = 0,
  DateTime? nextAttemptAt,
  bool blocked = false,
  String? uid = _uid,
  Map<String, dynamic>? body,
  DateTime? createdAt,
}) {
  return OfflineRequest(
    id: id,
    path: path,
    method: method,
    body: body ?? <String, dynamic>{'id': id},
    createdAt: createdAt ?? _t0,
    uid: uid,
    retryCount: retryCount,
    nextAttemptAt: nextAttemptAt,
    blocked: blocked,
  );
}

class _MemoryQueue extends OfflineQueue {
  final List<OfflineRequest> requests = <OfflineRequest>[];

  List<String> get ids => requests.map((request) => request.id).toList();

  OfflineRequest single(String id) =>
      requests.singleWhere((request) => request.id == id);

  @override
  bool get isInitialized => true;

  @override
  List<OfflineRequest> getQueuedRequests() {
    final sorted = List<OfflineRequest>.from(requests)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  @override
  Future<void> updateRequest(OfflineRequest request) async {
    final index = requests.indexWhere((existing) => existing.id == request.id);
    if (index >= 0) requests[index] = request;
  }

  @override
  Future<void> removeRequest(String id) async {
    requests.removeWhere((request) => request.id == id);
  }

  @override
  int get pendingCount =>
      requests.where((request) => !request.blocked).length;

  @override
  int get blockedCount =>
      requests.where((request) => request.blocked).length;
}

class _FakeTrackingBuffer extends TrackingBuffer {
  @override
  Future<List<Map<String, dynamic>>> readPending() async =>
      const <Map<String, dynamic>>[];
}

class _MutableAuth implements FirebaseAuth {
  _MutableAuth(String uid) : user = _FakeUser(uid);

  User? user;

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    user = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeRegionService implements RegionService {
  @override
  RegionInfo? get activeRegion => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _ZeroRandom implements math.Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
