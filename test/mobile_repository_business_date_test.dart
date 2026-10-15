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

/// Answers the aggregated range route with [rangeRows] and every single-date
/// route with [dayRows], recording the requests.
class _AttendanceAdapter implements HttpClientAdapter {
  _AttendanceAdapter({
    this.rangeRows = const <Map<String, dynamic>>[],
    this.dayRows = const <Map<String, dynamic>>[],
    this.rangeStatus = 200,
  });

  final List<Map<String, dynamic>> rangeRows;
  final List<Map<String, dynamic>> dayRows;
  final int rangeStatus;
  final List<String> paths = <String>[];
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    queries.add(options.queryParameters);
    if (options.path.endsWith('/range') && rangeStatus != 200) {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'error': 'not found'}),
        rangeStatus,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    final rows = options.path.endsWith('/range') ? rangeRows : dayRows;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'attendance': rows}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

MobileRepository _repository(HttpClientAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'https://test.invalid',
    authTokenProvider: () async => null,
  );
  client.dio.httpClientAdapter = adapter;
  return MobileRepository(client, _Auth(), _Region());
}

Map<String, dynamic> _row({
  required String id,
  String date = '2026-10-14',
  String? checkIn,
  String? checkOut,
}) => <String, dynamic>{
  'id': id,
  'employeeId': 'CISS-1042',
  'guardName': 'Rahul Kumar',
  'date': date,
  'checkIn': checkIn,
  'checkOut': checkOut,
  'shiftLabel': 'Night duty',
};

void main() {
  test('asks the range route for the business date plus its predecessor', () async {
    final adapter = _AttendanceAdapter(
      rangeRows: <Map<String, dynamic>>[
        _row(id: 'in', checkIn: '20:05'),
        _row(id: 'out', date: '2026-10-15', checkOut: '06:10'),
      ],
    );
    final repository = _repository(adapter);

    final rows = await repository.fetchGuardAttendanceForBusinessDate(
      businessDate: DateTime(2026, 10, 15),
    );

    expect(adapter.paths, <String>['/api/field-officer/guard-attendance/range']);
    expect(adapter.queries.single['start'], '2026-10-14');
    expect(adapter.queries.single['end'], '2026-10-15');
    expect(rows.map((row) => row.id).toList(), <String>['in', 'out']);
  });

  test('keeps a single-date deployment working and merges duplicates', () async {
    final adapter = _AttendanceAdapter(
      rangeStatus: 404,
      dayRows: <Map<String, dynamic>>[
        _row(id: 'in', checkIn: '20:05'),
        _row(id: 'shared', checkIn: '20:05'),
      ],
    );
    final repository = _repository(adapter);

    final rows = await repository.fetchGuardAttendanceForBusinessDate(
      businessDate: DateTime(2026, 10, 15),
    );

    expect(adapter.paths, <String>[
      '/api/field-officer/guard-attendance/range',
      '/api/field-officer/guard-attendance',
      '/api/field-officer/guard-attendance',
    ]);
    expect(adapter.queries[1]['date'], '2026-10-14');
    expect(adapter.queries[2]['date'], '2026-10-15');
    // The same punch returned for both dates is counted once.
    expect(rows.map((row) => row.id).toList(), <String>['in', 'shared']);
  });

  test('reports a real failure instead of falling back', () async {
    final adapter = _AttendanceAdapter(rangeStatus: 500);
    final repository = _repository(adapter);

    await expectLater(
      repository.fetchGuardAttendanceForBusinessDate(
        businessDate: DateTime(2026, 10, 15),
      ),
      throwsA(anything),
    );
    expect(adapter.paths, <String>[
      '/api/field-officer/guard-attendance/range',
    ]);
  });
}
