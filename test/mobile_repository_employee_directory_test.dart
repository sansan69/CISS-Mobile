import 'dart:convert';
import 'dart:typed_data';

import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/cache/read_cache.dart';
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
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Region implements RegionService {
  @override
  RegionInfo? get activeRegion => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'guards': <Object>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'includeInactive is opt-in and can be combined with district scope',
    () async {
      final client = ApiClient(
        baseUrl: 'https://test.invalid',
        authTokenProvider: () async => null,
      );
      final adapter = _Adapter();
      client.dio.httpClientAdapter = adapter;
      final repository = MobileRepository(
        client,
        _Auth(),
        _Region(),
        readCache: ReadCache(store: MemoryReadCacheStore()),
      );

      await repository.fetchFieldOfficerGuards(district: 'Ernakulam');
      await repository.fetchFieldOfficerGuards(
        district: 'Ernakulam',
        includeInactive: true,
      );

      expect(adapter.requests[0].queryParameters, {'district': 'Ernakulam'});
      expect(adapter.requests[1].queryParameters, {
        'district': 'Ernakulam',
        'includeInactive': true,
      });
      await repository.fetchFieldOfficerGuards();
      expect(adapter.requests[2].queryParameters, isEmpty);
    },
  );
}
