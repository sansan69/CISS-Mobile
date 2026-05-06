import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    return await _auth.isDeviceSupported();
  }

  Future<bool> canAuthenticate() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate =
        canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  Future<bool> authenticate({required String localizedReason}) async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
      );
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      // Catch-all for any unexpected errors (e.g. plugin not registered)
      return false;
    }
  }
}

final biometricServiceProvider = Provider((ref) => BiometricService());
