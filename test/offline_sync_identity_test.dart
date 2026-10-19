import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/core/sync/providers.dart';
import 'package:ciss_mobile/core/sync/sync_service.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'support/guard_redesign_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late OfflineQueue queue;
  late MutableRepository repository;
  late RecordingAdapter adapter;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync-identity-');
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
    repository = MutableRepository('owner-a', 'https://region-a.example');
    adapter = RecordingAdapter();
    repository.client.dio.httpClientAdapter = adapter;
    addTearDown(() async {
      await Hive.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
    });
  });

  Future<void> bindQueue({String? owner, String? origin}) async {
    queue.bindIdentity(
      () async => OfflineQueueIdentity(
        ownerUid: owner ?? repository.uid,
        origin: origin ?? repository.origin,
      ),
    );
  }

  SyncService service() => SyncService(
    repository,
    queue,
    TrackingBuffer(),
    trackingOwner: () async => null,
  );

  test(
    'does not replay a row for another user, origin, or signed-out state',
    () async {
      await bindQueue(owner: 'owner-old');
      await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
      await bindQueue(origin: 'https://region-old.example');
      await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
      repository.uid = 'owner-a';
      repository.origin = 'https://region-a.example';
      await service().processQueue();
      expect(adapter.sent, isEmpty);

      repository.uid = null;
      await service().processQueue();
      expect(adapter.sent, isEmpty);
    },
  );

  test(
    'retains and never infers identity for unattributed legacy rows',
    () async {
      await Hive.box<Map>(OfflineQueue.boxName).put('old-row', {
        'id': 'old-row',
        'path': '/api/guard/leave',
        'method': 'POST',
        'body': <String, dynamic>{},
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      await queue.init();
      await bindQueue();
      await service().processQueue();
      final retained = queue.getQueuedRequests().singleWhere(
        (r) => r.id == 'old-row',
      );
      expect(retained.state, 'quarantined');
      expect(adapter.sent, isEmpty);
    },
  );

  test(
    'public proof work drains independently of another owner stream',
    () async {
      await bindQueue(owner: 'owner-other');
      await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
      queue.bindIdentity(
        () async => OfflineQueueIdentity(
          ownerUid: null,
          origin: 'https://region-a.example',
        ),
      );
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {'attendanceVerificationToken': 'proof-token'},
      );
      repository.uid = 'owner-a';
      await service().processQueue();
      expect(adapter.sent.map((options) => options.path), [
        '/api/attendance/submit',
      ]);
      expect(queue.getQueuedRequests().single.path, '/api/guard/leave');
    },
  );

  test(
    'identity changing while token acquisition is paused prevents POST',
    () async {
      final token = Completer<String?>();
      repository.setTokenProvider(() => token.future);
      await bindQueue();
      await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
      final processing = service().processQueue();
      await Future<void>.delayed(Duration.zero);
      repository.uid = 'owner-b';
      token.complete('token-for-owner-a');
      await processing;
      expect(adapter.sent, isEmpty);
      expect(queue.pendingCount, 1);
    },
  );

  test('stopped run cannot dispatch after paused token acquisition', () async {
    final token = Completer<String?>();
    final entered = Completer<void>();
    repository.setTokenProvider(() {
      if (!entered.isCompleted) entered.complete();
      return token.future;
    });
    repository.authHeadersImmediate = true;
    await bindQueue();
    await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
    final oldService = service();
    final processing = oldService.processQueue();
    await entered.future;
    oldService.stop();
    token.complete('token-for-stopped-run');
    await processing;
    expect(adapter.sent, isEmpty);
    expect(queue.pendingCount, 1);
  });

  test('stopped run cannot refresh a 401 token or retry', () async {
    final refresh = Completer<String?>();
    final entered = Completer<void>();
    repository.client = ApiClient(
      baseUrl: repository.origin,
      authTokenProvider: () async => 'initial-token',
      authTokenRefreshProvider: () {
        if (!entered.isCompleted) entered.complete();
        return refresh.future;
      },
    );
    repository.client.dio.httpClientAdapter = adapter..status = 401;
    repository.authHeadersImmediate = true;
    await bindQueue();
    await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
    final oldService = service();
    final processing = oldService.processQueue();
    await entered.future;
    oldService.stop();
    refresh.complete('refreshed-token-for-stopped-run');
    await processing;
    expect(adapter.sent, hasLength(1));
    expect(queue.pendingCount, 1);
  });

  test(
    'stopped run cannot send tracking after paused token acquisition',
    () async {
      final token = Completer<String?>();
      final entered = Completer<void>();
      repository.setTokenProvider(() {
        if (!entered.isCompleted) entered.complete();
        return token.future;
      });
      repository.authHeadersImmediate = true;
      final spool = TrackingBuffer(directory: directory);
      await spool.init();
      await spool.add(
        {'latitude': 10.0},
        owner: 'employee-a',
        origin: repository.origin,
      );
      await bindQueue();
      final oldService = SyncService(
        repository,
        queue,
        spool,
        trackingOwner: () async => 'employee-a',
      );
      final processing = oldService.processQueue();
      await entered.future;
      oldService.stop();
      token.complete('token-for-stopped-run');
      await processing;
      expect(adapter.sent, isEmpty);
      expect((await spool.readPending()).single.sample, {'latitude': 10.0});
    },
  );

  test('identity change after 401 blocks the refreshed-token retry', () async {
    await bindQueue();
    await queue.enqueue(path: '/api/guard/leave', method: 'POST', body: {});
    adapter.status = 401;
    adapter.onFetch = () => repository.uid = 'owner-b';

    await service().processQueue();

    expect(adapter.sent, hasLength(1));
    expect(repository.refreshCount, 0);
    expect(queue.pendingCount, 1);
  });

  test(
    'public proof request never retries with authenticated credentials',
    () async {
      var tokenCalls = 0;
      final client = ApiClient(
        baseUrl: repository.origin,
        authTokenProvider: () async {
          tokenCalls++;
          return 'user-token';
        },
      );
      final publicAdapter = RecordingAdapter()..status = 401;
      client.dio.httpClientAdapter = publicAdapter;

      await expectLater(
        client.dio.post<void>(
          '/api/attendance/submit',
          options: Options(extra: {kSkipApiAuth: true}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(publicAdapter.sent, hasLength(1));
      expect(tokenCalls, 0);
    },
  );

  test('region revision recreates and disposes the sync service', () async {
    final container = ProviderContainer(
      overrides: [
        offlineQueueProvider.overrideWith((ref) => queue),
        mobileRepositoryProvider.overrideWith((ref) => repository),
        trackingBufferProvider.overrideWith((ref) => TrackingBuffer()),
      ],
    );
    addTearDown(container.dispose);
    final first = container.read(syncServiceProvider);
    repository.origin = 'https://region-b.example';
    container.read(regionGraphRevisionProvider.notifier).state++;
    final second = container.read(syncServiceProvider);
    expect(identical(first, second), isFalse);
  });

  test(
    'identity changing during photo upload prevents the final POST',
    () async {
      final upload = Completer<Map<String, dynamic>>();
      repository.photoUpload = () => upload.future;
      await bindQueue();
      await queue.enqueue(
        path: '/api/attendance/submit',
        method: 'POST',
        body: {
          'employeeDocId': 'employee-a',
          'siteId': 'site-a',
          'attendanceAttemptId': 'capture-a',
          'photoDataUrl': 'data:image/jpeg;base64,AA==',
        },
      );
      final processing = service().processQueue();
      await Future<void>.delayed(Duration.zero);
      repository.uid = 'owner-b';
      upload.complete({'url': 'https://storage.example/photo.jpg'});
      await processing;
      expect(adapter.sent, isEmpty);
      expect(queue.pendingCount, 1);
    },
  );
}

class MutableRepository extends NoNetworkRepository {
  MutableRepository(this.uid, this.origin) {
    client = ApiClient(
      baseUrl: origin,
      authTokenProvider: () => _tokenProvider(),
      authTokenRefreshProvider: () async {
        refreshCount++;
        return _tokenProvider();
      },
    );
  }

  String? uid;
  String origin;
  late ApiClient client;
  Future<String?> Function() _tokenProvider = () async => 'guard-token';
  int refreshCount = 0;
  bool authHeadersImmediate = false;
  Future<Map<String, dynamic>> Function()? photoUpload;

  void setTokenProvider(Future<String?> Function() provider) {
    _tokenProvider = provider;
  }

  @override
  User? get currentUser => uid == null ? null : _TestUser(uid!);
  @override
  String get dutyApiBaseUrl => origin;
  @override
  ApiClient get apiClient => client;
  @override
  Future<Map<String, String>> authHeaders() async => {
    'Authorization':
        'Bearer ${authHeadersImmediate ? 'headers-token' : await _tokenProvider()}',
  };
  @override
  Future<Map<String, dynamic>> uploadAttendancePhoto({
    required String employeeDocId,
    required String dataUrl,
    required String siteId,
    String? attemptId,
    String? verificationToken,
    bool authenticated = true,
    Future<bool> Function()? identityGuard,
  }) async =>
      photoUpload?.call() ?? {'url': 'https://storage.example/photo.jpg'};
}

class _TestUser implements User {
  const _TestUser(this.uid);
  @override
  final String uid;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token-$uid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingAdapter implements HttpClientAdapter {
  final sent = <RequestOptions>[];
  int status = 200;
  void Function()? onFetch;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    onFetch?.call();
    return ResponseBody.fromString(
      '{"success":true}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
