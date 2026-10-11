import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

abstract interface class SavedAccountsStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

class _SecureSavedAccountsStorage implements SavedAccountsStorage {
  const _SecureSavedAccountsStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

class SavedAccount {
  const SavedAccount({
    required this.role,
    required this.loginId,
    required this.displayName,
    required this.lastLoginAt,
    this.uid = '',
    this.biometricEnabled = false,
  });

  /// 'guard' | 'fieldOfficer'
  final String role;

  /// email for field officers, employeeId/phone number for guards
  final String loginId;
  final String displayName;
  final DateTime lastLoginAt;

  /// Stable Firebase user id. Old records have no uid and are never allowed
  /// to activate an app lock until the user signs in again.
  final String uid;

  /// Whether this account requires the biometric app lock to reopen its session.
  final bool biometricEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'loginId': loginId,
    'displayName': displayName,
    'lastLoginAt': lastLoginAt.toIso8601String(),
    'uid': uid,
    'biometricEnabled': biometricEnabled,
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      role: (json['role'] as String?) ?? '',
      loginId: (json['loginId'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      lastLoginAt:
          json['lastLoginAt'] is String
              ? DateTime.tryParse(json['lastLoginAt'] as String) ??
                  DateTime.now()
              : DateTime.now(),
      uid: (json['uid'] as String?) ?? '',
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    );
  }

  SavedAccount withUpdated({
    String? displayName,
    DateTime? lastLoginAt,
    String? uid,
    bool? biometricEnabled,
  }) {
    return SavedAccount(
      role: role,
      loginId: loginId,
      displayName: displayName ?? this.displayName,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      uid: uid ?? this.uid,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  bool matchesSession(AuthSession session) {
    return uid.isNotEmpty && role == session.role.name && uid == session.uid;
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
    final chars =
        parts
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .where((c) => c.isNotEmpty)
            .take(2)
            .join();
    return chars.isNotEmpty ? chars : loginId.substring(0, 1).toUpperCase();
  }
}

class SavedAccountsService {
  SavedAccountsService({SavedAccountsStorage? storage})
    : _storage = storage ?? const _SecureSavedAccountsStorage();

  static const String _storageKey = 'ciss_saved_accounts_v1';
  static const int _maxAccounts = 5;

  final SavedAccountsStorage _storage;

  Future<List<SavedAccount>> _readAll() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return <SavedAccount>[];
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return <SavedAccount>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SavedAccount.fromJson)
        .toList();
  }

  Future<List<SavedAccount>> loadAll() => _readAll();

  Future<void> _writeAll(List<SavedAccount> accounts) {
    final trimmed = accounts.take(_maxAccounts).toList();
    return _storage.write(
      key: _storageKey,
      value: jsonEncode(trimmed.map((a) => a.toJson()).toList()),
    );
  }

  Future<List<SavedAccount>> loadForRole(String role) async {
    final all = await loadAll();
    return all.where((a) => a.role == role).toList()
      ..sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
  }

  Future<void> saveAccount(SavedAccount account) async {
    final all = await _readAll();
    final deduped =
        all
            .where(
              (a) =>
                  !(a.role == account.role && a.loginId == account.loginId) &&
                  !(account.uid.isNotEmpty &&
                      a.role == account.role &&
                      a.uid == account.uid),
            )
            .toList();
    deduped.insert(0, account);
    await _writeAll(deduped);
  }

  Future<void> removeAccount(String role, String loginId) async {
    final all = await _readAll();
    final updated =
        all.where((a) => !(a.role == role && a.loginId == loginId)).toList();
    await _writeAll(updated);
  }

  /// Flip the app lock for the account that owns [uid]. Login identifiers can
  /// change; the stable Firebase uid is the only valid security binding.
  Future<void> setBiometricEnabled({
    required String role,
    required String uid,
    required bool enabled,
  }) async {
    final all = await _readAll();
    final updated =
        all.map((account) {
          if (account.role == role && account.uid == uid) {
            return account.withUpdated(biometricEnabled: enabled);
          }
          return account;
        }).toList();
    await _writeAll(updated);
  }

  Future<SavedAccount?> findForSession(AuthSession session) async {
    final all = await loadAll();
    for (final account in all) {
      if (account.matchesSession(session)) return account;
    }
    return null;
  }

  Future<bool> isBiometricAppLockEnabledFor(AuthSession session) async {
    final accounts = await loadAll();
    return accounts.any(
      (account) => account.biometricEnabled && account.matchesSession(session),
    );
  }

  Future<void> saveAll(List<SavedAccount> accounts) async {
    await _writeAll(accounts);
  }
}

final Provider<SavedAccountsService> savedAccountsServiceProvider =
    Provider<SavedAccountsService>((Ref ref) => SavedAccountsService());
