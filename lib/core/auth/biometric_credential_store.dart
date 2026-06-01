import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores credentials encrypted at rest, keyed by loginId + role.
///
/// This is **not** biometric-bound encryption (that requires platform-specific
/// key stores). Instead, we use FlutterSecureStorage which leverages the
/// Android Keystore / iOS Keychain. The biometric prompt is a gatekeeping
/// UX layer — the user must authenticate before we decrypt and use the
/// stored password/PIN.
///
/// For true biometric-bound keys (invalidated when fingerprints change),
/// migrate to `local_auth` + platform channels or `biometric_storage` plugin.
class BiometricCredentialStore {
  BiometricCredentialStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  static const String _keyPrefix = 'ciss_biometric_cred_';
  final FlutterSecureStorage _storage;

  String _makeKey(String role, String loginId) {
    final sanitized = loginId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '$_keyPrefix${role}_$sanitized';
  }

  /// Persist credentials after a successful login.
  Future<void> saveCredentials({
    required String role,
    required String loginId,
    required String password,
  }) async {
    final key = _makeKey(role, loginId);
    final payload = jsonEncode({'password': password});
    await _storage.write(key: key, value: payload);
  }

  /// Retrieve stored credentials. Returns null if none exist.
  Future<String?> getPassword({
    required String role,
    required String loginId,
  }) async {
    try {
      final key = _makeKey(role, loginId);
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded['password'] as String?;
    } catch (e) {
      debugPrint('BiometricCredentialStore read error: $e');
      return null;
    }
  }

  /// Delete stored credentials for a given account.
  Future<void> deleteCredentials({
    required String role,
    required String loginId,
  }) async {
    final key = _makeKey(role, loginId);
    await _storage.delete(key: key);
  }

  /// Delete all stored credentials (e.g. on global sign-out).
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Check whether credentials exist for a given account.
  Future<bool> hasCredentials({
    required String role,
    required String loginId,
  }) async {
    final key = _makeKey(role, loginId);
    final raw = await _storage.read(key: key);
    return raw != null && raw.isNotEmpty;
  }
}

final biometricCredentialStoreProvider = Provider<BiometricCredentialStore>(
  (Ref ref) => BiometricCredentialStore(),
);
