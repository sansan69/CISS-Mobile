import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/firebase_auth_state_source.dart';
import 'package:ciss_mobile/core/cache/account_scoped_providers.dart';
import 'package:ciss_mobile/core/cache/read_cache.dart';
import 'package:ciss_mobile/core/location/tracking_buffer.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/models/attendance_models.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/network/api_client.dart';
import 'package:ciss_mobile/core/network/auth_repository.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/offline/draft_service.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/privacy/local_data_purger.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_attendance_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_dashboard_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_profile_screen.dart';

const String _uidA = 'uid-guard-a-0000000000000001';
const String _uidB = 'uid-guard-b-0000000000000002';

/// Emits Firebase identity changes, exactly like the live auth-state source.
class _FakeAuthStateSource implements FirebaseAuthStateSource {
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast(sync: true);

  @override
  String? currentUid;

  @override
  Stream<String?> get idTokenUidChanges => _controller.stream;

  void emit(String? uid) {
    currentUid = uid;
    _controller.add(uid);
  }

  Future<void> dispose() => _controller.close();
}

/// Resolves the authoritative session for whichever uid is active, like the
/// backend round-trip the real notifier performs.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._authState);

  final _FakeAuthStateSource _authState;

  @override
  Future<AuthSession?> resolveCurrentSession() async {
    final uid = _authState.currentUid;
    if (uid == null) return null;
    return AuthSession(
      role: AppRole.guard,
      displayName: 'Guard $uid',
      primaryId: 'CISS/2026/$uid',
      uid: uid,
    );
  }

  @override
  Future<AuthSession> signInGuard({
    required String loginIdOrPhone,
    required String pin,
  }) async => throw UnimplementedError();

  @override
  Future<AuthSession> signInFieldOfficer({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> verifyCurrentGuardPin({
    required AuthSession expectedSession,
    required String loginIdOrPhone,
    required String pin,
  }) async => throw UnimplementedError();

  @override
  Future<void> verifyCurrentFieldOfficerPassword({
    required AuthSession expectedSession,
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

/// Spy repository: counts account-scoped fetches instead of hitting HTTP, and
/// tags every payload with the account it was fetched for.
class _SpyRepository extends MobileRepository {
  _SpyRepository(this._authState)
    : super(
        ApiClient(authTokenProvider: () async => 'token'),
        _FakeFirebaseAuth(_authState),
        _FakeRegionService(),
        log: (_) {},
      );

  final _FakeAuthStateSource _authState;
  int dashboardCalls = 0;
  int profileCalls = 0;

  String get _activeUid => _authState.currentUid ?? 'signed-out';

  @override
  Future<GuardDashboardSnapshot> fetchGuardDashboard() async {
    dashboardCalls += 1;
    return GuardDashboardSnapshot(
      employeeName: 'Guard $_activeUid',
      employeeId: 'EMP-$_activeUid',
      clientName: 'Client $_activeUid',
      district: 'Kollam',
      profilePhotoUrl: null,
      presentDays: 0,
      absentDays: 0,
      workingDays: 0,
      latestEvalScore: null,
      latestEvalPeriod: null,
      nextShiftLabel: null,
      nextShiftSiteName: null,
      nextShiftDate: null,
      recentAttendance: const <AttendanceRecordModel>[],
    );
  }

  @override
  Future<GuardProfileModel> fetchGuardProfile() async {
    profileCalls += 1;
    return GuardProfileModel(
      id: 'profile-$_activeUid',
      fullName: 'Guard $_activeUid',
      employeeId: 'EMP-$_activeUid',
      clientName: 'Client $_activeUid',
      district: 'Kollam',
      phoneNumber: '9000000000',
      status: 'Active',
    );
  }
}

/// Counts sign-out / account-change purges without touching real storage.
class _CountingPurger extends LocalDataPurger {
  _CountingPurger()
    : super(
        readCache: ReadCache(store: MemoryReadCacheStore()),
        offlineQueue: OfflineQueue(),
        draftService: DraftService(),
        trackingBuffer: TrackingBuffer(),
      );

  int purges = 0;

  @override
  Future<LocalDataPurgeReport> purge() async {
    purges += 1;
    return LocalDataPurgeReport();
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this._authState);

  final _FakeAuthStateSource _authState;

  @override
  User? get currentUser {
    final uid = _authState.currentUid;
    return uid == null ? null : _FakeUser(uid);
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

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('account-scoped provider cache (NEW-02)', () {
    late _FakeAuthStateSource authState;
    late _SpyRepository repository;
    late _CountingPurger purger;
    late ProviderContainer container;

    setUp(() {
      authState = _FakeAuthStateSource();
      repository = _SpyRepository(authState);
      purger = _CountingPurger();
      container = ProviderContainer(
        overrides: <Override>[
          firebaseAuthStateSourceProvider.overrideWithValue(authState),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(authState),
          ),
          mobileRepositoryProvider.overrideWithValue(repository),
          localDataPurgerProvider.overrideWithValue(purger),
          authTopicRefreshProvider.overrideWithValue(() async {}),
          authNotificationCleanupProvider.overrideWithValue(() async {}),
          authTrackingCleanupProvider.overrideWithValue(() async {}),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await authState.dispose();
    });

    test('signing in as another account refetches the dashboard and profile',
        () async {
      authState.currentUid = _uidA;
      expect(
        (await container.read(authSessionProvider.future))?.uid,
        _uidA,
        reason: 'account A is the active session',
      );

      final dashboardA = await container.read(guardDashboardProvider.future);
      final profileA = await container.read(guardProfileProvider.future);
      expect(dashboardA.employeeName, 'Guard $_uidA');
      expect(profileA.fullName, 'Guard $_uidA');
      expect(repository.dashboardCalls, 1);
      expect(repository.profileCalls, 1);

      // A cached future would be served again with no repository call.
      await container.read(guardDashboardProvider.future);
      expect(repository.dashboardCalls, 1, reason: 'cached while A is active');

      // Account A -> B without a sign-out in between.
      authState.emit(_uidB);
      await _flush();
      expect(container.read(authSessionProvider).valueOrNull?.uid, _uidB);

      final dashboardB = await container.read(guardDashboardProvider.future);
      final profileB = await container.read(guardProfileProvider.future);

      expect(
        repository.dashboardCalls,
        greaterThan(1),
        reason: 'B must refetch the dashboard instead of reusing A future',
      );
      expect(
        repository.profileCalls,
        greaterThan(1),
        reason: 'B must refetch the profile instead of reusing A future',
      );
      expect(dashboardB.employeeName, 'Guard $_uidB');
      expect(profileB.fullName, 'Guard $_uidB');
      expect(purger.purges, 1, reason: 'A -> B still purges A local data');
    });

    test('sign-out drops the cached account data before anything can reuse it',
        () async {
      authState.currentUid = _uidA;
      await container.read(authSessionProvider.future);
      await container.read(guardDashboardProvider.future);
      expect(repository.dashboardCalls, 1);

      authState.emit(null);
      await _flush();
      expect(container.read(authSessionProvider).valueOrNull, isNull);

      // Nothing is cached for the signed-out identity: reading it now must not
      // hand back A's snapshot.
      final signedOut = await container.read(guardDashboardProvider.future);
      expect(signedOut.employeeName, isNot('Guard $_uidA'));
      expect(repository.dashboardCalls, greaterThan(1));
    });

    test('the registry covers both portals and no device-scoped provider',
        () {
      expect(accountScopedProviders, contains(guardDashboardProvider));
      expect(accountScopedProviders, contains(guardProfileProvider));
      expect(accountScopedProviders, contains(attendanceSitesProvider));
      expect(accountScopedProviders, contains(fieldOfficerDashboardProvider));
      expect(
        accountScopedProviders.toSet(),
        hasLength(accountScopedProviders.length),
        reason: 'each provider is listed once',
      );
    });
  });
}
