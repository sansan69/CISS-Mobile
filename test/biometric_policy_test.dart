import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:ciss_mobile/core/auth/biometric_service.dart';

void main() {
  test(
    'biometric app-lock policy accepts the modalities local_auth exposes',
    () {
      expect(
        supportsBiometricAppLock(<BiometricType>[BiometricType.weak]),
        isTrue,
      );
      expect(
        supportsBiometricAppLock(<BiometricType>[BiometricType.fingerprint]),
        isTrue,
      );
      expect(supportsBiometricAppLock(const <BiometricType>[]), isFalse);
    },
  );
}
