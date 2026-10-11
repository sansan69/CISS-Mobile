import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this device can be used for the biometric app lock.
///
/// `local_auth` exposes enrolled modality names but does not let this app
/// enforce a uniform biometric strength or fingerprint-only policy across
/// platforms. The app therefore accepts any enrolled biometric that the
/// installed plugin can authenticate.
enum FingerprintAvailability { supported, noSensor, notEnrolled, unknown }

/// Typed outcome of a biometric prompt so UI can react to the OS error codes
/// (per local_auth docs: NotAvailable=13, NotEnrolled=11, LockedOut=7,
/// PermanentlyLockedOut=9).
enum BiometricAuthOutcome {
  success,
  failed,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  error,
}

/// `local_auth` cannot enforce a cross-platform strength or modality policy,
/// so the app-lock policy deliberately accepts any enrolled biometric exposed
/// by the installed plugin.
bool supportsBiometricAppLock(List<BiometricType> enrolledBiometrics) =>
    enrolledBiometrics.isNotEmpty;

class FingerprintSupport {
  const FingerprintSupport({
    required this.availability,
    required this.enrolledBiometrics,
  });

  final FingerprintAvailability availability;
  final List<BiometricType> enrolledBiometrics;

  static const unknown = FingerprintSupport(
    availability: FingerprintAvailability.unknown,
    enrolledBiometrics: <BiometricType>[],
  );
}

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

  Future<bool> canAuthenticateWithBiometrics() async {
    return await _auth.canCheckBiometrics;
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _auth.getAvailableBiometrics();
  }

  /// Capability probe for the biometric app lock:
  /// 1. `isDeviceSupported` — does the platform expose any biometric API.
  /// 2. `getAvailableBiometrics` — which types are ENROLLED right now.
  /// 3. `canCheckBiometrics` — distinguishes "no sensor" from "sensor
  ///    present but nothing enrolled" (canCheckBiometrics is hardware-only).
  ///
  /// Any enrolled biometric classification qualifies because `local_auth`
  /// cannot enforce a stronger policy consistently on every supported device.
  Future<FingerprintSupport> checkFingerprintSupport() async {
    var deviceSupported = false;
    try {
      deviceSupported = await _auth.isDeviceSupported();
    } catch (_) {}
    if (!deviceSupported) {
      return FingerprintSupport(
        availability: FingerprintAvailability.unknown,
        enrolledBiometrics: const <BiometricType>[],
      );
    }

    List<BiometricType> available = const <BiometricType>[];
    try {
      available = await _auth.getAvailableBiometrics();
    } catch (_) {}

    if (supportsBiometricAppLock(available)) {
      return FingerprintSupport(
        availability: FingerprintAvailability.supported,
        enrolledBiometrics: available,
      );
    }

    var canCheck = false;
    try {
      canCheck = await _auth.canCheckBiometrics;
    } catch (_) {}
    if (!canCheck) {
      return FingerprintSupport(
        availability: FingerprintAvailability.noSensor,
        enrolledBiometrics: available,
      );
    }
    return FingerprintSupport(
      availability: FingerprintAvailability.notEnrolled,
      enrolledBiometrics: available,
    );
  }

  /// Authenticate with biometrics, falling back to device credentials
  /// (PIN / pattern / password) if biometrics are not enrolled.
  Future<bool> authenticate({
    required String localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = false,
    bool sensitiveTransaction = true,
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric authentication',
            cancelButton: 'Cancel',
            biometricHint: 'Verify your identity',
            biometricNotRecognized: 'Not recognized, try again',
            biometricRequiredTitle: 'Biometric login required',
            biometricSuccess: 'Authentication successful',
            deviceCredentialsRequiredTitle: 'Device credentials required',
            deviceCredentialsSetupDescription:
                'Set up a PIN, pattern, or password to secure your account',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription:
                'Please set up biometric authentication in Settings',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription:
                'Please set up biometric authentication in Settings',
            lockOut:
                'Biometric authentication is disabled. '
                'Please lock and unlock your screen to enable it.',
          ),
        ],
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          sensitiveTransaction: sensitiveTransaction,
          biometricOnly: false, // Allow device credential fallback
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth PlatformException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// Authenticate with biometrics only (no device credential fallback).
  Future<bool> authenticateBiometricOnly({
    required String localizedReason,
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: false,
          sensitiveTransaction: true,
          biometricOnly: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric-only auth PlatformException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Biometric-only auth error: $e');
      return false;
    }
  }

  /// Biometric app-lock authentication with a typed outcome so the UI can
  /// guide the user through OS error states (per local_auth error codes).
  Future<BiometricAuthOutcome> authenticateFingerprint({
    required String localizedReason,
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          sensitiveTransaction: true,
          biometricOnly: true,
        ),
      );
      return didAuthenticate
          ? BiometricAuthOutcome.success
          : BiometricAuthOutcome.failed;
    } on PlatformException catch (e) {
      debugPrint('Biometric app-lock PlatformException: ${e.message}');
      switch (e.code) {
        case 'NotAvailable':
          return BiometricAuthOutcome.notAvailable;
        case 'NotEnrolled':
          return BiometricAuthOutcome.notEnrolled;
        case 'LockedOut':
          return BiometricAuthOutcome.lockedOut;
        case 'PermanentlyLockedOut':
          return BiometricAuthOutcome.permanentlyLockedOut;
        default:
          return BiometricAuthOutcome.error;
      }
    } catch (e) {
      debugPrint('Biometric app-lock error: $e');
      return BiometricAuthOutcome.error;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);
