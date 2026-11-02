import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/app_lock_controller.dart';
import 'package:ciss_mobile/core/auth/app_lock_overlay.dart';
import 'package:ciss_mobile/core/auth/app_lock_preferences.dart';
import 'package:ciss_mobile/core/auth/biometric_service.dart';
import 'package:ciss_mobile/core/auth/firebase_auth_state_source.dart';
import 'package:ciss_mobile/core/auth/saved_accounts_service.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/network/auth_repository.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/security/screen_security.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fakes. Real biometrics are never touched: the prompt is a completer the test
// decides the outcome of.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeAuthStateSource implements FirebaseAuthStateSource {
  @override
  String? currentUid;

  @override
  Stream<String?> get idTokenUidChanges => const Stream<String?>.empty();
}

class _FixedSessionNotifier extends AuthSessionNotifier {
  _FixedSessionNotifier(this.session);

  final AuthSession? session;

  @override
  Future<AuthSession?> build() async => session;
}

class _FakeSavedAccountsService extends SavedAccountsService {
  _FakeSavedAccountsService({
    this.accounts = const <SavedAccount>[],
    this.error,
  });

  final List<SavedAccount> accounts;
  final Object? error;

  @override
  Future<bool> isBiometricAppLockEnabledFor(AuthSession session) async {
    final thrown = error;
    if (thrown != null) throw thrown;
    return accounts.any(
      (SavedAccount account) =>
          account.biometricEnabled && account.matchesSession(session),
    );
  }
}

class _ScriptedBiometricService extends BiometricService {
  final List<Completer<BiometricAuthOutcome>> prompts =
      <Completer<BiometricAuthOutcome>>[];
  int fingerprintCalls = 0;

  @override
  Future<BiometricAuthOutcome> authenticateFingerprint({
    required String localizedReason,
  }) {
    fingerprintCalls += 1;
    final prompt = Completer<BiometricAuthOutcome>();
    prompts.add(prompt);
    return prompt.future;
  }

  /// Completes the most recent (still pending) prompt.
  void completeLast(BiometricAuthOutcome outcome) {
    prompts.last.complete(outcome);
  }
}

class _RecordingAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<AuthSession?> resolveCurrentSession() async => null;

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
  }) async {}

  @override
  Future<void> verifyCurrentFieldOfficerPassword({
    required AuthSession expectedSession,
    required String email,
    required String password,
  }) async {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Harness
// ─────────────────────────────────────────────────────────────────────────────

/// Workspace shell used instead of the real Guard/FO shell: its marker text
/// stands in for "sensitive content that must never be reachable while locked".
class _WorkspaceHome extends StatelessWidget {
  const _WorkspaceHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Workspace marker'),
            const SizedBox(height: 12),
            TextButton(
              onPressed:
                  () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const _SecretRoute(),
                    ),
                  ),
              child: const Text('Open private record'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for a pushed private detail route.
class _SecretRoute extends StatelessWidget {
  const _SecretRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Pushed secret marker')));
  }
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
  );
}

SavedAccount _storedAccount(AuthSession session, {bool enabled = true}) {
  return SavedAccount(
    role: session.role.name,
    loginId: session.primaryId,
    displayName: session.displayName,
    lastLoginAt: DateTime.now(),
    uid: session.uid,
    biometricEnabled: enabled,
  );
}

ProviderContainer _container({
  required AuthSession session,
  required _FakeSavedAccountsService accounts,
  required _ScriptedBiometricService biometrics,
  AuthRepository? repository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      firebaseAuthStateSourceProvider.overrideWithValue(_FakeAuthStateSource()),
      authSessionProvider.overrideWith(() => _FixedSessionNotifier(session)),
      savedAccountsServiceProvider.overrideWithValue(accounts),
      biometricServiceProvider.overrideWithValue(biometrics),
      authNotificationCleanupProvider.overrideWithValue(() async {}),
      authTrackingCleanupProvider.overrideWithValue(() async {}),
      authLocalDataPurgeProvider.overrideWithValue(() async {}),
      if (repository != null)
        authRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      // Exactly how `lib/app/app.dart` mounts it: above the navigator, which is
      // what makes every pushed route covered.
      builder:
          (BuildContext context, Widget? child) =>
              AppLockOverlay(child: child ?? const SizedBox.shrink()),
      home: const _WorkspaceHome(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _pushSecretRoute(WidgetTester tester) async {
  await tester.tap(find.text('Open private record'));
  await tester.pumpAndSettle();
  expect(find.text('Pushed secret marker').hitTestable(), findsOneWidget);
}

Future<void> _backgroundAndResume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await _settle(tester);
}

Future<void> _sendSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a cold start with a locked session covers the workspace before it prompts',
    (WidgetTester tester) async {
      final session = _session();
      final biometrics = _ScriptedBiometricService();
      final container = _container(
        session: session,
        accounts: _FakeSavedAccountsService(
          accounts: <SavedAccount>[_storedAccount(session)],
        ),
        biometrics: biometrics,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await _settle(tester);

      expect(find.text('App Locked'), findsOneWidget);
      expect(find.text('Workspace marker').hitTestable(), findsNothing);
      expect(biometrics.fingerprintCalls, 1);

      biometrics.completeLast(BiometricAuthOutcome.success);
      await _settle(tester);

      expect(find.text('App Locked'), findsNothing);
      expect(find.text('Workspace marker').hitTestable(), findsOneWidget);
      // A successful unlock must not be followed by a second prompt.
      expect(biometrics.fingerprintCalls, 1);
    },
  );

  testWidgets('the covered workspace is excluded from focus and semantics', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final biometrics = _ScriptedBiometricService();
    final container = _container(
      session: session,
      accounts: _FakeSavedAccountsService(
        accounts: <SavedAccount>[_storedAccount(session)],
      ),
      biometrics: biometrics,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.text('App Locked'), findsOneWidget);
    final excludes =
        tester.widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics));
    expect(excludes.any((widget) => widget.excluding), isTrue);
    final lockedScopes =
        tester.widgetList<FocusScope>(find.byType(FocusScope));
    expect(
      lockedScopes.any((scope) => scope.descendantsAreFocusable == false),
      isTrue,
    );

    biometrics.completeLast(BiometricAuthOutcome.success);
    await _settle(tester);

    expect(find.text('App Locked'), findsNothing);
    expect(find.bySemanticsLabel('Open private record'), findsOneWidget);
  });

  testWidgets('a pushed route stays covered after background and resume', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final biometrics = _ScriptedBiometricService();
    final container = _container(
      session: session,
      accounts: _FakeSavedAccountsService(
        accounts: <SavedAccount>[_storedAccount(session)],
      ),
      biometrics: biometrics,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await _settle(tester);
    biometrics.completeLast(BiometricAuthOutcome.success);
    await _settle(tester);
    expect(find.text('App Locked'), findsNothing);

    await _pushSecretRoute(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // The lock arms as soon as the app leaves the foreground, so the recents
    // snapshot is covered even before the resume prompt.
    expect(container.read(appLockControllerProvider).armed, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(find.text('App Locked'), findsOneWidget);
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(biometrics.fingerprintCalls, 2);
    // The pushed route is still mounted underneath, but is neither visible nor
    // hittable.
    expect(find.text('Pushed secret marker'), findsOneWidget);
    expect(find.text('Pushed secret marker').hitTestable(), findsNothing);

    // Android back is swallowed while locked: the covered route must not pop.
    await _sendSystemBack(tester);
    expect(find.text('App Locked'), findsOneWidget);
    expect(find.text('Pushed secret marker'), findsOneWidget);

    biometrics.completeLast(BiometricAuthOutcome.failed);
    await _settle(tester);
  });

  testWidgets(
    'a cancelled prompt keeps the lock on top, never loops, and can be retried',
    (WidgetTester tester) async {
      final session = _session();
      final biometrics = _ScriptedBiometricService();
      final container = _container(
        session: session,
        accounts: _FakeSavedAccountsService(
          accounts: <SavedAccount>[_storedAccount(session)],
        ),
        biometrics: biometrics,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await _settle(tester);
      biometrics.completeLast(BiometricAuthOutcome.success);
      await _settle(tester);

      await _pushSecretRoute(tester);
      await _backgroundAndResume(tester);
      expect(biometrics.fingerprintCalls, 2);

      // Cancel / fail the prompt.
      biometrics.completeLast(BiometricAuthOutcome.failed);
      await _settle(tester);

      expect(find.text('App Locked'), findsOneWidget);
      expect(find.text(kAppLockFailedMessage), findsOneWidget);
      expect(find.text('Pushed secret marker').hitTestable(), findsNothing);
      expect(find.text('Sign in with PIN or password'), findsOneWidget);

      // No prompt loop: further frames and lifecycle noise must not re-prompt.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(biometrics.fingerprintCalls, 2);
      expect(find.text('Pushed secret marker').hitTestable(), findsNothing);

      // Explicit retry triggers exactly one more prompt.
      await tester.tap(find.text('Try biometrics again'));
      await tester.pump();
      expect(biometrics.fingerprintCalls, 3);
      expect(find.text('Pushed secret marker').hitTestable(), findsNothing);

      biometrics.completeLast(BiometricAuthOutcome.success);
      await _settle(tester);
      expect(find.text('App Locked'), findsNothing);
      expect(find.text('Pushed secret marker').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('no lock is armed when the uid preference is off', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final biometrics = _ScriptedBiometricService();
    final container = _container(
      session: session,
      accounts: _FakeSavedAccountsService(
        accounts: <SavedAccount>[_storedAccount(session, enabled: false)],
      ),
      biometrics: biometrics,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.text('App Locked'), findsNothing);

    await _pushSecretRoute(tester);
    await _backgroundAndResume(tester);

    expect(find.text('App Locked'), findsNothing);
    expect(find.text('Pushed secret marker').hitTestable(), findsOneWidget);
    expect(biometrics.fingerprintCalls, 0);
  });

  testWidgets('the live preference arms the lock without a background cycle', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final biometrics = _ScriptedBiometricService();
    final container = _container(
      session: session,
      accounts: _FakeSavedAccountsService(
        accounts: <SavedAccount>[_storedAccount(session, enabled: false)],
      ),
      biometrics: biometrics,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.text('App Locked'), findsNothing);

    // The settings sheet publishes an enable here.
    container.read(appLockPreferencesProvider.notifier).setFor(session, true);
    await _settle(tester);

    expect(find.text('App Locked'), findsOneWidget);
    expect(biometrics.fingerprintCalls, 1);

    biometrics.completeLast(BiometricAuthOutcome.success);
    await _settle(tester);
    expect(find.text('App Locked'), findsNothing);
  });

  testWidgets('a transient inactive transition does not arm the lock', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final biometrics = _ScriptedBiometricService();
    final container = _container(
      session: session,
      accounts: _FakeSavedAccountsService(
        accounts: <SavedAccount>[_storedAccount(session)],
      ),
      biometrics: biometrics,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await _settle(tester);
    biometrics.completeLast(BiometricAuthOutcome.success);
    await _settle(tester);
    await _pushSecretRoute(tester);

    // System dialogs (the biometric prompt itself, permission prompts) report
    // `inactive` without the app leaving the foreground.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(container.read(appLockControllerProvider).armed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(find.text('App Locked'), findsNothing);
    expect(biometrics.fingerprintCalls, 1);
    expect(find.text('Pushed secret marker').hitTestable(), findsOneWidget);
  });

  test('FLAG_SECURE is cleared only when the last holder releases', () async {
    const channel = MethodChannel(secureWindowChannelName);
    final calls = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(
            (call.arguments as Map<Object?, Object?>)['secure']! as bool,
          );
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final security = ScreenSecurity(channel: channel, supported: true);
    await security.acquire('private-record');
    await security.acquire('profile');
    // A duplicate acquire for the same holder is not a new hold.
    await security.acquire('profile');
    expect(security.isSecure, isTrue);
    expect(calls, <bool>[true]);

    await security.release('private-record');
    expect(security.isSecure, isTrue);
    expect(calls, <bool>[true]);

    await security.release('profile');
    expect(security.isSecure, isFalse);
    expect(calls, <bool>[true, false]);

    await security.release('profile');
    expect(calls, <bool>[true, false]);
  });

  test(
    'fails closed and signs out when the durable preference is unreadable',
    () async {
      final session = _session();
      final repository = _RecordingAuthRepository();
      final container = _container(
        session: session,
        accounts: _FakeSavedAccountsService(
          error: StateError('secure storage unavailable'),
        ),
        biometrics: _ScriptedBiometricService(),
        repository: repository,
      );
      addTearDown(container.dispose);

      // Creating the controller starts preference resolution for the session.
      final subscription = container.listen<AppLockState>(
        appLockControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(authSessionProvider.future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.signOutCalls, 1);
      expect(container.read(appLockControllerProvider).armed, isFalse);
      expect(container.read(appLockControllerProvider).appLockEnabled, isFalse);
    },
  );
}
