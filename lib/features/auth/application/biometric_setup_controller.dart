import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/auth/biometric_credential_store.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/network/mobile_repository.dart';
import '../../../core/network/providers.dart';

/// Result of an enable/disable attempt, carrying the fingerprint outcome so
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
    this.hasStoredCredential = false,
    this.busy = false,
  });

  final FingerprintSupport support;
  final bool accountEnabled;
  final bool hasStoredCredential;
  final bool busy;

  BiometricSetupState copyWith({
    FingerprintSupport? support,
    bool? accountEnabled,
    bool? hasStoredCredential,
    bool? busy,
  }) {
    return BiometricSetupState(
      support: support ?? this.support,
      accountEnabled: accountEnabled ?? this.accountEnabled,
      hasStoredCredential: hasStoredCredential ?? this.hasStoredCredential,
      busy: busy ?? this.busy,
    );
  }
}

/// Enrollment + lifecycle for fingerprint unlock on one saved account.
///
/// Industry-standard flow:
/// - Enable:  verify the account's PIN/password against the backend (the
///   credential we will store must be a real one), then prompt a fingerprint
///   gesture as the identity gate, then persist the credential in the secure
///   store and flip the per-account + global flags.
/// - Disable: confirm with a fingerprint gesture, then remove the credential
///   and clear the flags (global flag drops only when no other account uses
///   biometrics).
class BiometricSetupController extends StateNotifier<BiometricSetupState> {
  BiometricSetupController(this._ref) : super(const BiometricSetupState());

  final Ref _ref;

  BiometricService get _biometrics => _ref.read(biometricServiceProvider);
  BiometricCredentialStore get _store =>
      _ref.read(biometricCredentialStoreProvider);
  SavedAccountsService get _accounts =>
      _ref.read(savedAccountsServiceProvider);
  MobileRepository get _repository => _ref.read(mobileRepositoryProvider);

  /// Refresh capability + per-account state. Call when the settings surface
  /// opens so the status reflects the current device and account.
  Future<void> load({
    required String role,
    required String loginId,
  }) async {
    final support = await _biometrics.checkFingerprintSupport();
    final hasStoredCredential = await _store.hasCredentials(
      role: role,
      loginId: loginId,
    );
    final accounts = await _accounts.loadForRole(role);
    SavedAccount? account;
    for (final candidate in accounts) {
      if (candidate.loginId == loginId) {
        account = candidate;
        break;
      }
    }
    state = BiometricSetupState(
      support: support,
      hasStoredCredential: hasStoredCredential,
      accountEnabled: account?.biometricEnabled ?? false,
    );
  }

  /// Verify the account's PIN/password against the backend (no session
  /// change — repository call only), then require a fingerprint gesture and
  /// bind the verified credential.
  Future<BiometricSetupResult> enable({
    required String role,
    required String loginId,
    required String password,
  }) async {
    if (state.support.availability != FingerprintAvailability.supported) {
      return const BiometricSetupResult(
        success: false,
        message: 'Fingerprint unlock is not available on this device.',
      );
    }
    state = state.copyWith(busy: true);

    try {
      // 1. Server-verify the credential we are about to store.
      if (role == 'guard') {
        await _repository.signInGuard(
          loginIdOrPhone: loginId,
          pin: password,
        );
      } else {
        await _repository.signInFieldOfficer(
          email: loginId,
          password: password,
        );
      }
    } catch (_) {
      state = state.copyWith(busy: false);
      return const BiometricSetupResult(
        success: false,
        message:
            'The PIN or password is incorrect. Verify your details and try again.',
      );
    }

    // 2. Fingerprint gesture as the identity gate.
    final outcome = await _biometrics.authenticateFingerprint(
      localizedReason: 'Place your finger to enable fingerprint unlock',
    );
    if (outcome != BiometricAuthOutcome.success) {
      state = state.copyWith(busy: false);
      return BiometricSetupResult(
        success: false,
        outcome: outcome,
        message: _outcomeMessage(outcome, 'enable'),
      );
    }

    // 3. Bind: store credential + flip flags.
    await _store.saveCredentials(role: role, loginId: loginId, password: password);
    await _accounts.setBiometricEnabled(
      role: role,
      loginId: loginId,
      enabled: true,
    );
    await _ref
        .read(appSettingsControllerProvider.notifier)
        .setBiometricsEnabled(true);

    state = state.copyWith(
      busy: false,
      accountEnabled: true,
      hasStoredCredential: true,
    );
    return BiometricSetupResult.ok;
  }

  /// Confirm with a fingerprint gesture, then remove the binding.
  Future<BiometricSetupResult> disable({
    required String role,
    required String loginId,
  }) async {
    final outcome = await _biometrics.authenticateFingerprint(
      localizedReason: 'Confirm with your fingerprint to disable unlock',
    );
    if (outcome != BiometricAuthOutcome.success) {
      return BiometricSetupResult(
        success: false,
        outcome: outcome,
        message: _outcomeMessage(outcome, 'disable'),
      );
    }

    await _store.deleteCredentials(role: role, loginId: loginId);
    await _accounts.setBiometricEnabled(
      role: role,
      loginId: loginId,
      enabled: false,
    );
    // Global flag only drops when no other saved account uses biometrics.
    if (!await _accounts.anyBiometricEnabled()) {
      await _ref
          .read(appSettingsControllerProvider.notifier)
          .setBiometricsEnabled(false);
    }

    state = state.copyWith(
      accountEnabled: false,
      hasStoredCredential: false,
    );
    return BiometricSetupResult.ok;
  }

  String _outcomeMessage(
    BiometricAuthOutcome outcome,
    String action,
  ) {
    switch (outcome) {
      case BiometricAuthOutcome.notEnrolled:
        return 'No fingerprint is set up on this device. '
            'Add one in Settings, then try again.';
      case BiometricAuthOutcome.lockedOut:
        return 'Fingerprint is temporarily locked. '
            'Unlock your phone with your PIN or pattern, then retry.';
      case BiometricAuthOutcome.permanentlyLockedOut:
        return 'Fingerprint was permanently locked. '
            'Re-enroll your fingerprint in device Settings.';
      case BiometricAuthOutcome.notAvailable:
        return 'Fingerprint authentication is not available on this device.';
      case BiometricAuthOutcome.failed:
      case BiometricAuthOutcome.error:
        return 'Could not $action with fingerprint. Please try again.';
      case BiometricAuthOutcome.success:
        return '';
    }
  }
}

final biometricSetupProvider =
    StateNotifierProvider<BiometricSetupController, BiometricSetupState>(
      (ref) => BiometricSetupController(ref),
    );
