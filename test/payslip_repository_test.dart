import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/cache/read_cache.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/ciss_error.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/region/region_service.dart';

const String _uid = 'uid-guard-payslip-000000000001';
final List<int> _pdfBytes = List<int>.generate(2048, (i) => i % 256);

void main() {
  late List<RequestOptions> requests;

  setUp(() => requests = <RequestOptions>[]);

  MobileRepository repo({
    User? user,
    Future<ResponseBody> Function(RequestOptions options)? handler,
    void Function(String message)? log,
  }) {
    final auth = _FakeFirebaseAuth(user ?? _FakeUser(_uid));
    final client = ApiClient(
      authTokenProvider: () async => auth.currentUser?.getIdToken(false),
    );
    client.dio.httpClientAdapter = _FakeAdapter((options) {
      requests.add(options);
      return handler?.call(options) ?? Future.value(_json(200, const {}));
    });
    return MobileRepository(
      client,
      auth,
      _FakeRegionService(),
      readCache: ReadCache(store: MemoryReadCacheStore()),
      log: log ?? (_) {},
    );
  }

  group('fetchPayslips', () {
    test('GETs the documented endpoint with the guard bearer token', () async {
      final repository = repo(
        handler:
            (options) async => _json(200, <String, dynamic>{
              'payslips': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'slip-1',
                  'period': '2026-09',
                  'fileName': 'Sep-2026.pdf',
                  'sizeBytes': 188416,
                  'createdAt': '2026-10-02T09:15:00.000Z',
                  'employeeId': 'CISS/TCS/2025-26/871',
                },
                <String, dynamic>{
                  'id': 'slip-2',
                  'period': '2026-08',
                  'fileName': 'Aug-2026.pdf',
                  'sizeBytes': 182272,
                  'createdAt': '2026-09-03T06:00:00.000Z',
                },
              ],
            }),
      );

      final payslips = await repository.fetchPayslips();

      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/api/guard/payslips');
      expect(
        requests.single.headers['Authorization'],
        'Bearer token',
        reason: 'the slip list is guard-authenticated',
      );
      expect(requests.single.responseType, isNot(ResponseType.bytes));
      expect(payslips, hasLength(2));
      expect(payslips.first.id, 'slip-1');
      expect(payslips.first.period, '2026-09');
      expect(payslips.first.sizeBytes, 188416);
      expect(payslips.last.id, 'slip-2');
      expect(payslips.last.employeeId, isNull);
    });

    test('tolerates a payload with no list and drops rows without an id',
        () async {
      expect(
        await repo(
          handler: (options) async => _json(200, const <String, dynamic>{}),
        ).fetchPayslips(),
        isEmpty,
      );

      final payslips = await repo(
        handler:
            (options) async => _json(200, <String, dynamic>{
              'payslips': <dynamic>[
                <String, dynamic>{'period': '2026-09'},
                <String, dynamic>{'id': 'slip-1', 'period': '2026-09'},
                'not-a-map',
              ],
            }),
      ).fetchPayslips();

      expect(payslips, hasLength(1));
      expect(payslips.single.id, 'slip-1');
    });

    test('is never served from the offline read cache', () async {
      final readCache = ReadCache(store: MemoryReadCacheStore());
      final client = ApiClient(authTokenProvider: () async => 'token');
      client.dio.httpClientAdapter = _FakeAdapter(
        (options) async => _json(200, <String, dynamic>{
          'payslips': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'slip-1', 'period': '2026-09'},
          ],
        }),
      );
      final repository = MobileRepository(
        client,
        _FakeFirebaseAuth(_FakeUser(_uid)),
        _FakeRegionService(),
        readCache: readCache,
        log: (_) {},
      );

      await repository.fetchPayslips();
      await Future<void>.delayed(Duration.zero);

      // Nothing was written under any key for the payslip list.
      expect(
        await readCache.readJson(r'$uid|/api/guard/payslips'),
        isNull,
      );
      expect(
        await readCache.readJson(
          MobileRepository.buildReadCacheKey(
            region: 'KL',
            uid: _uid,
            path: '/api/guard/payslips',
          ),
        ),
        isNull,
      );
    });
  });

  group('downloadPayslipPdf', () {
    test('GETs the per-slip PDF as authenticated bytes', () async {
      final repository = repo(
        handler:
            (options) async => ResponseBody.fromBytes(
              _pdfBytes,
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/pdf'],
              },
            ),
      );

      final bytes = await repository.downloadPayslipPdf('slip/2026 09');

      expect(requests.single.method, 'GET');
      expect(
        requests.single.path,
        '/api/guard/payslips/slip%2F2026%2009/payslip',
        reason: 'the id is encoded into a single path segment',
      );
      expect(requests.single.headers['Authorization'], 'Bearer token');
      expect(requests.single.responseType, ResponseType.bytes);
      expect(bytes, hasLength(_pdfBytes.length));
      expect(bytes.first, _pdfBytes.first);
      expect(bytes.last, _pdfBytes.last);
    });

    test('rejects an empty id and an unauthenticated caller', () async {
      final repository = repo();

      await expectLater(
        repository.downloadPayslipPdf('   '),
        throwsA(isA<Exception>()),
      );
      expect(requests, isEmpty);

      final anonymous = MobileRepository(
        ApiClient(authTokenProvider: () async => null),
        _FakeFirebaseAuth(null),
        _FakeRegionService(),
        readCache: ReadCache(store: MemoryReadCacheStore()),
        log: (_) {},
      );
      await expectLater(
        anonymous.downloadPayslipPdf('slip-1'),
        throwsA(isA<StateError>()),
      );
      expect(requests, isEmpty, reason: 'no request without a session');
    });

    test('surfaces 404/403/401 as human messages', () async {
      Future<String> messageFor(int status) async {
        final repository = repo(
          handler:
              (options) async => ResponseBody.fromBytes(
                utf8.encode('{"error":"denied"}'),
                status,
                headers: <String, List<String>>{
                  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
                },
              ),
        );
        try {
          await repository.downloadPayslipPdf('slip-1');
        } catch (error) {
          return CissError.parse(error);
        }
        fail('expected the download to fail with $status');
      }

      expect(await messageFor(404), 'Requested information not found.');
      expect(
        await messageFor(403),
        'Access denied. You do not have permission for this action.',
      );
      expect(await messageFor(401), 'Session expired. Please login again.');
    });

    test('never logs the PDF payload or the download URL', () async {
      final logs = <String>[];
      final repository = repo(
        log: logs.add,
        handler:
            (options) async => ResponseBody.fromBytes(_pdfBytes, 200),
      );

      await repository.downloadPayslipPdf('slip-secret-1');

      final joined = logs.join('\n');
      expect(joined, isNot(contains('/api/guard/payslips')));
      expect(joined, isNot(contains('slip-secret-1')));
      expect(joined, isNot(contains(base64Encode(_pdfBytes.take(24).toList()))));

      final failing = repo(
        log: logs.add,
        handler:
            (options) async => ResponseBody.fromBytes(
              utf8.encode('not found'),
              404,
            ),
      );
      try {
        await failing.downloadPayslipPdf('slip-secret-2');
      } catch (_) {
        // Expected: only the failure is under test here.
      }
      final failureLogs = logs.join('\n');
      expect(failureLogs, isNot(contains('/api/guard/payslips')));
      expect(failureLogs, isNot(contains('slip-secret-2')));
    });
  });
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
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this._user);

  final User? _user;

  @override
  User? get currentUser => _user;

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
