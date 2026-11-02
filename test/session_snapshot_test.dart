import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/firebase_auth_state_source.dart';
import 'package:ciss_mobile/core/auth/session_snapshot_store.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/network/auth_repository.dart';
import 'package:ciss_mobile/core/network/authoritative_session_error.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';

const String _uid = 'uid-guard-snapshot-00000000001';
final DateTime _now = DateTime.utc(2026, 10, 22, 10);

void main() {
  group('AuthSession serialization', () {
    test('round-trips every field and the role', () {
      const session = AuthSession(
        role: AppRole.fieldOfficer,
        displayName: 'FO Test',
        primaryId: 'CISS/2026/007',
        uid: _uid,
        email: 'officer@cissindia.co.in',
        employeeDocId: 'doc-7',
        assignedDistricts: <String>['Ernakulam', 'Kollam'],
        clientName: 'Client',
        district: 'Ernakulam',
        stateCode: 'KL',
      );
      final decoded = AuthSession.fromJson(session.toJson());
      expect(decoded, isNotNull);
      expect(decoded!.role, AppRole.fieldOfficer);
      expect(decoded.displayName, 'FO Test');
      expect(decoded.primaryId, 'CISS/2026/007');
      expect(decoded.uid, _uid);
      expect(decoded.email, 'officer@cissindia.co.in');
      expect(decoded.employeeDocId, 'doc-7');
      expect(decoded.assignedDistricts, <String>['Ernakulam', 'Kollam']);
      expect(decoded.clientName, 'Client');
      expect(decoded.district, 'Ernakulam');
      expect(decoded.stateCode, 'KL');
      expect(decoded.offline, isFalse);
    });

    test('offline defaults to false and round-trips when set', () {
      final session = _session().copyWith(offline: true);
      expect(session.offline, isTrue);
      expect(AuthSession.fromJson(session.toJson())!.offline, isTrue);
      expect(AuthSession.fromJson(_session().toJson())!.offline, isFalse);
    });

    test('rejects an unknown role or a missing uid', () {
      expect(
        AuthSession.fromJson(<String, dynamic>{
          'role': 'admin',
          'uid': _uid,
        }),
        isNull,
      );
      expect(
        AuthSession.fromJson(<String, dynamic>{'role': 'guard'}),
        isNull,
      );
    });
  });

  group('SessionSnapshotStore', () {
    late _MemorySecureStore storage;
    late DateTime clock;

    SessionSnapshotStore build() =>
        SessionSnapshotStore(storage: storage, now: () => clock);

    setUp(() {
      storage = _MemorySecureStore();
      clock = _now;
    });

    test('saves and loads the session bound to the same uid', () async {
      final store = build();
      await store.save(_session());
      expect(storage.values, contains(SessionSnapshotStore.storageKey));

      final snapshot = await store.load(_uid);
      expect(snapshot, isNotNull);
      expect(snapshot!.session.uid, _uid);
      expect(snapshot.session.role, AppRole.guard);
      expect(snapshot.session.displayName, 'Snapshot Guard');
      expect(snapshot.savedAt, _now);
    });

    test('returns null and clears an expired snapshot', () async {
      final store = build();
      await store.save(_session());

      clock = _now.add(SessionSnapshotStore.maxAge + const Duration(minutes: 1));
      expect(await store.load(_uid), isNull);
      expect(
        storage.values.containsKey(SessionSnapshotStore.storageKey),
        isFalse,
        reason: 'expired entries are removed',
      );
    });

    test('keeps a snapshot inside the 24h window', () async {
      final store = build();
      await store.save(_session());
      clock = _now.add(const Duration(hours: 23, minutes: 59));
      expect(await store.load(_uid), isNotNull);
    });

    test('returns null and clears a snapshot for another uid', () async {
      final store = build();
      await store.save(_session());
      expect(await store.load('uid-someone-else'), isNull);
      expect(
        storage.values.containsKey(SessionSnapshotStore.storageKey),
        isFalse,
      );
    });

    test('corrupt payloads are discarded and cleared', () async {
      final store = build();
      storage.values[SessionSnapshotStore.storageKey] = '{not json';
      expect(await store.load(_uid), isNull);
      expect(
        storage.values.containsKey(SessionSnapshotStore.storageKey),
        isFalse,
      );

      // Valid JSON with an unknown role is corrupt for our purposes.
      storage.values[SessionSnapshotStore.storageKey] = jsonEncode(
        <String, dynamic>{
          'session': <String, dynamic>{'role': 'admin', 'uid': _uid},
          'savedAt': _now.toIso8601String(),
        },
      );
      expect(await store.load(_uid), isNull);
      expect(
        storage.values.containsKey(SessionSnapshotStore.storageKey),
        isFalse,
      );
    });

    test('a future savedAt beyond clock-skew tolerance is discarded', () async {
      final store = build();
      await store.save(_session());
      clock = _now.subtract(const Duration(days: 2));
      expect(await store.load(_uid), isNull);
    });

    test('clear removes the snapshot', () async {
      final store = build();
      await store.save(_session());
      await store.clear();
      expect(storage.values, isEmpty);
      expect(await store.load(_uid), isNull);
    });

    test('never overwrites the snapshot with an offline session', () async {
      final store = build();
      await store.save(_session());
      await store.save(_session().copyWith(offline: true));
      final snapshot = await store.load(_uid);
      expect(snapshot, isNotNull);
      expect(snapshot!.session.offline, isFalse);
    });

    test('storage failures degrade to "no snapshot" without throwing',
        () async {
      storage.failAll = true;
      final store = build();
      await store.save(_session());
      expect(await store.load(_uid), isNull);
      await store.clear();
    });
  });

  group('AuthSessionNotifier offline grace (F-23)', () {
    test('restores the snapshot with offline=true on a transport failure',
        () async {
      final authState = _FakeAuthStateSource(_uid);
      final repository = _FakeAuthRepository()
        ..resolveError = const AuthoritativeSessionTransportError();
      final storage = _MemorySecureStore();
      final snapshotStore = SessionSnapshotStore(
        storage: storage,
        now: () => _now,
      );
      await snapshotStore.save(_session());
      final container = _container(
        authState: authState,
        repository: repository,
        snapshotStore: snapshotStore,
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      final resolved = await container.read(authSessionProvider.future);

      expect(resolved, isNotNull);
      expect(resolved!.uid, _uid);
      expect(resolved.offline, isTrue);
      expect(repository.signOutCalls, 0, reason: 'transport is not denial');
      expect(container.read(authSessionProvider).valueOrNull?.offline, isTrue);
      expect(container.read(sessionOfflineProvider), isTrue);
    });

    test('fails closed on a transport failure with no snapshot', () async {
      final authState = _FakeAuthStateSource(_uid);
      final repository = _FakeAuthRepository()
        ..resolveError = const AuthoritativeSessionTransportError();
      final container = _container(
        authState: authState,
        repository: repository,
        snapshotStore: SessionSnapshotStore(
          storage: _MemorySecureStore(),
          now: () => _now,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      expect(await container.read(authSessionProvider.future), isNull);
      expect(repository.signOutCalls, 1);
    });

    test('an expired snapshot does not grant an offline session', () async {
      final authState = _FakeAuthStateSource(_uid);
      final repository = _FakeAuthRepository()
        ..resolveError = const AuthoritativeSessionTransportError();
      var clock = _now;
      final store = SessionSnapshotStore(
        storage: _MemorySecureStore(),
        now: () => clock,
      );
      await store.save(_session());
      clock = _now.add(
        SessionSnapshotStore.maxAge + const Duration(minutes: 1),
      );
      final container = _container(
        authState: authState,
        repository: repository,
        snapshotStore: store,
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      expect(await container.read(authSessionProvider.future), isNull);
      expect(repository.signOutCalls, 1);
    });

    test('saves the snapshot after an authoritative resolution', () async {
      final authState = _FakeAuthStateSource(_uid);
      final repository = _FakeAuthRepository()
        ..resolver = () async => _session();
      final storage = _MemorySecureStore();
      final container = _container(
        authState: authState,
        repository: repository,
        snapshotStore: SessionSnapshotStore(
          storage: storage,
          now: () => _now,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      final resolved = await container.read(authSessionProvider.future);
      expect(resolved?.offline, isFalse);
      await _flush();

      expect(
        storage.values.containsKey(SessionSnapshotStore.storageKey),
        isTrue,
        reason: 'successful resolution is persisted for offline cold start',
      );
    });

    test('a 401 clears the snapshot and fails closed', () async {
      final authState = _FakeAuthStateSource(_uid);
      final storage = _MemorySecureStore();
      final snapshotStore = SessionSnapshotStore(
        storage: storage,
        now: () => _now,
      );
      await snapshotStore.save(_session());
      final repository = _FakeAuthRepository()
        ..resolveError = const AuthoritativeSessionDeniedError(401);
      final container = _container(
        authState: authState,
        repository: repository,
        snapshotStore: snapshotStore,
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      expect(await container.read(authSessionProvider.future), isNull);
      await _flush();
      expect(repository.signOutCalls, 1);
      expect(
        storage.values.containsKey(SessionSnapshotStore.storageKey),
        isFalse,
        reason: 'an authoritative denial invalidates the offline grace',
      );
    });

    test('sign-out clears the snapshot', () async {
      final authState = _FakeAuthStateSource(_uid);
      final storage = _MemorySecureStore();
      final snapshotStore = SessionSnapshotStore(
        storage: storage,
        now: () => _now,
      );
      await snapshotStore.save(_session());
      final repository = _FakeAuthRepository()
        ..resolver = () async => _session();
      final container = _container(
        authState: authState,
        repository: repository,
        snapshotStore: snapshotStore,
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      expect(await container.read(authSessionProvider.future), isNotNull);
      await container.read(authControllerProvider).signOut();
      await _flush();

      expect(
        storage.values.containsKey(SessionSnapshotStore.storageKey),
        isFalse,
      );
    });
  });
}

AuthSession _session() {
  return const AuthSession(
    role: AppRole.guard,
    displayName: 'Snapshot Guard',
    primaryId: 'CISS/2026/001',
    uid: _uid,
    email: 'guard@cissindia.co.in',
  );
}

ProviderContainer _container({
  required _FakeAuthStateSource authState,
  required _FakeAuthRepository repository,
  required SessionSnapshotStore snapshotStore,
}) {
  return ProviderContainer(
    overrides: <Override>[
      firebaseAuthStateSourceProvider.overrideWithValue(authState),
      authRepositoryProvider.overrideWithValue(repository),
      sessionSnapshotStoreProvider.overrideWithValue(snapshotStore),
      authTopicRefreshProvider.overrideWithValue(() async {}),
    ],
  );
}

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};
  bool failAll = false;

  @override
  Future<String?> read(String key) async {
    if (failAll) throw StateError('keychain unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failAll) throw StateError('keychain unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failAll) throw StateError('keychain unavailable');
    values.remove(key);
  }
}

class _FakeAuthStateSource implements FirebaseAuthStateSource {
  _FakeAuthStateSource(this.currentUid);

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

class _FakeAuthRepository implements AuthRepository {
  Future<AuthSession?> Function()? resolver;
  Object? resolveError;
  int signOutCalls = 0;

  @override
  Future<AuthSession?> resolveCurrentSession() async {
    if (resolveError != null) throw resolveError!;
    return resolver?.call();
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
