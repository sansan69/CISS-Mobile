import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/biometric_credential_store.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/fcm/providers.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/models/guard_pin_status.dart';
import '../../../core/network/providers.dart';
import '../../../app/theme/theme_mode_controller.dart';

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
  StreamSubscription<User?>? _authSubscription;
  AuthSession? _cachedSession;
  bool _disposed = false;

  @override
  Future<AuthSession?> build() async {
    ref.onDispose(() {
      _disposed = true;
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    final auth = ref.watch(firebaseAuthProvider);

    // Cancel any previous listener and await to prevent duplicate subscriptions.
    await _authSubscription?.cancel();
    _authSubscription = null;

    // Fast path: if we have a cached session and the Firebase user matches,
    // return it instantly. The listener will refresh in the background.
    final user = auth.currentUser;
    if (user == null) {
      _cachedSession = null;
      return null;
    }

    final cached = _cachedSession;
    if (cached != null && cached.uid == user.uid) {
      // Schedule a background refresh without blocking the UI.
      _scheduleBackgroundRefresh();
      return cached;
    }

    // Listen to auth changes for the lifetime of this notifier.
    _authSubscription = auth.idTokenChanges().listen((User? changedUser) async {
      if (_disposed) return;
      if (changedUser == null) {
        _cachedSession = null;
        state = const AsyncData(null);
        return;
      }

      // If the user hasn't changed and we have a cached session, skip.
      final currentCached = _cachedSession;
      if (currentCached != null && currentCached.uid == changedUser.uid) {
        return;
      }

      try {
        final session = await ref
            .read(mobileRepositoryProvider)
            .resolveCurrentSession();
        if (_disposed) return;
        _cachedSession = session;
        state = AsyncData(session);
      } catch (error, stack) {
        if (_disposed) return;
        // Keep the cached session alive if backend is temporarily down.
        final fallback = _cachedSession;
        if (fallback != null) {
          state = AsyncData(fallback);
        } else {
          state = AsyncError(error, stack);
        }
      }
    });

    // Block only on first-ever resolution; warm starts use the fast path above.
    final session = await ref
        .read(mobileRepositoryProvider)
        .resolveCurrentSession();
    _cachedSession = session;
    return session;
  }

  void _scheduleBackgroundRefresh() {
    // Refresh in the background without blocking.
    ref.read(mobileRepositoryProvider).resolveCurrentSession().then((session) {
      if (_disposed || session == null) return;
      _cachedSession = session;
      // Only update state if it hasn't changed to null in the meantime.
      if (state.valueOrNull != null) {
        state = AsyncData(session);
      }
    }).catchError((_) {
      // Silent — the cached session is still valid.
    });
  }

  /// Inject a session after a fresh login — avoids a redundant backend call.
  void setSession(AuthSession session) {
    if (_disposed) return;
    _cachedSession = session;
    state = AsyncData(session);
  }

  /// Clear the session (used on sign-out before the auth listener fires).
  void clearSession() {
    if (_disposed) return;
    _cachedSession = null;
    state = const AsyncData(null);
  }
}

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
  AuthSessionNotifier.new,
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
    // 1. Authenticate with Firebase via the custom token from the backend.
    final session = await _ref
        .read(mobileRepositoryProvider)
        .signInGuard(loginIdOrPhone: loginIdOrPhone, pin: pin);

    // 2. Inject the resolved session directly — no provider invalidation.
    _ref.read(authSessionProvider.notifier).setSession(session);
    unawaited(
      _ref.read(notificationServiceProvider).refreshTopicSubscription(),
    );

    // 3. Persist the account for quick login next time.
    final trimmedLoginId = loginIdOrPhone.trim();
    unawaited(_ref.read(savedAccountsServiceProvider).saveAccount(
      SavedAccount(
        role: 'guard',
        loginId: trimmedLoginId,
        displayName: session.displayName,
        lastLoginAt: DateTime.now(),
        biometricEnabled: saveForBiometric,
      ),
    ));

    // 4. If biometric login is requested, encrypt and store the PIN.
    if (saveForBiometric) {
      unawaited(
        _ref.read(biometricCredentialStoreProvider).saveCredentials(
          role: 'guard',
          loginId: trimmedLoginId,
          password: pin,
        ),
      );
      unawaited(
        _ref.read(appSettingsControllerProvider.notifier).setBiometricsEnabled(true),
      );
    }

    return session;
  }

  Future<GuardPinStatus> checkGuardPinStatus({required String loginIdOrPhone}) {
    return _ref
        .read(mobileRepositoryProvider)
        .checkGuardPinStatus(loginIdOrPhone: loginIdOrPhone);
  }

  Future<void> setupGuardPin({
    required String employeeId,
    required String phoneNumber,
    required String dateOfBirth,
    required String pin,
  }) {
    return _ref
        .read(mobileRepositoryProvider)
        .setupGuardPin(
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
    // 1. Authenticate with Firebase directly.
    final session = await _ref
        .read(mobileRepositoryProvider)
        .signInFieldOfficer(email: email, password: password);

    // 2. Inject the resolved session directly.
    _ref.read(authSessionProvider.notifier).setSession(session);
    unawaited(
      _ref.read(notificationServiceProvider).refreshTopicSubscription(),
    );

    // 3. Persist the account.
    final trimmedEmail = email.trim();
    unawaited(_ref.read(savedAccountsServiceProvider).saveAccount(
      SavedAccount(
        role: 'fieldOfficer',
        loginId: trimmedEmail,
        displayName: session.displayName,
        lastLoginAt: DateTime.now(),
        biometricEnabled: saveForBiometric,
      ),
    ));

    // 4. If biometric login is requested, encrypt and store the password.
    if (saveForBiometric) {
      unawaited(
        _ref.read(biometricCredentialStoreProvider).saveCredentials(
          role: 'fieldOfficer',
          loginId: trimmedEmail,
          password: password,
        ),
      );
      unawaited(
        _ref.read(appSettingsControllerProvider.notifier).setBiometricsEnabled(true),
      );
    }

    return session;
  }

  /// Retrieve stored credentials for biometric auto-login.
  Future<String?> getStoredPassword({
    required String role,
    required String loginId,
  }) async {
    return _ref.read(biometricCredentialStoreProvider).getPassword(
      role: role,
      loginId: loginId,
    );
  }

  /// Enable or disable biometric login for a saved account.
  Future<void> setBiometricEnabled({
    required String role,
    required String loginId,
    required bool enabled,
  }) async {
    try {
      final service = _ref.read(savedAccountsServiceProvider);
      final accounts = await service.loadAll();
      final target = accounts.firstWhere(
        (a) => a.role == role && a.loginId == loginId,
      );
      final updated = target.withUpdated(biometricEnabled: enabled);

      final updatedList = accounts.map((a) {
        if (a.role == role && a.loginId == loginId) return updated;
        return a;
      }).toList();

      await service.saveAll(updatedList);

      if (!enabled) {
        await _ref.read(biometricCredentialStoreProvider).deleteCredentials(
          role: role,
          loginId: loginId,
        );
      }
    } catch (e) {
      debugPrint('setBiometricEnabled error: $e');
    }
  }

  Future<void> deleteBiometricCredentials({
    required String role,
    required String loginId,
  }) async {
    await _ref.read(biometricCredentialStoreProvider).deleteCredentials(
      role: role,
      loginId: loginId,
    );
  }

  Future<AuthSession> signInAsAdminOrClient({
    required String email,
    required String password,
    bool saveForBiometric = false,
  }) async {
    final session = await _ref
        .read(mobileRepositoryProvider)
        .signInAdminOrClient(email: email, password: password);

    _ref.read(authSessionProvider.notifier).setSession(session);
    unawaited(
      _ref.read(notificationServiceProvider).refreshTopicSubscription(),
    );

    final trimmedEmail = email.trim();
    final roleLabel = session.role == AppRole.admin ? 'admin' : 'client';
    unawaited(_ref.read(savedAccountsServiceProvider).saveAccount(
      SavedAccount(
        role: roleLabel,
        loginId: trimmedEmail,
        displayName: session.displayName,
        lastLoginAt: DateTime.now(),
        biometricEnabled: saveForBiometric,
      ),
    ));

    if (saveForBiometric) {
      unawaited(
        _ref.read(biometricCredentialStoreProvider).saveCredentials(
          role: roleLabel,
          loginId: trimmedEmail,
          password: password,
        ),
      );
      unawaited(
        _ref.read(appSettingsControllerProvider.notifier).setBiometricsEnabled(true),
      );
    }

    return session;
  }

  Future<void> signOut() async {
    await _ref.read(notificationServiceProvider).clearTopicSubscriptions();

    // Clear the session immediately so the UI reacts before the auth listener.
    _ref.read(authSessionProvider.notifier).clearSession();

    // Sign out from Firebase. The idTokenChanges listener will also fire
    // null, but we've already cleared the state — it's a no-op double-clear.
    await _ref.read(mobileRepositoryProvider).signOut();
  }
}

final Provider<AuthController> authControllerProvider =
    Provider<AuthController>((Ref ref) => AuthController(ref));
