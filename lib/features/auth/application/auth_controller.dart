import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/firebase_auth_state_source.dart';
import '../../../core/auth/legacy_biometric_credential_cleanup.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/fcm/providers.dart';
import '../../../core/location/background_tracking_service.dart';
import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/network/providers.dart';

/// Session key whose workspace has passed AuthGate's biometric and permission
/// onboarding checks. Notification detail routes remain behind this gate.
final workspaceAccessSessionKeyProvider = StateProvider<String?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
// Session notifier — owns the logged-in session state.
//
// It listens to Firebase idTokenChanges() so it reacts to sign-in / sign-out /
// token refresh automatically. It also exposes setSession() so the
// AuthController can inject the already-resolved session after a fresh login
// (instead of invalidating the provider and triggering a redundant second
// network call).
// ─────────────────────────────────────────────────────────────────────────────

class AuthSessionNotifier extends AsyncNotifier<AuthSession?> {
  StreamSubscription<String?>? _authSubscription;
  AuthSession? _cachedSession;
  bool _disposed = false;
  bool _controllerSignInInProgress = false;
  bool _identityVerificationInProgress = false;
  bool _logoutInProgress = false;
  int _authEventGeneration = 0;

  @override
  Future<AuthSession?> build() async {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    final authState = ref.watch(firebaseAuthStateSourceProvider);

    // Cancel any previous listener and await to prevent duplicate subscriptions.
    await _authSubscription?.cancel();
    _authSubscription = null;

    // Subscribe before resolving a session so a Firebase event that races with
    // startup cannot leave the UI with stale state.
    _authSubscription = authState.idTokenUidChanges.listen(_onAuthUidChanged);

    final uid = authState.currentUid;
    if (uid == null) {
      _cachedSession = null;
      return null;
    }

    // Every Firebase identity event is checked against the backend. A cached
    // same-UID session is not authorization and must never bypass it.
    return _resolveAndPublish(uid, publishToState: false);
  }

  void _onAuthUidChanged(String? uid) {
    if (_disposed) return;
    if (_controllerSignInInProgress ||
        _identityVerificationInProgress ||
        _logoutInProgress) {
      return;
    }
    unawaited(_resolveAndPublish(uid));
  }

  Future<AuthSession?> _resolveAndPublish(
    String? uid, {
    bool publishToState = true,
  }) async {
    if (_logoutInProgress) return null;
    final generation = ++_authEventGeneration;
    if (uid == null) {
      _cachedSession = null;
      if (publishToState && !_disposed) state = const AsyncData(null);
      return null;
    }

    // Never expose account A while Firebase has already changed to B.
    if (_cachedSession?.uid != uid && publishToState && !_disposed) {
      _cachedSession = null;
      state = const AsyncData(null);
    }

    try {
      final session =
          await ref.read(authRepositoryProvider).resolveCurrentSession();
      if (_disposed || generation != _authEventGeneration) return null;
      // A session is valid only for the Firebase identity that caused this
      // event. This also prevents an in-flight resolver from publishing after
      // another account signs in or out.
      if (ref.read(firebaseAuthStateSourceProvider).currentUid != uid ||
          session?.uid != uid) {
        if (ref.read(firebaseAuthStateSourceProvider).currentUid == uid) {
          await _failClosed(uid);
        }
        return null;
      }
      _cachedSession = session;
      if (publishToState) state = AsyncData(session);
      return session;
    } catch (_) {
      if (_disposed || generation != _authEventGeneration) return null;
      if (ref.read(firebaseAuthStateSourceProvider).currentUid == uid) {
        await _failClosed(uid);
      }
      return null;
    }
  }

  Future<void> _failClosed(String expectedUid) async {
    if (_disposed ||
        _logoutInProgress ||
        ref.read(firebaseAuthStateSourceProvider).currentUid != expectedUid) {
      return;
    }
    _cachedSession = null;
    state = const AsyncData(null);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // UI/cache state remains cleared even if Firebase refuses sign-out.
    }
  }

  /// Prevent Firebase events raised during a controller-owned sign-in from
  /// reaching AuthGate before the controller has persisted account metadata.
  void beginControllerSignIn() {
    if (_disposed) return;
    _logoutInProgress = false;
    _controllerSignInInProgress = true;
  }

  /// Inject a session after metadata persistence. Returns false when Firebase
  /// changed users during sign-in, in which case the caller must fail closed.
  bool setSession(AuthSession session) {
    final authStateUid = ref.read(firebaseAuthStateSourceProvider).currentUid;
    // The live Firebase session is only a fallback for when the auth-state
    // source has not yet reported a uid. Reading it when no Firebase app exists
    // (unit tests, very early startup) would throw, so guard it.
    final String? directUid =
        Firebase.apps.isNotEmpty
            ? ref.read(firebaseAuthProvider).currentUser?.uid
            : null;
    final activeUid = authStateUid ?? directUid;
    if (_disposed || activeUid != session.uid) {
      _controllerSignInInProgress = false;
      return false;
    }
    _controllerSignInInProgress = false;
    _logoutInProgress = false;
    _cachedSession = session;
    state = AsyncData(session);
    return true;
  }

  /// Re-enable normal Firebase event handling after an aborted controller
  /// sign-in. This preserves sign-out, restoration, and external auth events.
  Future<void> cancelControllerSignIn() async {
    if (_disposed) return;
    _controllerSignInInProgress = false;
    final uid = ref.read(firebaseAuthStateSourceProvider).currentUid;
    if (uid == null) {
      clearSession();
      return;
    }
    if (_cachedSession?.uid != uid) {
      await _resolveAndPublish(uid);
    }
  }

  bool _matchesActiveIdentity(AuthSession expected) {
    final exposed = state.valueOrNull;
    return ref.read(firebaseAuthStateSourceProvider).currentUid ==
            expected.uid &&
        (exposed == null ||
            (exposed.uid == expected.uid && exposed.role == expected.role));
  }

  /// Suppress token events during reauthentication. If the Firebase identity
  /// changes, completion clears the exposed session before AuthGate can see it.
  bool beginIdentityVerification(AuthSession expected) {
    if (_disposed ||
        _controllerSignInInProgress ||
        !_matchesActiveIdentity(expected)) {
      return false;
    }
    _identityVerificationInProgress = true;
    _authEventGeneration += 1;
    return true;
  }

  Future<bool> completeIdentityVerification(AuthSession expected) async {
    if (_disposed) return false;
    _identityVerificationInProgress = false;
    if (_matchesActiveIdentity(expected)) return true;
    clearSession();
    return false;
  }

  /// Clear the session (used on sign-out before the auth listener fires).
  void clearSession() {
    if (_disposed) return;
    _cachedSession = null;
    state = const AsyncData(null);
  }

  /// Clear exposed state and ignore all token events while Firebase signs out.
  /// This prevents a resolver that started before logout from republishing a
  /// session while cleanup work is still running.
  void beginSignOut() {
    if (_disposed) return;
    _logoutInProgress = true;
    _controllerSignInInProgress = false;
    _identityVerificationInProgress = false;
    _authEventGeneration += 1;
    clearSession();
  }
}

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
      AuthSessionNotifier.new,
    );

typedef FieldOfficerPasswordResetSender = Future<void> Function(String email);

typedef GuardPinSetupSender =
    Future<void> Function({
      required String employeeId,
      required String phoneNumber,
      required String dateOfBirth,
      required String pin,
    });

final Provider<FieldOfficerPasswordResetSender>
fieldOfficerPasswordResetSenderProvider =
    Provider<FieldOfficerPasswordResetSender>((Ref ref) {
      final repository = ref.read(mobileRepositoryProvider);
      return (String email) =>
          repository.sendFieldOfficerPasswordResetEmail(email: email);
    });

final Provider<GuardPinSetupSender> guardPinSetupSenderProvider =
    Provider<GuardPinSetupSender>((Ref ref) {
      final repository = ref.read(mobileRepositoryProvider);
      return ({
        required String employeeId,
        required String phoneNumber,
        required String dateOfBirth,
        required String pin,
      }) => repository.setupGuardPin(
        employeeId: employeeId,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        pin: pin,
      );
    });

final Provider<Future<void> Function()> authTopicRefreshProvider =
    Provider<Future<void> Function()>(
      (Ref ref) =>
          () =>
              ref.read(notificationServiceProvider).refreshTopicSubscription(),
    );

final Provider<Future<void> Function()> authNotificationCleanupProvider =
    Provider<Future<void> Function()>(
      (Ref ref) =>
          () => ref.read(notificationServiceProvider).clearTopicSubscriptions(),
    );

final Provider<Future<void> Function()> authTrackingCleanupProvider =
    Provider<Future<void> Function()>(
      (Ref ref) => () => BackgroundTrackingService.stop(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Auth controller — orchestrates login / logout actions.
// ─────────────────────────────────────────────────────────────────────────────

class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  Future<AuthSession> signInAsGuard({
    required String loginIdOrPhone,
    required String pin,
    bool saveForBiometric = false,
  }) async {
    final notifier = _ref.read(authSessionProvider.notifier);
    notifier.beginControllerSignIn();
    try {
      // 1. Authenticate with Firebase via the custom token from the backend.
      final session = await _ref
          .read(authRepositoryProvider)
          .signInGuard(loginIdOrPhone: loginIdOrPhone, pin: pin);
      await _requireRole(session, AppRole.guard);

      // 2. Confirm the optional app lock and durably persist its uid-bound
      // metadata before exposing the session. No PIN is retained.
      await _prepareAccountForSession(
        session: session,
        loginId: loginIdOrPhone.trim(),
        requestedAppLock: saveForBiometric,
      );

      // 3. Inject the resolved session directly — no provider invalidation.
      if (!notifier.setSession(session)) {
        await _ref.read(authRepositoryProvider).signOut();
        throw StateError(
          'The signed-in account changed before setup completed.',
        );
      }
      unawaited(_ref.read(authTopicRefreshProvider)());
      return session;
    } catch (_) {
      await notifier.cancelControllerSignIn();
      rethrow;
    }
  }

  Future<void> setupGuardPin({
    required String employeeId,
    required String phoneNumber,
    required String dateOfBirth,
    required String pin,
  }) {
    return _ref.read(guardPinSetupSenderProvider)(
      employeeId: employeeId,
      phoneNumber: phoneNumber,
      dateOfBirth: dateOfBirth,
      pin: pin,
    );
  }

  Future<AuthSession> signInAsFieldOfficer({
    required String email,
    required String password,
    bool saveForBiometric = false,
  }) async {
    final notifier = _ref.read(authSessionProvider.notifier);
    notifier.beginControllerSignIn();
    try {
      // 1. Authenticate with Firebase directly.
      final session = await _ref
          .read(authRepositoryProvider)
          .signInFieldOfficer(email: email, password: password);
      await _requireRole(session, AppRole.fieldOfficer);

      // 2. Persist account metadata before exposing the session; see guard
      // sign-in. This is fail-closed when the account needs an app lock.
      await _prepareAccountForSession(
        session: session,
        loginId: email.trim(),
        requestedAppLock: saveForBiometric,
      );

      // 3. Inject the resolved session directly.
      if (!notifier.setSession(session)) {
        await _ref.read(authRepositoryProvider).signOut();
        throw StateError(
          'The signed-in account changed before setup completed.',
        );
      }
      unawaited(_ref.read(authTopicRefreshProvider)());
      return session;
    } catch (_) {
      await notifier.cancelControllerSignIn();
      rethrow;
    }
  }

  Future<void> sendFieldOfficerPasswordResetEmail({required String email}) {
    return _ref.read(fieldOfficerPasswordResetSenderProvider)(email);
  }

  /// Forgetting a recent account removes its metadata and any matching legacy
  /// credential that predates the app-lock migration.
  Future<void> removeSavedAccount({
    required String role,
    required String loginId,
  }) async {
    await _ref.read(savedAccountsServiceProvider).removeAccount(role, loginId);
    await _ref
        .read(legacyBiometricCredentialCleanupProvider)
        .purgeLegacyCredentialsForAccount(role: role, loginId: loginId);
  }

  Future<void> _prepareAccountForSession({
    required AuthSession session,
    required String loginId,
    required bool requestedAppLock,
  }) async {
    try {
      final appLockEnabled = await _resolveAppLockPreference(
        session: session,
        requested: requestedAppLock,
      );
      await _ref
          .read(savedAccountsServiceProvider)
          .saveAccount(
            SavedAccount(
              role: session.role.name,
              loginId: loginId,
              displayName: session.displayName,
              lastLoginAt: DateTime.now(),
              uid: session.uid,
              biometricEnabled: appLockEnabled,
            ),
          );
    } catch (_) {
      // A selected app lock is only meaningful if its uid-bound preference is
      // durable. Do not leave a newly authenticated Firebase session exposed
      // when that required metadata cannot be saved.
      _ref.read(authSessionProvider.notifier).clearSession();
      try {
        await _ref.read(authRepositoryProvider).signOut();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _requireRole(AuthSession session, AppRole expectedRole) async {
    if (session.role == expectedRole) return;
    await _ref.read(authRepositoryProvider).signOut();
    throw StateError(
      '${expectedRole.label} login is not allowed for this account.',
    );
  }

  Future<bool> _resolveAppLockPreference({
    required AuthSession session,
    required bool requested,
  }) async {
    final existing = await _ref
        .read(savedAccountsServiceProvider)
        .findForSession(session);
    // A fresh PIN/password login is recovery from the local app lock. Clear
    // the exact UID-bound flag durably before the session is exposed so
    // AuthGate cannot immediately lock the user behind stale local state.
    if (!requested) {
      if (existing?.biometricEnabled == true) {
        await _ref
            .read(savedAccountsServiceProvider)
            .setBiometricEnabled(
              role: session.role.name,
              uid: session.uid,
              enabled: false,
            );
      }
      return false;
    }

    try {
      final biometrics = _ref.read(biometricServiceProvider);
      final support = await biometrics.checkFingerprintSupport();
      if (support.availability != FingerprintAvailability.supported) {
        return existing?.biometricEnabled ?? false;
      }
      final confirmed =
          await biometrics.authenticateFingerprint(
            localizedReason: 'Verify to enable biometric app lock',
          ) ==
          BiometricAuthOutcome.success;
      return confirmed || (existing?.biometricEnabled ?? false);
    } catch (_) {
      return existing?.biometricEnabled ?? false;
    }
  }

  Future<void> signOut() async {
    // Expose no session before touching any optional work, then sign Firebase
    // out immediately. The notifier suppresses token events so a pending
    // resolver cannot republish this account during logout.
    _ref.read(authSessionProvider.notifier).beginSignOut();
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } finally {
      unawaited(_runBestEffortCleanup(authNotificationCleanupProvider));
      unawaited(_runBestEffortCleanup(authTrackingCleanupProvider));
    }
  }

  Future<void> _runBestEffortCleanup(
    ProviderListenable<Future<void> Function()> provider,
  ) async {
    try {
      await _ref.read(provider)().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Topic and tracking cleanup must neither delay logout nor revive auth.
    }
  }
}

final Provider<AuthController> authControllerProvider =
    Provider<AuthController>((Ref ref) => AuthController(ref));
