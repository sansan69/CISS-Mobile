import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccount {
  const SavedAccount({
    required this.role,
    required this.loginId,
    required this.displayName,
    required this.lastLoginAt,
    this.biometricEnabled = false,
  });

  /// 'guard' | 'fieldOfficer'
  final String role;

  /// email for field officers, employeeId/phone number for guards
  final String loginId;
  final String displayName;
  final DateTime lastLoginAt;

  /// Whether this saved account has biometric login enabled.
  final bool biometricEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'loginId': loginId,
    'displayName': displayName,
    'lastLoginAt': lastLoginAt.toIso8601String(),
    'biometricEnabled': biometricEnabled,
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      role: (json['role'] as String?) ?? '',
      loginId: (json['loginId'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      lastLoginAt: json['lastLoginAt'] is String
          ? DateTime.tryParse(json['lastLoginAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    );
  }

  SavedAccount withUpdated({
    String? displayName,
    DateTime? lastLoginAt,
    bool? biometricEnabled,
  }) {
    return SavedAccount(
      role: role,
      loginId: loginId,
      displayName: displayName ?? this.displayName,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  String get maskedLoginId {
    if (loginId.contains('@')) {
      final parts = loginId.split('@');
      final local = parts[0];
      final domain = parts.length > 1 ? parts[1] : '';
      final visible = local.length > 2 ? local.substring(0, 2) : local;
      return '$visible***@$domain';
    }
    if (loginId.length > 4) {
      return '${loginId.substring(0, 3)}***';
    }
    return loginId;
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final chars = parts.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').where((c) => c.isNotEmpty).take(2).join();
    return chars.isNotEmpty ? chars : loginId.substring(0, 1).toUpperCase();
  }
}

class SavedAccountsService {
  SavedAccountsService() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _storageKey = 'ciss_saved_accounts_v1';
  static const int _maxAccounts = 5;

  final FlutterSecureStorage _storage;

  Future<List<SavedAccount>> loadAll() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return <SavedAccount>[];
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <SavedAccount>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedAccount.fromJson)
          .toList();
    } catch (_) {
      return <SavedAccount>[];
    }
  }

  Future<List<SavedAccount>> loadForRole(String role) async {
    final all = await loadAll();
    return all
        .where((a) => a.role == role)
        .toList()
      ..sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
  }

  Future<void> saveAccount(SavedAccount account) async {
    try {
      final all = await loadAll();
      final deduped = all
          .where((a) => !(a.role == account.role && a.loginId == account.loginId))
          .toList();
      deduped.insert(0, account);
      final trimmed = deduped.take(_maxAccounts).toList();
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(trimmed.map((a) => a.toJson()).toList()),
      );
    } catch (_) {
      // Non-critical — don't block login if storage write fails.
    }
  }

  Future<void> removeAccount(String role, String loginId) async {
    try {
      final all = await loadAll();
      final updated = all
          .where((a) => !(a.role == role && a.loginId == loginId))
          .toList();
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(updated.map((a) => a.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Flip biometric-unlock for one saved account without touching its
  /// display name or login timestamp.
  Future<void> setBiometricEnabled({
    required String role,
    required String loginId,
    required bool enabled,
  }) async {
    try {
      final all = await loadAll();
      final updated = all.map((account) {
        if (account.role == role && account.loginId == loginId) {
          return account.withUpdated(biometricEnabled: enabled);
        }
        return account;
      }).toList();
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(updated.map((a) => a.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// True when at least one saved account has biometric unlock enabled.
  Future<bool> anyBiometricEnabled() async {
    final all = await loadAll();
    return all.any((account) => account.biometricEnabled);
  }

  Future<void> saveAll(List<SavedAccount> accounts) async {
    try {
      final trimmed = accounts.take(_maxAccounts).toList();
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(trimmed.map((a) => a.toJson()).toList()),
      );
    } catch (_) {
      // Non-critical — don't block if storage write fails.
    }
  }
}

final Provider<SavedAccountsService> savedAccountsServiceProvider =
    Provider<SavedAccountsService>((Ref ref) => SavedAccountsService());
