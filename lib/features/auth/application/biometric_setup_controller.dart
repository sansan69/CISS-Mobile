import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/app_lock_preferences.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/network/auth_repository.dart';
import '../../../core/network/providers.dart';
import 'auth_controller.dart';

/// Result of an enable/disable attempt, carrying the biometric outcome so
/// the UI can guide the user through OS error states (not enrolled, locked).
class BiometricSetupResult {
  const BiometricSetupResult({
    required this.success,
    this.outcome,
    this.message,
  });

  final bool success;
  final BiometricAuthOutcome? outcome;
  final String? message;

  static const BiometricSetupResult ok = BiometricSetupResult(success: true);
}

class BiometricSetupState {
  const BiometricSetupState({
    this.support = FingerprintSupport.unknown,
    this.accountEnabled = false,
    this.busy = false,
  });

  final FingerprintSupport support;
  final bool accountEnabled;
  final bool busy;

  BiometricSetupState copyWith({
    FingerprintSupport? support,
    bool? accountEnabled,
    bool? busy,
  }) {
    return BiometricSetupState(
      support: support ?? this.support,
      accountEnabled: accountEnabled ?? this.accountEnabled,
      busy: busy ?? this.busy,
    );
  }
}

/// Enrollment + lifecycle for a biometric app lock on one account.
///
/// Enabling verifies the PIN/password against the server and requires a
/// biometric gesture. It persists only an account-scoped app-lock flag;
/// PINs and passwords are never retained on-device.
class BiometricSetupController extends StateNotifier<BiometricSetupState> {
  BiometricSetupController(this._ref) : super(const BiometricSetupState());

  final Ref _ref;

  BiometricService get _biometrics => _ref.read(biometricServiceProvider);
  SavedAccountsService get _accounts => _ref.read(savedAccountsServiceProvider);
  AuthRepository get _repository => _ref.read(authRepositoryProvider);

  String _loginIdFor(AuthSession session) {
    return session.role == AppRole.fieldOfficer
        ? session.email ?? session.primaryId
        : session.primaryId;
  }

  Future<void> _setAccountLock(AuthSession session, bool enabled) async {
    final existing = await _accounts.findForSession(session);
    if (existing == null) {
      await _accounts.saveAccount(
        SavedAccount(
          role: session.role.name,
          loginId: _loginIdFor(session),
          displayName: session.displayName,
          lastLoginAt: DateTime.now(),
          uid: session.uid,
          biometricEnabled: enabled,
        ),
      );
      return;
    }
    await _accounts.setBiometricEnabled(
      role: session.role.name,
      uid: session.uid,
      enabled: enabled,
    );
  }

  /// Refresh capability + per-account state. Call when the settings surface
  /// opens so the status reflects the current device and account.
  Future<void> load({required AuthSession session}) async {
    final support = await _biometrics.checkFingerprintSupport();
    final account = await _accounts.findForSession(session);
    state = BiometricSetupState(
      support: support,
      accountEnabled: account?.biometricEnabled ?? false,
    );
  }

  /// Verify the account's PIN/password server-side, then require a
  /// biometric gesture before enabling this session's app lock.
  Future<BiometricSetupResult> enable({
    required AuthSession session,
    required String password,
  }) async {
    if (state.support.availability != FingerprintAvailability.supported) {
      return const BiometricSetupResult(
        success: false,
        message: 'Biometric app lock is not available on this device.',
      );
    }
    state = state.copyWith(busy: true);
    final verifyWith = _loginIdFor(session);
    final sessionNotifier = _ref.read(authSessionProvider.notifier);
    if (!sessionNotifier.beginIdentityVerification(session)) {
      state = state.copyWith(busy: false);
      return const BiometricSetupResult(
        success: false,
        message: 'Could not verify this account. Please sign in again.',
      );
    }

    try {
      // 1. Verify the existing Firebase identity without replacing it.
      if (session.role == AppRole.guard) {
        await _repository.verifyCurrentGuardPin(
          expectedSession: session,
          loginIdOrPhone: verifyWith,
          pin: password,
        );
      } else {
        await _repository.verifyCurrentFieldOfficerPassword(
          expectedSession: session,
          email: session.email ?? verifyWith,
          password: password,
        );
      }
      if (!await sessionNotifier.completeIdentityVerification(session)) {
        state = state.copyWith(busy: false);
        return const BiometricSetupResult(
          success: false,
          message: 'Could not verify this account. Please sign in again.',
        );
      }
    } catch (_) {
      await sessionNotifier.completeIdentityVerification(session);
      state = state.copyWith(busy: false);
      return const BiometricSetupResult(
        success: false,
        message:
            'The PIN or password is incorrect. Verify your details and try again.',
      );
    }

    // 2. Biometric gesture as the identity gate.
    final outcome = await _biometrics.authenticateFingerprint(
      localizedReason: 'Verify to enable biometric app lock',
    );
    if (outcome != BiometricAuthOutcome.success) {
      state = state.copyWith(busy: false);
      return BiometricSetupResult(
        success: false,
        outcome: outcome,
        message: _outcomeMessage(outcome, 'enable'),
      );
    }

    // 3. Persist only the uid-bound app-lock preference.
    try {
      await _setAccountLock(session, true);
    } catch (_) {
      state = state.copyWith(busy: false);
      return const BiometricSetupResult(
        success: false,
        message: 'Could not save the biometric app lock. Please try again.',
      );
    }

    _ref.read(appLockPreferencesProvider.notifier).setFor(session, true);
    state = state.copyWith(busy: false, accountEnabled: true);
    return BiometricSetupResult.ok;
  }

  /// Confirm with a biometric gesture, then disable the account app lock.
  Future<BiometricSetupResult> disable({required AuthSession session}) async {
    final outcome = await _biometrics.authenticateFingerprint(
      localizedReason: 'Verify to disable biometric app lock',
    );
    if (outcome != BiometricAuthOutcome.success) {
      return BiometricSetupResult(
        success: false,
        outcome: outcome,
        message: _outcomeMessage(outcome, 'disable'),
      );
    }

    try {
      await _setAccountLock(session, false);
    } catch (_) {
      return const BiometricSetupResult(
        success: false,
        message: 'Could not update the biometric app lock. Please try again.',
      );
    }

    _ref.read(appLockPreferencesProvider.notifier).setFor(session, false);
    state = state.copyWith(accountEnabled: false);
    return BiometricSetupResult.ok;
  }

  String _outcomeMessage(BiometricAuthOutcome outcome, String action) {
    switch (outcome) {
      case BiometricAuthOutcome.notEnrolled:
        return 'No biometric is set up on this device. '
            'Add one in Settings, then try again.';
      case BiometricAuthOutcome.lockedOut:
        return 'Biometric authentication is temporarily locked. '
            'Unlock your phone with your PIN or pattern, then retry.';
      case BiometricAuthOutcome.permanentlyLockedOut:
        return 'Biometric authentication was permanently locked. '
            'Re-enroll biometrics in device Settings.';
      case BiometricAuthOutcome.notAvailable:
        return 'Biometric authentication is not available on this device.';
      case BiometricAuthOutcome.failed:
      case BiometricAuthOutcome.error:
        return 'Could not $action with biometrics. Please try again.';
      case BiometricAuthOutcome.success:
        return '';
    }
  }
}

final biometricSetupProvider =
    StateNotifierProvider<BiometricSetupController, BiometricSetupState>(
      (ref) => BiometricSetupController(ref),
    );
