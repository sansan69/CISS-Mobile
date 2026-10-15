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

class _AttendanceAdapter implements HttpClientAdapter {
  static const _attendance = <Map<String, dynamic>>[
    {
      'id': 'in-and-out',
      'checkIn': '08:00',
      'checkOut': '17:00',
      'status': 'present',
    },
    {'id': 'in-only', 'checkIn': '08:05', 'status': 'present'},
    {'id': 'out-only', 'checkOut': '17:10', 'status': 'present'},
    {'id': 'absent-status-only', 'status': 'absent'},
    {
      'id': 'blank-times-status-only',
      'checkIn': '  ',
      'checkOut': '',
      'status': 'present',
    },
  ];

  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({'attendance': _attendance}),
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
    'both attendance history methods return only recorded punches',
    () async {
      final client = ApiClient(
        baseUrl: 'https://test.invalid',
        authTokenProvider: () async => null,
      );
      final adapter = _AttendanceAdapter();
      client.dio.httpClientAdapter = adapter;
      final repository = MobileRepository(client, _Auth(), _Region());

      final daily = await repository.fetchFieldOfficerGuardAttendance(
        date: '2026-10-15',
      );
      final ranged = await repository.fetchFieldOfficerGuardAttendanceRange(
        start: DateTime(2026, 10, 15),
        end: DateTime(2026, 10, 15),
      );

      expect(adapter.paths, [
        '/api/field-officer/guard-attendance',
        '/api/field-officer/guard-attendance/range',
      ]);
      expect(daily.map((entry) => entry.id), [
        'in-and-out',
        'in-only',
        'out-only',
      ]);
      expect(ranged.map((entry) => entry.id), [
        'in-and-out',
        'in-only',
        'out-only',
      ]);
    },
  );
}
