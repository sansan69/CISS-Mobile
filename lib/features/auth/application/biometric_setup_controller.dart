import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/auth/biometric_credential_store.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/saved_accounts_service.dart';
import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
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
/// Credentials are keyed by the SAME login identifier the user typed at
/// sign-in (saved-account loginId — phone or employeeId for guards, email
/// for field officers), NOT by `session.primaryId` (employeeId / Firebase
/// uid) — otherwise the quick-login chip can never find the stored PIN.
/// The canonical key is written as a second copy so employeeId-keyed
/// accounts keep working too.
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

  /// Resolve the saved-account loginId for this session. The user may have
  /// signed in with a phone number (guards) or a different identifier than
  /// the canonical ids the backend returns, so match against the session's
  /// canonical ids plus (for guards) the profile phone.
  Future<String?> _resolveLoginId(AuthSession session) async {
    final accounts = await _accounts.loadForRole(session.role.name);

    SavedAccount? match(String candidate) {
      for (final account in accounts) {
        if (account.loginId == candidate) return account;
      }
      return null;
    }

    if (match(session.primaryId) != null) return session.primaryId;

    if (session.role == AppRole.guard) {
      try {
        final phone = (await _repository.fetchGuardProfile()).phoneNumber;
        if (phone.isNotEmpty && match(phone) != null) return phone;
      } catch (_) {}
    } else if (session.email != null && match(session.email!) != null) {
      return session.email;
    }

    // Last resort: a single saved account for this role is unambiguous.
    if (accounts.length == 1) return accounts.first.loginId;
    return null;
  }

  Future<bool> _accountBiometricEnabled(String role, String loginId) async {
    final accounts = await _accounts.loadForRole(role);
    for (final account in accounts) {
      if (account.loginId == loginId) return account.biometricEnabled;
    }
    return false;
  }

  /// Refresh capability + per-account state. Call when the settings surface
  /// opens so the status reflects the current device and account.
  Future<void> load({required AuthSession session}) async {
    final support = await _biometrics.checkFingerprintSupport();
    final loginId = await _resolveLoginId(session);
    final hasStoredCredential = await _store.hasCredentials(
      role: session.role.name,
      loginId: loginId ?? session.primaryId,
    );
    state = BiometricSetupState(
      support: support,
      hasStoredCredential: hasStoredCredential,
      accountEnabled:
          loginId != null &&
          await _accountBiometricEnabled(session.role.name, loginId),
    );
  }

  /// Verify the account's PIN/password against the backend (no session
  /// change — repository call only), then require a fingerprint gesture and
  /// bind the verified credential.
  Future<BiometricSetupResult> enable({
    required AuthSession session,
    required String password,
  }) async {
    if (state.support.availability != FingerprintAvailability.supported) {
      return const BiometricSetupResult(
        success: false,
        message: 'Fingerprint unlock is not available on this device.',
      );
    }
    state = state.copyWith(busy: true);
    final role = session.role.name;
    final loginId = await _resolveLoginId(session);
    final verifyWith = loginId ?? session.primaryId;

    try {
      // 1. Server-verify the credential we are about to store.
      if (role == 'guard') {
        await _repository.signInGuard(
          loginIdOrPhone: verifyWith,
          pin: password,
        );
      } else {
        await _repository.signInFieldOfficer(
          email: session.email ?? verifyWith,
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

    // 3. Bind: store under the typed login id (primary) plus the canonical
    //    id (backup), and flip the flags on the matched account.
    await _store.saveCredentials(
      role: role,
      loginId: loginId ?? session.primaryId,
      password: password,
    );
    if (loginId != null && loginId != session.primaryId) {
      await _store.saveCredentials(
        role: role,
        loginId: session.primaryId,
        password: password,
      );
    }
    if (loginId != null) {
      await _accounts.setBiometricEnabled(
        role: role,
        loginId: loginId,
        enabled: true,
      );
    }
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
  Future<BiometricSetupResult> disable({required AuthSession session}) async {
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

    final role = session.role.name;
    final loginId = await _resolveLoginId(session);
    if (loginId != null) {
      await _store.deleteCredentials(role: role, loginId: loginId);
      await _accounts.setBiometricEnabled(
        role: role,
        loginId: loginId,
        enabled: false,
      );
    }
    await _store.deleteCredentials(role: role, loginId: session.primaryId);
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
