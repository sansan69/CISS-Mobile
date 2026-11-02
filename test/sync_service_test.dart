import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/authoritative_session_error.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/core/sync/sync_service.dart';

const String _uid = 'uid-guard-session-000000000001';

void main() {
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

  group('SyncService retry policy constants', () {
    test('blocks after 20 attempts and flushes every 3 foreground minutes', () {
      expect(SyncService.maxRetryAttempts, 20);
      expect(SyncService.foregroundFlushInterval, const Duration(minutes: 3));
      expect(
        SyncService.maxBackoff,
        greaterThanOrEqualTo(SyncService.backoffBase),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // F-23: transport failure vs authoritative denial classification
  // ───────────────────────────────────────────────────────────────────────────
  group('resolveCurrentSession failure classification', () {
    test('a transport failure is typed and does not sign Firebase out',
        () async {
      final auth = _FakeFirebaseAuth(_FakeUser(_uid));
      final repo = _repo(
        auth: auth,
        adapter: _FakeAdapter(
          (options) async => throw const SocketException('offline'),
        ),
      );

      await expectLater(
        repo.resolveCurrentSession(),
        throwsA(isA<AuthoritativeSessionTransportError>()),
      );
      expect(auth.signOutCalls, 0, reason: 'offline is not a denial');
      expect(auth.currentUser, isNotNull);
    });

    test('a timeout is a transport failure', () async {
      final auth = _FakeFirebaseAuth(_FakeUser(_uid));
      final repo = _repo(
        auth: auth,
        adapter: _FakeAdapter(
          (options) async => throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 40),
            requestOptions: options,
          ),
        ),
      );

      await expectLater(
        repo.resolveCurrentSession(),
        throwsA(isA<AuthoritativeSessionTransportError>()),
      );
      expect(auth.signOutCalls, 0);
    });

    test('401 and 403 remain authoritative denials and fail closed', () async {
      for (final status in <int>[401, 403]) {
        final auth = _FakeFirebaseAuth(_FakeUser(_uid));
        final repo = _repo(
          auth: auth,
          adapter: _FakeAdapter(
            (options) async => _json(status, <String, dynamic>{'error': 'no'}),
          ),
        );

        await expectLater(
          repo.resolveCurrentSession(),
          throwsA(isA<AuthoritativeSessionDeniedError>()),
        );
        expect(auth.signOutCalls, 1, reason: 'HTTP $status must fail closed');
        expect(auth.currentUser, isNull);
      }
    });

    test('5xx is a resolution failure, not a transport failure', () async {
      final auth = _FakeFirebaseAuth(_FakeUser(_uid));
      final repo = _repo(
        auth: auth,
        adapter: _FakeAdapter(
          (options) async => _json(503, <String, dynamic>{'error': 'down'}),
        ),
      );

      await expectLater(
        repo.resolveCurrentSession(),
        throwsA(isA<AuthoritativeSessionResolutionError>()),
      );
      expect(
        await _matchesTransportError(repo),
        isFalse,
        reason: 'server errors must not grant offline grace',
      );
      expect(auth.signOutCalls, 1);
    });

    test('a malformed session payload stays non-transport and fails closed',
        () async {
      final auth = _FakeFirebaseAuth(_FakeUser(_uid));
      final repo = _repo(
        auth: auth,
        adapter: _FakeAdapter(
          // Role missing: the server answered, but not with a session.
          (options) async => _json(200, <String, dynamic>{'uid': _uid}),
        ),
      );

      await expectLater(
        repo.resolveCurrentSession(),
        throwsA(isA<AuthoritativeSessionResolutionError>()),
      );
      expect(await _matchesTransportError(repo), isFalse);
      expect(auth.signOutCalls, 1);
    });

    test('a successful resolution returns the session without signing out',
        () async {
      final auth = _FakeFirebaseAuth(_FakeUser(_uid));
      final repo = _repo(
        auth: auth,
        adapter: _FakeAdapter(
          (options) async => _json(200, <String, dynamic>{
            'role': 'guard',
            'uid': _uid,
            'displayName': 'Guard One',
            'primaryId': 'CISS/2026/001',
          }),
        ),
      );

      final session = await repo.resolveCurrentSession();
      expect(session, isA<AuthSession>());
      expect(session!.uid, _uid);
      expect(session.displayName, 'Guard One');
      expect(session.offline, isFalse);
      expect(auth.signOutCalls, 0);
    });
  });
}

Future<bool> _matchesTransportError(MobileRepository repo) async {
  try {
    await repo.resolveCurrentSession();
  } on AuthoritativeSessionTransportError {
    return true;
  } catch (_) {
    return false;
  }
  return false;
}

MobileRepository _repo({
  required _FakeFirebaseAuth auth,
  required HttpClientAdapter adapter,
}) {
  final client = ApiClient(
    authTokenProvider: () async => auth.currentUser?.getIdToken(false),
  );
  client.dio.httpClientAdapter = adapter;
  return MobileRepository(client, auth, _FakeRegionService(), log: (_) {});
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

  int signOutCalls = 0;

  @override
  User? get currentUser => _user;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
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
