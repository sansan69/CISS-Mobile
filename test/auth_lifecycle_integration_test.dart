import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:ciss_mobile/core/auth/biometric_service.dart';
import 'package:ciss_mobile/core/auth/app_lock_preferences.dart';
import 'package:ciss_mobile/core/auth/firebase_auth_state_source.dart';
import 'package:ciss_mobile/core/auth/saved_accounts_service.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/network/auth_repository.dart';
import 'package:ciss_mobile/core/network/authenticated_identity_mismatch_error.dart';
import 'package:ciss_mobile/core/network/authoritative_session_error.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/auth/application/biometric_setup_controller.dart';
import 'package:ciss_mobile/features/auth/presentation/auth_gate_screen.dart';
import 'package:ciss_mobile/shared/widgets/biometric_setup_sheet.dart';

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

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.guardSession,
    this.fieldOfficerSession,
    this.onGuardSignIn,
    this.onSignOut,
    this.onVerifyGuardPin,
    this.onVerifyFieldOfficerPassword,
  });

  AuthSession? guardSession;
  AuthSession? fieldOfficerSession;
  FutureOr<void> Function()? onGuardSignIn;
  FutureOr<void> Function()? onSignOut;
  FutureOr<void> Function()? onVerifyGuardPin;
  FutureOr<void> Function()? onVerifyFieldOfficerPassword;
  int signOutCalls = 0;
  int guardVerificationCalls = 0;
  int fieldOfficerVerificationCalls = 0;
  String? fieldOfficerPassword;
  AuthSession? Function()? sessionForCurrentUser;
  Future<AuthSession?>? pendingResolution;
  Object? resolveError;

  @override
  Future<AuthSession?> resolveCurrentSession() async {
    if (resolveError != null) throw resolveError!;
    if (pendingResolution != null) return pendingResolution!;
    return sessionForCurrentUser?.call();
  }

  @override
  Future<AuthSession> signInGuard({
    required String loginIdOrPhone,
    required String pin,
  }) async {
    await onGuardSignIn?.call();
    return guardSession!;
  }

  @override
  Future<AuthSession> signInFieldOfficer({
    required String email,
    required String password,
  }) async {
    fieldOfficerPassword = password;
    return fieldOfficerSession!;
  }

  @override
  Future<void> verifyCurrentGuardPin({
    required AuthSession expectedSession,
    required String loginIdOrPhone,
    required String pin,
  }) async {
    guardVerificationCalls += 1;
    await onVerifyGuardPin?.call();
  }

  @override
  Future<void> verifyCurrentFieldOfficerPassword({
    required AuthSession expectedSession,
    required String email,
    required String password,
  }) async {
    fieldOfficerVerificationCalls += 1;
    fieldOfficerPassword = password;
    await onVerifyFieldOfficerPassword?.call();
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    await onSignOut?.call();
  }
}

class _FakeSavedAccountsService extends SavedAccountsService {
  _FakeSavedAccountsService({this.save});

  Future<void> Function(SavedAccount account)? save;
  final List<SavedAccount> saved = <SavedAccount>[];

  @override
  Future<SavedAccount?> findForSession(AuthSession session) async {
    for (final account in saved) {
      if (account.matchesSession(session)) return account;
    }
    return null;
  }

  @override
  Future<void> saveAccount(SavedAccount account) async {
    await save?.call(account);
    saved.removeWhere(
      (existing) =>
          (existing.role == account.role &&
              existing.loginId == account.loginId) ||
          (account.uid.isNotEmpty &&
              existing.role == account.role &&
              existing.uid == account.uid),
    );
    saved.add(account);
  }

  @override
  Future<bool> isBiometricAppLockEnabledFor(AuthSession session) async =>
      saved.any(
        (SavedAccount account) =>
            account.biometricEnabled && account.matchesSession(session),
      );

  @override
  Future<void> setBiometricEnabled({
    required String role,
    required String uid,
    required bool enabled,
  }) async {
    for (var index = 0; index < saved.length; index++) {
      final account = saved[index];
      if (account.role == role && account.uid == uid) {
        saved[index] = account.withUpdated(biometricEnabled: enabled);
      }
    }
  }
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService({this.pendingAuthentication});

  final Completer<BiometricAuthOutcome>? pendingAuthentication;
  int fingerprintCalls = 0;

  @override
  Future<FingerprintSupport> checkFingerprintSupport() async {
    return const FingerprintSupport(
      availability: FingerprintAvailability.supported,
      enrolledBiometrics: [],
    );
  }

  @override
  Future<BiometricAuthOutcome> authenticateFingerprint({
    required String localizedReason,
  }) async {
    fingerprintCalls += 1;
    return pendingAuthentication?.future ?? BiometricAuthOutcome.success;
  }
}

class _ScriptedBiometricService extends BiometricService {
  _ScriptedBiometricService(this._outcomes);

  final List<Completer<BiometricAuthOutcome>> _outcomes;
  int fingerprintCalls = 0;

  @override
  Future<FingerprintSupport> checkFingerprintSupport() async {
    return const FingerprintSupport(
      availability: FingerprintAvailability.supported,
      enrolledBiometrics: <BiometricType>[],
    );
  }

  @override
  Future<BiometricAuthOutcome> authenticateFingerprint({
    required String localizedReason,
  }) {
    fingerprintCalls += 1;
    return _outcomes.removeAt(0).future;
  }
}

class _FixedSessionNotifier extends AuthSessionNotifier {
  _FixedSessionNotifier(this.session);

  final AuthSession? session;

  @override
  Future<AuthSession?> build() async => session;
}

AuthSession _session({
  AppRole role = AppRole.guard,
  String uid = 'firebase-guard-uid',
}) {
  return AuthSession(
    role: role,
    displayName: 'Test User',
    primaryId: 'CISS/2026/001',
    uid: uid,
    email: 'officer@cissindia.co.in',
  );
}

ProviderContainer _container({
  required _FakeAuthStateSource authState,
  required _FakeAuthRepository repository,
  required _FakeSavedAccountsService accounts,
  BiometricService? biometrics,
  Future<void> Function()? notificationCleanup,
  Future<void> Function()? trackingCleanup,
}) {
  return ProviderContainer(
    overrides: <Override>[
      firebaseAuthStateSourceProvider.overrideWithValue(authState),
      authRepositoryProvider.overrideWithValue(repository),
      savedAccountsServiceProvider.overrideWithValue(accounts),
      authTopicRefreshProvider.overrideWithValue(() async {}),
      if (notificationCleanup != null)
        authNotificationCleanupProvider.overrideWithValue(notificationCleanup),
      if (trackingCleanup != null)
        authTrackingCleanupProvider.overrideWithValue(trackingCleanup),
      if (biometrics != null)
        biometricServiceProvider.overrideWithValue(biometrics),
    ],
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('controller-managed auth lifecycle', () {
    test(
      'does not publish a Firebase sign-in event before metadata persists',
      () async {
        final authState = _FakeAuthStateSource();
        final session = _session();
        final metadataWrite = Completer<void>();
        final repository = _FakeAuthRepository(
          guardSession: session,
          onGuardSignIn: () => authState.emit(session.uid),
        );
        repository.sessionForCurrentUser = () => session;
        final accounts = _FakeSavedAccountsService(
          save: (_) => metadataWrite.future,
        );
        final container = _container(
          authState: authState,
          repository: repository,
          accounts: accounts,
        );
        addTearDown(container.dispose);
        addTearDown(authState.dispose);

        await container.read(authSessionProvider.future);
        final signIn = container
            .read(authControllerProvider)
            .signInAsGuard(loginIdOrPhone: ' CISS/2026/001 ', pin: '1234');
        await _flush();

        expect(container.read(authSessionProvider).valueOrNull, isNull);
        expect(accounts.saved, isEmpty);

        metadataWrite.complete();
        await expectLater(signIn, completion(session));
        expect(container.read(authSessionProvider).valueOrNull, same(session));
        expect(accounts.saved.single.uid, session.uid);
      },
    );

    test('rejects a role-mismatched login and signs Firebase out', () async {
      final authState = _FakeAuthStateSource();
      final wrongRole = _session(role: AppRole.fieldOfficer);
      final repository = _FakeAuthRepository(
        guardSession: wrongRole,
        onGuardSignIn: () => authState.emit(wrongRole.uid),
        onSignOut: () => authState.emit(null),
      );
      final container = _container(
        authState: authState,
        repository: repository,
        accounts: _FakeSavedAccountsService(),
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      await container.read(authSessionProvider.future);
      await expectLater(
        container
            .read(authControllerProvider)
            .signInAsGuard(loginIdOrPhone: 'CISS/2026/001', pin: '1234'),
        throwsA(isA<StateError>()),
      );

      expect(repository.signOutCalls, 1);
      expect(container.read(authSessionProvider).valueOrNull, isNull);
    });

    test('fails closed when account metadata cannot be written', () async {
      final authState = _FakeAuthStateSource();
      final session = _session();
      final repository = _FakeAuthRepository(
        guardSession: session,
        onGuardSignIn: () => authState.emit(session.uid),
        onSignOut: () => authState.emit(null),
      );
      final container = _container(
        authState: authState,
        repository: repository,
        accounts: _FakeSavedAccountsService(
          save: (_) => throw StateError('secure storage unavailable'),
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      await container.read(authSessionProvider.future);
      await expectLater(
        container
            .read(authControllerProvider)
            .signInAsGuard(loginIdOrPhone: 'CISS/2026/001', pin: '1234'),
        throwsA(isA<StateError>()),
      );

      expect(repository.signOutCalls, 1);
      expect(container.read(authSessionProvider).valueOrNull, isNull);
    });

    test(
      'restores and clears sessions from external Firebase events',
      () async {
        final authState = _FakeAuthStateSource();
        final restored = _session(uid: 'restored-firebase-uid');
        final repository = _FakeAuthRepository();
        repository.sessionForCurrentUser =
            () => authState.currentUid == restored.uid ? restored : null;
        final container = _container(
          authState: authState,
          repository: repository,
          accounts: _FakeSavedAccountsService(),
        );
        addTearDown(container.dispose);
        addTearDown(authState.dispose);

        await container.read(authSessionProvider.future);
        authState.emit(restored.uid);
        await _flush();
        expect(container.read(authSessionProvider).valueOrNull, same(restored));

        authState.emit(null);
        await _flush();
        expect(container.read(authSessionProvider).valueOrNull, isNull);
      },
    );

    test(
      'sign-out clears UI immediately and survives cleanup failures',
      () async {
        final authState = _FakeAuthStateSource();
        final session = _session();
        authState.currentUid = session.uid;
        final repository = _FakeAuthRepository(
          onSignOut: () => authState.emit(null),
        )..sessionForCurrentUser = () => session;
        final cleanupStarted = Completer<void>();
        final allowCleanupToFinish = Completer<void>();
        final container = _container(
          authState: authState,
          repository: repository,
          accounts: _FakeSavedAccountsService(),
          notificationCleanup: () async {
            cleanupStarted.complete();
            await allowCleanupToFinish.future;
          },
          trackingCleanup: () async => throw StateError('tracking unavailable'),
        );
        addTearDown(container.dispose);
        addTearDown(authState.dispose);

        await container.read(authSessionProvider.future);
        await container.read(authControllerProvider).signOut();
        await cleanupStarted.future;

        expect(container.read(authSessionProvider).valueOrNull, isNull);
        expect(repository.signOutCalls, 1);

        allowCleanupToFinish.complete();
      },
    );

    test('logout suppresses an in-flight auth-listener resolution', () async {
      final authState = _FakeAuthStateSource();
      final session = _session();
      final resolution = Completer<AuthSession?>();
      final repository = _FakeAuthRepository(
        onSignOut: () => authState.emit(null),
      )..pendingResolution = resolution.future;
      final container = _container(
        authState: authState,
        repository: repository,
        accounts: _FakeSavedAccountsService(),
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      await container.read(authSessionProvider.future);
      authState.emit(session.uid);
      await _flush();

      await container.read(authControllerProvider).signOut();
      resolution.complete(session);
      await _flush();

      expect(repository.signOutCalls, 1);
      expect(container.read(authSessionProvider).valueOrNull, isNull);
    });

    test(
      'field-officer passwords retain leading and trailing whitespace',
      () async {
        final authState = _FakeAuthStateSource();
        final session = _session(role: AppRole.fieldOfficer);
        final repository = _FakeAuthRepository(fieldOfficerSession: session);
        final container = _container(
          authState: authState,
          repository: repository,
          accounts: _FakeSavedAccountsService(),
        );
        addTearDown(container.dispose);
        addTearDown(authState.dispose);

        authState.currentUid = session.uid;
        await container
            .read(authControllerProvider)
            .signInAsFieldOfficer(
              email: session.email!,
              password: '  exact password  ',
            );

        expect(repository.fieldOfficerPassword, '  exact password  ');
      },
    );

    test(
      'identity mismatch clears the exposed session instead of falling back',
      () async {
        final authState = _FakeAuthStateSource();
        final repository =
            _FakeAuthRepository()
              ..resolveError = const AuthenticatedIdentityMismatchError(
                firebaseUid: 'active-uid',
                backendUid: 'different-uid',
              );
        final container = _container(
          authState: authState,
          repository: repository,
          accounts: _FakeSavedAccountsService(),
        );
        addTearDown(container.dispose);
        addTearDown(authState.dispose);

        await container.read(authSessionProvider.future);
        authState.emit('active-uid');
        await _flush();

        expect(container.read(authSessionProvider).valueOrNull, isNull);
        expect(container.read(authSessionProvider).hasError, isFalse);
      },
    );

    for (final role in <AppRole>[AppRole.guard, AppRole.fieldOfficer]) {
      test(
        'cached ${role.name} session is cleared and signed out when authoritative refresh is denied',
        () async {
          final authState = _FakeAuthStateSource();
          final session = _session(role: role, uid: '${role.name}-uid');
          final repository =
              _FakeAuthRepository()..sessionForCurrentUser = () => session;
          final container = _container(
            authState: authState,
            repository: repository,
            accounts: _FakeSavedAccountsService(),
          );
          addTearDown(container.dispose);
          addTearDown(authState.dispose);

          authState.currentUid = session.uid;
          await container.read(authSessionProvider.future);
          expect(
            container.read(authSessionProvider).valueOrNull,
            same(session),
          );

          repository.resolveError = const AuthoritativeSessionDeniedError(401);
          authState.emit(session.uid);
          await _flush();

          expect(container.read(authSessionProvider).valueOrNull, isNull);
          expect(repository.signOutCalls, 1);
        },
      );
    }

    test(
      'account A is never retained when account B is authoritatively denied',
      () async {
        final authState = _FakeAuthStateSource();
        final accountA = _session(uid: 'account-a');
        final repository =
            _FakeAuthRepository()
              ..sessionForCurrentUser =
                  () => authState.currentUid == accountA.uid ? accountA : null;
        final container = _container(
          authState: authState,
          repository: repository,
          accounts: _FakeSavedAccountsService(),
        );
        addTearDown(container.dispose);
        addTearDown(authState.dispose);

        authState.currentUid = accountA.uid;
        await container.read(authSessionProvider.future);
        expect(container.read(authSessionProvider).valueOrNull, same(accountA));

        authState.emit('account-b');
        expect(container.read(authSessionProvider).valueOrNull, isNull);
        await _flush();

        expect(container.read(authSessionProvider).valueOrNull, isNull);
        expect(repository.signOutCalls, 1);
      },
    );

    test(
      'credential recovery clears an existing UID app lock before session exposure',
      () async {
        final authState = _FakeAuthStateSource();
        final session = _session();
        final accounts =
            _FakeSavedAccountsService()
              ..saved.add(
                SavedAccount(
                  role: session.role.name,
                  loginId: session.primaryId,
                  displayName: session.displayName,
                  lastLoginAt: DateTime.now(),
                  uid: session.uid,
                  biometricEnabled: true,
                ),
              );
        final repository = _FakeAuthRepository(
          guardSession: session,
          onGuardSignIn: () => authState.emit(session.uid),
        );
        final container = _container(
          authState: authState,
          repository: repository,
          accounts: accounts,
        );
        addTearDown(container.dispose);
        addTearDown(authState.dispose);

        await container.read(authSessionProvider.future);
        await container
            .read(authControllerProvider)
            .signInAsGuard(loginIdOrPhone: session.primaryId, pin: '1234');

        expect(accounts.saved.single.biometricEnabled, isFalse);
        expect(container.read(authSessionProvider).valueOrNull, same(session));
      },
    );
  });

  test(
    'biometric setup refuses a credential verified for another identity',
    () async {
      final session = _session();
      final authState = _FakeAuthStateSource()..currentUid = session.uid;
      final repository = _FakeAuthRepository(
        onVerifyGuardPin: () => authState.emit('different-firebase-uid'),
      )..sessionForCurrentUser = () => session;
      final biometrics = _FakeBiometricService();
      final accounts = _FakeSavedAccountsService();
      final container = _container(
        authState: authState,
        repository: repository,
        accounts: accounts,
        biometrics: biometrics,
      );
      addTearDown(container.dispose);

      await container.read(authSessionProvider.future);
      expect(container.read(authSessionProvider).valueOrNull, same(session));

      final controller = container.read(biometricSetupProvider.notifier);
      await controller.load(session: session);
      final result = await controller.enable(
        session: session,
        password: '1234',
      );

      expect(result.success, isFalse);
      expect(
        result.message,
        'Could not verify this account. Please sign in again.',
      );
      expect(biometrics.fingerprintCalls, 0);
      expect(accounts.saved, isEmpty);
      expect(repository.guardVerificationCalls, 1);
      expect(container.read(authSessionProvider).valueOrNull, isNull);
      await _flush();
      expect(container.read(authSessionProvider).valueOrNull, isNull);
    },
  );

  test(
    'field-officer biometric setup reauthenticates the active account in place',
    () async {
      final session = _session(role: AppRole.fieldOfficer, uid: 'officer-uid');
      final authState = _FakeAuthStateSource()..currentUid = session.uid;
      final repository = _FakeAuthRepository(
        onVerifyFieldOfficerPassword: () => authState.emit(session.uid),
      )..sessionForCurrentUser = () => session;
      final accounts = _FakeSavedAccountsService();
      final container = _container(
        authState: authState,
        repository: repository,
        accounts: accounts,
        biometrics: _FakeBiometricService(),
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      await container.read(authSessionProvider.future);
      final controller = container.read(biometricSetupProvider.notifier);
      await controller.load(session: session);
      final result = await controller.enable(
        session: session,
        password: '  exact officer password  ',
      );

      expect(result.success, isTrue);
      expect(repository.fieldOfficerVerificationCalls, 1);
      expect(repository.fieldOfficerPassword, '  exact officer password  ');
      expect(container.read(authSessionProvider).valueOrNull, same(session));
      expect(accounts.saved.single.uid, session.uid);
      expect(accounts.saved.single.biometricEnabled, isTrue);
    },
  );

  testWidgets(
    'biometric setup passes a Field Officer password without trimming',
    (WidgetTester tester) async {
      final session = _session(role: AppRole.fieldOfficer, uid: 'officer-uid');
      final authState = _FakeAuthStateSource()..currentUid = session.uid;
      final repository =
          _FakeAuthRepository()..sessionForCurrentUser = () => session;
      final container = _container(
        authState: authState,
        repository: repository,
        accounts: _FakeSavedAccountsService(),
        biometrics: _FakeBiometricService(),
      );
      addTearDown(container.dispose);
      addTearDown(authState.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: BiometricSetupSheet(session: session)),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        '  exact officer password  ',
      );
      await tester.tap(find.text('ENABLE STRONG BIOMETRIC APP LOCK'));
      await tester.pump();
      await tester.pump();

      expect(repository.fieldOfficerPassword, '  exact officer password  ');
      expect(repository.fieldOfficerVerificationCalls, 1);
    },
  );

  testWidgets('AuthGate holds a uid-bound account behind its app lock', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final pendingFingerprint = Completer<BiometricAuthOutcome>();
    final accounts =
        _FakeSavedAccountsService()
          ..saved.add(
            SavedAccount(
              role: session.role.name,
              loginId: session.primaryId,
              displayName: session.displayName,
              lastLoginAt: DateTime.now(),
              uid: session.uid,
              biometricEnabled: true,
            ),
          );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          savedAccountsServiceProvider.overrideWithValue(accounts),
          biometricServiceProvider.overrideWithValue(
            _FakeBiometricService(pendingAuthentication: pendingFingerprint),
          ),
        ],
        child: const MaterialApp(home: AuthGateScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('App Locked'), findsOneWidget);
    expect(find.text('Sign in with PIN or password'), findsOneWidget);
    pendingFingerprint.complete(BiometricAuthOutcome.failed);
  });

  testWidgets(
    'enabling the app lock relocks the active gate after background and resume',
    (WidgetTester tester) async {
      final session = _session();
      final firstPrompt = Completer<BiometricAuthOutcome>();
      final secondPrompt = Completer<BiometricAuthOutcome>();
      final biometrics = _ScriptedBiometricService(
        <Completer<BiometricAuthOutcome>>[firstPrompt, secondPrompt],
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          savedAccountsServiceProvider.overrideWithValue(
            _FakeSavedAccountsService(),
          ),
          biometricServiceProvider.overrideWithValue(biometrics),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AuthGateScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('App Locked'), findsNothing);

      container.read(appLockPreferencesProvider.notifier).setFor(session, true);
      await tester.pump();
      await tester.pump();
      expect(find.text('App Locked'), findsOneWidget);
      expect(biometrics.fingerprintCalls, 1);

      firstPrompt.complete(BiometricAuthOutcome.success);
      await tester.pump();
      await tester.pump();
      expect(find.text('App Locked'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(find.text('App Locked'), findsOneWidget);
      expect(biometrics.fingerprintCalls, 2);
      secondPrompt.complete(BiometricAuthOutcome.failed);
    },
  );

  test('session UID and guard PIN identity failures are handled safely', () {
    expect(
      MobileRepository.authoritativeSessionUid(
        firebaseUid: 'firebase-uid',
        backendUid: 'firebase-uid',
      ),
      'firebase-uid',
    );
    expect(
      () => MobileRepository.authoritativeSessionUid(
        firebaseUid: 'firebase-uid',
        backendUid: 'backend-uid',
      ),
      throwsA(isA<AuthenticatedIdentityMismatchError>()),
    );
    expect(
      MobileRepository.allowsClaimsFallback(
        const AuthenticatedIdentityMismatchError(
          firebaseUid: 'firebase-uid',
          backendUid: 'backend-uid',
        ),
      ),
      isFalse,
    );
    expect(
      MobileRepository.allowsClaimsFallback(StateError('offline')),
      isFalse,
    );
    expect(
      MobileRepository.guardPinSetupClientMessage(
        serverMessage: 'Employee was not found for this phone number.',
      ),
      'Could not verify those details. Check them and try again.',
    );
  });
}
