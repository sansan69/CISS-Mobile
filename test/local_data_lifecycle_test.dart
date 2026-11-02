import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ciss_mobile/core/cache/hive_read_cache_store.dart';
import 'package:ciss_mobile/core/cache/read_cache.dart';
import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/offline/draft_service.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/privacy/local_data_purger.dart';
import 'package:ciss_mobile/core/privacy/privacy_log.dart';
import 'package:ciss_mobile/core/region/region_service.dart';

const String _incidentsPath = '/api/guard/incidents';
const String _uidA = 'uid-guard-a-0000000000000001';
const String _uidB = 'uid-guard-b-0000000000000002';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ───────────────────────────────────────────────────────────────────────────
  // Read cache: per-account keys, no fallback on auth errors, max age
  // ───────────────────────────────────────────────────────────────────────────
  group('read cache account scoping', () {
    test('cache key includes the active uid', () {
      final keyA = MobileRepository.buildReadCacheKey(
        region: 'KL',
        uid: _uidA,
        path: _incidentsPath,
      );
      final keyB = MobileRepository.buildReadCacheKey(
        region: 'KL',
        uid: _uidB,
        path: _incidentsPath,
      );
      expect(keyA, contains(_uidA));
      expect(keyB, contains(_uidB));
      expect(keyA, isNot(keyB));
      expect(
        MobileRepository.buildReadCacheKey(
          region: 'KL',
          uid: null,
          path: _incidentsPath,
        ),
        contains('anonymous'),
      );
    });

    test('account A cache is never served to account B', () async {
      final store = MemoryReadCacheStore();
      final cache = ReadCache(store: store);

      final repoA = _repo(
        auth: _FakeFirebaseAuth(_FakeUser(_uidA)),
        cache: cache,
        adapter: _FakeAdapter(
          (options) async => _json(200, <String, dynamic>{
            'incidents': <String>['A-incident'],
          }),
        ),
      );
      expect(
        await repoA.getJson(_incidentsPath),
        <String, dynamic>{
          'incidents': <String>['A-incident'],
        },
      );
      await _flush();

      // A may use its own cache when genuinely offline.
      repoA.apiClient.dio.httpClientAdapter = _offlineAdapter();
      expect(
        await repoA.getJson(_incidentsPath),
        <String, dynamic>{
          'incidents': <String>['A-incident'],
        },
      );

      // B failing with 401 must get an error, not A's cached incidents.
      final repoB = _repo(
        auth: _FakeFirebaseAuth(_FakeUser(_uidB)),
        cache: cache,
        adapter: _FakeAdapter(
          (options) async => _json(401, <String, dynamic>{'error': 'denied'}),
        ),
      );
      Object? bError;
      Map<String, dynamic>? bResult;
      try {
        bResult = await repoB.getJson(_incidentsPath);
      } catch (error) {
        bError = error;
      }
      expect(bResult, isNull);
      expect(bError, isNotNull);

      // B offline must also not see A's payload.
      repoB.apiClient.dio.httpClientAdapter = _offlineAdapter();
      Object? offlineError;
      Map<String, dynamic>? offlineResult;
      try {
        offlineResult = await repoB.getJson(_incidentsPath);
      } catch (error) {
        offlineError = error;
      }
      expect(offlineResult, isNull);
      expect(offlineError, isNotNull);
    });

    test('never falls back for 401/403 responses', () async {
      final cache = ReadCache();
      final repo = _repo(
        auth: _FakeFirebaseAuth(_FakeUser(_uidA)),
        cache: cache,
        adapter: _FakeAdapter(
          (options) async => _json(401, <String, dynamic>{'error': 'expired'}),
        ),
      );
      // Prime the cache with a successful response.
      repo.apiClient.dio.httpClientAdapter = _FakeAdapter(
        (options) async => _json(200, <String, dynamic>{'incidents': 'cached'}),
      );
      expect(await repo.getJson('/api/guard/incidents'), <String, dynamic>{
        'incidents': 'cached',
      });
      await _flush();

      for (final status in <int>[401, 403]) {
        repo.apiClient.dio.httpClientAdapter = _FakeAdapter(
          (options) async => _json(status, <String, dynamic>{'error': 'no'}),
        );
        Object? error;
        Map<String, dynamic>? result;
        try {
          result = await repo.getJson('/api/guard/incidents');
        } catch (e) {
          error = e;
        }
        expect(result, isNull, reason: 'status $status must not serve cache');
        expect(error, isNotNull);
      }
    });

    test('never falls back for StateError(Not authenticated)', () async {
      final cache = ReadCache();
      // Prime the anonymous namespace the unauthenticated key would use.
      cache.setJson(
        MobileRepository.buildReadCacheKey(
          region: 'KL',
          uid: null,
          path: '/api/guard/incidents',
        ),
        <String, dynamic>{'incidents': 'anonymous-cache'},
      );

      final repo = _repo(
        auth: _FakeFirebaseAuth(null),
        cache: cache,
        adapter: _offlineAdapter(),
      );
      Object? error;
      Map<String, dynamic>? result;
      try {
        result = await repo.getJson('/api/guard/incidents');
      } catch (e) {
        error = e;
      }
      expect(result, isNull);
      expect(error, isNotNull);
    });

    test('offline fallback refuses entries older than 24h', () async {
      var now = DateTime.utc(2026, 1, 1, 12);
      final cache = ReadCache(now: () => now);
      final repo = _repo(
        auth: _FakeFirebaseAuth(_FakeUser(_uidA)),
        cache: cache,
        adapter: _FakeAdapter(
          (options) async => _json(200, <String, dynamic>{'x': 1}),
        ),
      );
      expect(await repo.getJson('/api/guard/dashboard'), <String, dynamic>{
        'x': 1,
      });
      await _flush();

      repo.apiClient.dio.httpClientAdapter = _offlineAdapter();
      // Still within 24h — served.
      now = now.add(const Duration(hours: 23));
      expect(await repo.getJson('/api/guard/dashboard'), <String, dynamic>{
        'x': 1,
      });

      // Beyond 24h — error instead of stale data.
      now = now.add(const Duration(hours: 2));
      Object? error;
      Map<String, dynamic>? result;
      try {
        result = await repo.getJson('/api/guard/dashboard');
      } catch (e) {
        error = e;
      }
      expect(result, isNull);
      expect(error, isNotNull);
    });

    test('Hive store uses the already-open box', () async {
      final dir = Directory.systemTemp.createTempSync('ciss_read_cache');
      addTearDown(() async {
        await Hive.close();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      Hive.init(dir.path);
      final box = await Hive.openBox<dynamic>(
        HiveReadCacheStore.defaultBoxName,
      );
      final store = HiveReadCacheStore();
      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
      expect(box.get('k'), 'v');
    });

    test('Hive store does not create a plaintext box on its own', () async {
      final dir = Directory.systemTemp.createTempSync('ciss_read_cache_closed');
      addTearDown(() async {
        await Hive.close();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      Hive.init(dir.path);
      final store = HiveReadCacheStore();
      await store.write('k', 'v');
      expect(await store.read('k'), isNull);
      expect(Hive.isBoxOpen(HiveReadCacheStore.defaultBoxName), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Offline queue ownership + fail-closed encryption
  // ───────────────────────────────────────────────────────────────────────────
  group('offline queue ownership', () {
    late Directory dir;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('ciss_queue');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await _resetHive(<String>[OfflineQueue.boxName]);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('enqueue stamps the owner and replay filters by it', () async {
      await Hive.openBox<Map>(OfflineQueue.boxName);
      final queue = OfflineQueue();
      await queue.setOwner(_uidA);
      await queue.enqueue(
        path: '/api/guard/incidents',
        method: 'POST',
        body: <String, dynamic>{'reason': 'A only'},
      );

      final queued = queue.getQueuedRequests();
      expect(queued, hasLength(1));
      expect(queued.single.uid, _uidA);

      // A different account never sees (or replays) A's request.
      await queue.setOwner(_uidB);
      expect(queue.getQueuedRequests(), isEmpty);
      expect(Hive.box<Map>(OfflineQueue.boxName).isEmpty, isTrue);
    });

    test('legacy ownerless entries are purged, not replayed', () async {
      await Hive.openBox<Map>(OfflineQueue.boxName);
      final box = Hive.box<Map>(OfflineQueue.boxName);
      await box.put('legacy', <String, dynamic>{
        'id': 'legacy',
        'path': '/api/attendance/submit',
        'method': 'POST',
        'body': <String, dynamic>{},
        'createdAt': DateTime.now().toIso8601String(),
      });

      final queue = OfflineQueue();
      await queue.setOwner(_uidA);
      expect(queue.getQueuedRequests(), isEmpty);
      expect(box.containsKey('legacy'), isFalse);
    });

    test('anonymous public attendance stays replayable after sign-in',
        () async {
      await Hive.openBox<Map>(OfflineQueue.boxName);
      final queue = OfflineQueue();
      await queue.setOwner(null);
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: <String, dynamic>{
          'employeeId': 'EMP-1',
          'attendanceVerificationToken': 'short-lived-proof',
        },
      );
      expect(
        queue.getQueuedRequests().single.uid,
        OfflineQueue.anonymousOwnerUid,
      );

      await queue.setOwner(_uidA);
      final replayable = queue.getQueuedRequests();
      expect(replayable, hasLength(1));
      expect(replayable.single.uid, OfflineQueue.anonymousOwnerUid);
      expect(replayable.single.isPublicAttendance, isTrue);
    });

    test('signing in does not purge unauthenticated public attendance',
        () async {
      await Hive.openBox<Map>(OfflineQueue.boxName);
      final box = Hive.box<Map>(OfflineQueue.boxName);
      final queue = OfflineQueue();
      await queue.setOwner(null);
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: <String, dynamic>{
          'employeeId': 'EMP-1',
          'attendanceVerificationToken': 'short-lived-proof',
        },
      );

      // Signing in as an account must not treat the anonymous bucket as a
      // foreign owner: the submission is deliverable, not lost.
      await queue.setOwner(_uidA);
      expect(
        box.length,
        1,
        reason: 'anonymous entries survive sign-in (NEW-03)',
      );
      final replayable = queue.getQueuedRequests();
      expect(replayable.single.uid, OfflineQueue.anonymousOwnerUid);
      expect(replayable.single.isPublicAttendance, isTrue);
      expect(queue.pendingCount, 1);

      // The real foreign-owner purge is unchanged: A's queued work is deleted
      // when another account signs in, while the anonymous entry stays.
      await queue.enqueue(
        path: '/api/guard/incidents',
        method: 'POST',
        body: <String, dynamic>{'reason': 'A only'},
      );
      await queue.setOwner(_uidB);
      expect(box.length, 1);
      expect(
        queue.getQueuedRequests().single.uid,
        OfflineQueue.anonymousOwnerUid,
        reason: 'A entry purged, anonymous bucket kept',
      );
    });

    test('rejects an anonymous non-public action instead of parking it',
        () async {
      await Hive.openBox<Map>(OfflineQueue.boxName);
      final box = Hive.box<Map>(OfflineQueue.boxName);
      final queue = OfflineQueue();
      await queue.setOwner(null);

      await expectLater(
        queue.enqueue(
          path: '/api/guard/incidents',
          method: 'POST',
          body: <String, dynamic>{'reason': 'no proof'},
        ),
        throwsA(isA<OfflineQueueAnonymousError>()),
      );
      expect(box, isEmpty, reason: 'it could never be replayed');
    });

    test('fails closed instead of opening the queue unencrypted', () async {
      // Secure storage is unavailable in the test process, so no cipher exists.
      final queue = OfflineQueue();
      await expectLater(
        queue.getEncryptionCipher(),
        throwsA(isA<OfflineQueueUnavailableError>()),
      );
      expect(queue.isInitialized, isFalse);
      await expectLater(
        queue.enqueue(
          path: '/api/guard/incidents',
          method: 'POST',
          body: <String, dynamic>{},
        ),
        throwsA(isA<OfflineQueueUnavailableError>()),
      );
      expect(queue.queueSize, 0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Drafts: uid namespacing
  // ───────────────────────────────────────────────────────────────────────────
  group('draft namespacing', () {
    late Directory dir;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('ciss_drafts');
      Hive.init(dir.path);
      await DraftService.init();
    });

    tearDown(() async {
      await _resetHive(<String>[DraftService.boxName]);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('a new account cannot restore the previous account draft', () async {
      final drafts = DraftService();
      await drafts.setOwner(_uidA);
      await drafts.saveDraft('guard_incident_draft', <String, dynamic>{
        'description': 'A secret incident',
      });
      expect(
        drafts.getDraft('guard_incident_draft')?['description'],
        'A secret incident',
      );

      await drafts.setOwner(_uidB);
      expect(drafts.getDraft('guard_incident_draft'), isNull);
      expect(drafts.hasDraft('guard_incident_draft'), isFalse);

      await drafts.saveDraft('guard_incident_draft', <String, dynamic>{
        'description': 'B only',
      });
      await drafts.setOwner(_uidA);
      expect(drafts.getDraft('guard_incident_draft'), isNull);
    });

    test('same owner keeps its draft across restarts', () async {
      final drafts = DraftService();
      await drafts.setOwner(_uidA);
      await drafts.saveDraft('field_officer_report_visits', <String, dynamic>{
        'notes': 'still mine',
      });

      final restarted = DraftService();
      await restarted.setOwner(_uidA);
      expect(
        restarted.getDraft('field_officer_report_visits')?['notes'],
        'still mine',
      );
    });

    test('ownerless writes are not persisted', () async {
      final drafts = DraftService();
      await drafts.setOwner(null);
      await drafts.saveDraft('guard_incident_draft', <String, dynamic>{
        'description': 'ownerless',
      });
      expect(drafts.getDraft('guard_incident_draft'), isNull);
      expect(Hive.box<Map>(DraftService.boxName).isEmpty, isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Tracking spool ownership
  // ───────────────────────────────────────────────────────────────────────────
  group('tracking spool ownership', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('ciss_spool');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('samples flush only for the owner that recorded them', () async {
      final a = TrackingBuffer(directory: dir);
      await a.init();
      await a.setOwner(_uidA);
      await a.add(<String, dynamic>{'latitude': 9.1, 'longitude': 76.2});
      expect(await a.readPending(), hasLength(1));

      // A new process before the session resolves: owner unknown, spool must
      // not be drained with whatever token happens to be current.
      final unknown = TrackingBuffer(directory: dir);
      await unknown.init();
      expect(await unknown.readPending(), isEmpty);

      // Account B adopts the spool: A's samples are purged, not flushed.
      await unknown.setOwner(_uidB);
      expect(await unknown.readPending(), isEmpty);
      expect(await a.pending(), isEmpty);
    });

    test('clear removes samples and the owner marker', () async {
      final buffer = TrackingBuffer(directory: dir);
      await buffer.init();
      await buffer.setOwner(_uidA);
      await buffer.add(<String, dynamic>{'latitude': 9.1});
      await buffer.clear();

      expect(await buffer.readPending(), isEmpty);
      expect(
        File('${dir.path}/${TrackingBuffer.ownerFileName}').existsSync(),
        isFalse,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Local data purger
  // ───────────────────────────────────────────────────────────────────────────
  group('local data purger', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ciss_purge');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('clears account cache, queue, drafts, spool, session, and FCM',
        () async {
      final store = MemoryReadCacheStore();
      final cache = ReadCache(store: store);
      cache.setJson('any-key', <String, dynamic>{'netPay': 'secret'});
      await _flush();

      File('${tempDir.path}/payslip-2026-01.pdf').writeAsStringSync('pdf');
      File('${tempDir.path}/payslip-2026-02.pdf').writeAsStringSync('pdf');
      File('${tempDir.path}/keep.txt').writeAsStringSync('keep');
      File('${tempDir.path}/payslip-2026-03.docx').writeAsStringSync('keep');

      final queue = _RecordingQueue();
      final drafts = _RecordingDrafts();
      final tracking = _RecordingTrackingBuffer();
      var fcmTokenDeletes = 0;
      var trackingSessionClears = 0;
      final logs = <String>[];

      final purger = LocalDataPurger(
        readCache: cache,
        offlineQueue: queue,
        draftService: drafts,
        trackingBuffer: tracking,
        deleteFcmToken: () async => fcmTokenDeletes += 1,
        tempDirectoryProvider: () async => tempDir,
        clearTrackingSession: () async => trackingSessionClears += 1,
        log: logs.add,
      );

      final report = await purger.purge();

      expect(report.isClean, isTrue, reason: report.failures.toString());
      expect(await store.read('any-key'), isNull);
      expect(queue.cleared, isTrue);
      expect(queue.ownerUid, isNull);
      expect(drafts.cleared, isTrue);
      expect(drafts.ownerUid, isNull);
      expect(tracking.cleared, isTrue);
      expect(fcmTokenDeletes, 1);
      expect(trackingSessionClears, 1);
      expect(File('${tempDir.path}/payslip-2026-01.pdf').existsSync(), isFalse);
      expect(File('${tempDir.path}/payslip-2026-02.pdf').existsSync(), isFalse);
      expect(File('${tempDir.path}/keep.txt').existsSync(), isTrue);
      expect(File('${tempDir.path}/payslip-2026-03.docx').existsSync(), isTrue);
      expect(logs, isEmpty);
    });

    test('one failing step does not stop the others and logs no PII',
        () async {
      final cache = ReadCache(store: MemoryReadCacheStore());
      final queue = _RecordingQueue();
      final drafts = _RecordingDrafts();
      final tracking = _RecordingTrackingBuffer();
      final logs = <String>[];

      final purger = LocalDataPurger(
        readCache: cache,
        offlineQueue: queue,
        draftService: drafts,
        trackingBuffer: tracking,
        deleteFcmToken: () async {
          throw StateError('secure store failed for guard@example.com /tmp/x');
        },
        tempDirectoryProvider: () async => tempDir,
        clearTrackingSession: () async {},
        log: logs.add,
      );

      final report = await purger.purge();

      expect(report.failures.keys, contains(LocalDataPurger.fcmTokenStep));
      expect(report.didClear(LocalDataPurger.readCacheStep), isTrue);
      expect(report.didClear(LocalDataPurger.offlineQueueStep), isTrue);
      expect(report.didClear(LocalDataPurger.trackingSpoolStep), isTrue);
      expect(queue.cleared, isTrue);
      expect(tracking.cleared, isTrue);
      // The failing step's message (email/path) must not reach the log.
      expect(logs.join('\n'), isNot(contains('guard@example.com')));
      expect(logs.join('\n'), isNot(contains('/tmp/x')));
      expect(logs.join('\n'), contains(LocalDataPurger.fcmTokenStep));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PII log redaction
  // ───────────────────────────────────────────────────────────────────────────
  group('PII log redaction', () {
    test('redacts uids, emails, tokens and coordinates', () {
      final message =
          'session uid=$_uidA email=guard@cissindia.co.in '
          'auth=Bearer abc.def.ghi coords=9.123456,76.654321 '
          'jwt=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.'
          'dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U';

      final redacted = PrivacyLog.redactForLog(message, uids: <String>[_uidA]);

      expect(redacted, isNot(contains(_uidA)));
      expect(redacted, isNot(contains('guard@cissindia.co.in')));
      expect(redacted, isNot(contains('9.123456')));
      expect(redacted, isNot(contains('76.654321')));
      expect(redacted, isNot(contains('abc.def.ghi')));
      expect(redacted, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('keeps endpoint/status diagnostics', () {
      expect(
        PrivacyLog.redactForLog('/api/guard/incidents failed with HTTP 401'),
        '/api/guard/incidents failed with HTTP 401',
      );
    });

    test('repository diagnostics never include the session payload or uid',
        () async {
      final logs = <String>[];
      final repo = _repo(
        auth: _FakeFirebaseAuth(_FakeUser(_uidA)),
        cache: ReadCache(),
        log: logs.add,
        adapter: _FakeAdapter(
          (options) async => _json(200, <String, dynamic>{
            'role': 'not-a-real-role',
            'uid': _uidA,
            'displayName': 'Guard Secret',
            'email': 'guard.secret@cissindia.co.in',
            'employeeDocId': 'CISS/TCS/2025-26/871',
          }),
        ),
      );

      await expectLater(repo.resolveCurrentSession(), throwsA(anything));

      final joined = logs.join('\n');
      expect(joined, isNot(contains(_uidA)));
      expect(joined, isNot(contains('guard.secret@cissindia.co.in')));
      expect(joined, isNot(contains('Guard Secret')));
      expect(joined, isNot(contains('CISS/TCS/2025-26/871')));
      expect(joined, contains('_resolveSessionFromBackend'));
    });

    test('repository source no longer logs payloads, uids or raw prints', () {
      final source = File(
        'lib/core/network/mobile_repository.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('received data=')));
      expect(source, isNot(contains('user.uid=')));
      expect(source, isNot(contains('debugPrint(')));
      // Diagnostics worth keeping stay in place.
      expect(source, contains("'/api/mobile/session'"));
    });

    test('both sign-out paths invoke the local data purger', () {
      final source = File(
        'lib/features/auth/application/auth_controller.dart',
      ).readAsStringSync();
      // Normal sign-out (AuthController.signOut).
      expect(
        source,
        contains('_runBestEffortCleanup(authLocalDataPurgeProvider)'),
      );
      // Fail-closed sign-out (AuthSessionNotifier._failClosed).
      expect(
        source,
        contains('unawaited(enqueueIdentityCleanup(_runFailClosedCleanup));'),
      );
      expect(source, contains('await _purgeLocalAccountData();'));
      // Account-scoped store ownership is wired from the auth lifecycle.
      expect(source, contains('offlineQueueProvider).setOwner'));
      expect(source, contains('draftServiceProvider).setOwner'));
      expect(source, contains('trackingBufferProvider).setOwner'));
    });

    test('tracking spool source does not log coordinates', () {
      final source = File(
        'lib/core/location/tracking_buffer.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('toStringAsFixed(5)')));
      expect(source, isNot(contains('latitude.toStringAsFixed')));
      expect(source, isNot(contains('longitude.toStringAsFixed')));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _resetHive(List<String> boxNames) async {
  await Hive.close();
  for (final name in boxNames) {
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {
      // Already gone.
    }
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ResponseBody _json(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

_FakeAdapter _offlineAdapter() =>
    _FakeAdapter((options) async => throw const SocketException('offline'));

MobileRepository _repo({
  required _FakeFirebaseAuth auth,
  required ReadCache cache,
  required HttpClientAdapter adapter,
  void Function(String message)? log,
}) {
  final client = ApiClient(
    authTokenProvider: () async => auth.currentUser?.getIdToken(false),
  );
  client.dio.httpClientAdapter = adapter;
  return MobileRepository(
    client,
    auth,
    _FakeRegionService(),
    readCache: cache,
    log: log ?? (_) {},
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  String? get displayName => null;

  @override
  String? get email => null;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this._user);

  User? _user;

  @override
  User? get currentUser => _user;

  @override
  Future<void> signOut() async {
    _user = null;
  }

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

class _RecordingQueue extends OfflineQueue {
  bool cleared = false;

  @override
  Future<void> setOwner(String? uid) async {
    // Mirrors the real implementation's visible state without touching Hive.
    ownerUidForTest = uid;
  }

  String? ownerUidForTest;

  @override
  String? get ownerUid => ownerUidForTest;

  @override
  Future<void> clear() async {
    cleared = true;
    ownerUidForTest = null;
  }
}

class _RecordingDrafts extends DraftService {
  bool cleared = false;
  String? ownerUidForTest;

  @override
  Future<void> setOwner(String? uid) async {
    ownerUidForTest = uid;
  }

  @override
  String? get ownerUid => ownerUidForTest;

  @override
  Future<void> clearAll() async {
    cleared = true;
    ownerUidForTest = null;
  }
}

class _RecordingTrackingBuffer extends TrackingBuffer {
  bool cleared = false;

  @override
  Future<void> clear() async {
    cleared = true;
  }
}
