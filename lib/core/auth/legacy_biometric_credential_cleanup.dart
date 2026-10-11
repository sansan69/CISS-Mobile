import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Prefix used by the retired biometric quick-sign-in implementation.
///
/// Legacy values under this prefix contained reusable PINs or passwords. They
/// are deliberately removed one key at a time; this shared secure-storage
/// namespace may also contain unrelated application data.
const String legacyBiometricCredentialPrefix = 'ciss_biometric_cred_';

Iterable<String> legacyBiometricCredentialKeys(Iterable<String> keys) {
  return keys.where((key) => key.startsWith(legacyBiometricCredentialPrefix));
}

/// Injectable narrow storage surface so migration behavior can be verified
/// without exposing any credential read/write API to app code.
abstract interface class LegacyBiometricStorage {
  Future<Map<String, String>> readAll();
  Future<void> delete({required String key});
}

class _SecureLegacyBiometricStorage implements LegacyBiometricStorage {
  const _SecureLegacyBiometricStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}

class LegacyBiometricCredentialCleanup {
  LegacyBiometricCredentialCleanup({LegacyBiometricStorage? storage})
    : _storage = storage ?? const _SecureLegacyBiometricStorage();

  final LegacyBiometricStorage _storage;

  /// Removes only credentials written by the retired quick-sign-in feature.
  /// Failures are non-fatal: the migration is retried safely on the next app
  /// launch and never uses deleteAll on the shared secure-storage instance.
  Future<void> purgeLegacyCredentials() async {
    try {
      final values = await _storage.readAll();
      for (final key in legacyBiometricCredentialKeys(values.keys)) {
        await _storage.delete(key: key);
      }
    } catch (_) {
      // Secure storage may be temporarily unavailable during device startup.
    }
  }

  /// Remove a retired credential immediately when its recent-account entry is
  /// forgotten. Startup migration still removes every legacy key safely.
  Future<void> purgeLegacyCredentialsForAccount({
    required String role,
    required String loginId,
  }) async {
    final sanitized = loginId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await _storage.delete(
      key: '$legacyBiometricCredentialPrefix${role}_$sanitized',
    );
  }
}

final Provider<LegacyBiometricCredentialCleanup>
legacyBiometricCredentialCleanupProvider =
    Provider<LegacyBiometricCredentialCleanup>(
      (Ref ref) => LegacyBiometricCredentialCleanup(),
    );
