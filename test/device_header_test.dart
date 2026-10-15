import 'dart:convert';
import 'dart:typed_data';

import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements FirebaseAuth {
  @override
  User? get currentUser => _User();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Region implements RegionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the headers of every request it answers.
class _HeaderAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> headers = <Map<String, dynamic>>[];
  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    headers.add(Map<String, dynamic>.from(options.headers));
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'ok': true, 'url': 'https://files/x.jpg'}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

MobileRepository repositoryWith(
  HttpClientAdapter adapter, {
  Future<String?> Function()? deviceId,
}) {
  final client = ApiClient(
    baseUrl: 'https://test.invalid',
    authTokenProvider: () async => null,
  );
  client.dio.httpClientAdapter = adapter;
  return MobileRepository(
    client,
    _Auth(),
    _Region(),
    deviceIdProvider: deviceId,
  );
}

void main() {
  test('a punch carries the handset id', () async {
    final adapter = _HeaderAdapter();
    final repository = repositoryWith(
      adapter,
      deviceId: () async => 'udid-alpha',
    );

    await repository.submitAttendance(<String, dynamic>{'status': 'In'});

    expect(adapter.paths, <String>['/api/attendance/submit']);
    expect(adapter.headers.single['X-Device-Id'], 'udid-alpha');
    expect(adapter.headers.single['Authorization'], 'Bearer test-token');
  });

  test('a device whose id cannot be read still punches', () async {
    final adapter = _HeaderAdapter();
    final repository = repositoryWith(
      adapter,
      deviceId: () async => throw StateError('keystore unavailable'),
    );

    await repository.submitAttendance(<String, dynamic>{'status': 'Out'});

    expect(adapter.paths, hasLength(1));
    expect(adapter.headers.single.containsKey('X-Device-Id'), isFalse);
  });

  test('no configured device id leaves the header absent', () async {
    final adapter = _HeaderAdapter();
    final repository = repositoryWith(adapter);

    await repository.submitAttendance(<String, dynamic>{'status': 'In'});

    expect(adapter.headers.single.containsKey('X-Device-Id'), isFalse);
  });
}
