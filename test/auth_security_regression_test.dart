import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/app_lock_lifecycle.dart';
import 'package:ciss_mobile/core/auth/guard_login_identifier.dart';
import 'package:ciss_mobile/core/network/authenticated_identity_mismatch_error.dart';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:flutter/widgets.dart';

void main() {
  group('guard login identifier classification', () {
    test('keeps alphanumeric employee IDs as employee IDs', () {
      expect(
        GuardLoginIdentifier.isPhoneNumber('CISS/TCS/2025-26/871'),
        isFalse,
      );
      expect(
        GuardLoginIdentifier.setupQueryParameters('CISS/TCS/2025-26/871'),
        <String, String>{'employeeId': 'CISS/TCS/2025-26/871'},
      );
    });

    test('accepts only complete supported phone input with 8–15 digits', () {
      expect(GuardLoginIdentifier.isPhoneNumber('+91 (98765) 43210'), isTrue);
      expect(GuardLoginIdentifier.isPhoneNumber('98765abc43210'), isFalse);
      expect(GuardLoginIdentifier.isPhoneNumber('1234567'), isFalse);
    });
  });

  test('no session-resolution failure is eligible for claims fallback', () {
    final mismatch = const AuthenticatedIdentityMismatchError(
      firebaseUid: 'active-user',
      backendUid: 'backend-user',
    );

    expect(MobileRepository.allowsClaimsFallback(mismatch), isFalse);
    expect(
      MobileRepository.allowsClaimsFallback(StateError('offline')),
      isFalse,
    );
  });

  group('account app-lock lifecycle', () {
    test('rearms after the app backgrounds and resumes', () {
      final lifecycle = AppLockLifecycle();

      lifecycle.didChangeAppLifecycleState(
        AppLifecycleState.paused,
        appLockEnabled: true,
        biometricPromptActive: false,
      );

      expect(
        lifecycle.consumeLockOnResume(
          state: AppLifecycleState.resumed,
          appLockEnabled: true,
          biometricPromptActive: false,
        ),
        isTrue,
      );
    });

    test(
      'does not rearm while a biometric prompt owns the lifecycle change',
      () {
        final lifecycle = AppLockLifecycle();

        lifecycle.didChangeAppLifecycleState(
          AppLifecycleState.inactive,
          appLockEnabled: true,
          biometricPromptActive: true,
        );

        expect(
          lifecycle.consumeLockOnResume(
            state: AppLifecycleState.resumed,
            appLockEnabled: true,
            biometricPromptActive: false,
          ),
          isFalse,
        );
      },
    );
  });
}
