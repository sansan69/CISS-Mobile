import 'package:ciss_mobile/core/cache/read_cache.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Region implements RegionService {
  @override
  RegionInfo? get activeRegion => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final unavailable in <bool?>[true, false, null]) {
    test(
      'dashboard next-shift availability maps $unavailable without new route',
      () async {
        final client = ApiClient(
          baseUrl: 'https://fixture.invalid',
          authTokenProvider: () async => 'test-token',
        );
        final requests = <String>[];
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add('${options.method} ${options.path}');
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'employeeName': 'Guard',
                    'employeeId': 'E1',
                    'attendanceStats': <String, dynamic>{
                      'presentDays': 3,
                      'absentDays': 1,
                      'workingDays': 5,
                    },
                    'recentAttendance': <dynamic>[],
                    'nextShift': <String, dynamic>{
                      'siteName': 'Central post',
                      'shiftLabel': 'Night duty',
                      'date': '2026-10-14',
                    },
                    if (unavailable != null)
                      'nextShiftUnavailable': unavailable,
                  },
                ),
              );
            },
          ),
        );
        final repository = MobileRepository(
          client,
          _Auth(),
          _Region(),
          readCache: ReadCache(),
        );
        final snapshot = await repository.fetchGuardDashboard();
        expect(snapshot.nextShiftUnavailable, unavailable ?? false);
        expect(snapshot.nextShiftSiteName, 'Central post');
        expect(snapshot.presentDays, 3);
        expect(requests, <String>['GET /api/guard/dashboard']);
        client.dio.close();
      },
    );
  }
}
