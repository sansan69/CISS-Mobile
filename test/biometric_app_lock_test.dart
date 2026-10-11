import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/legacy_biometric_credential_cleanup.dart';
import 'package:ciss_mobile/core/auth/saved_accounts_service.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';

class _InMemorySavedAccountsService extends SavedAccountsService {
  _InMemorySavedAccountsService(this.accounts);

  final List<SavedAccount> accounts;

  @override
  Future<List<SavedAccount>> loadAll() async => List<SavedAccount>.of(accounts);
}

class _InMemorySavedAccountsStorage implements SavedAccountsStorage {
  _InMemorySavedAccountsStorage({
    this.failReads = false,
    this.failWrites = false,
  });

  final bool failReads;
  final bool failWrites;
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({required String key}) async {
    if (failReads) throw StateError('secure storage unavailable');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('secure storage unavailable');
    values[key] = value;
  }
}

class _InMemoryLegacyStorage implements LegacyBiometricStorage {
  _InMemoryLegacyStorage(this.values);

  final Map<String, String> values;
  final List<String> deletedKeys = <String>[];

  @override
  Future<void> delete({required String key}) async {
    deletedKeys.add(key);
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map<String, String>.of(values);
}

AuthSession _session({required AppRole role, required String uid}) {
  return AuthSession(
    role: role,
    displayName: 'Test User',
    primaryId: 'CISS/2026/001',
    uid: uid,
    email: 'officer@cissindia.co.in',
  );
}

void main() {
  group('SavedAccount biometric app lock', () {
    test(
      'serializes uid and matches only the exact role and Firebase user',
      () {
        final account = SavedAccount(
          role: 'guard',
          loginId: 'CISS/2026/001',
          displayName: 'Guard User',
          lastLoginAt: DateTime.utc(2026, 8, 19),
          uid: 'guard-uid',
          biometricEnabled: true,
        );

        final restored = SavedAccount.fromJson(account.toJson());

        expect(restored.uid, 'guard-uid');
        expect(restored.biometricEnabled, isTrue);
        expect(
          restored.matchesSession(
            _session(role: AppRole.guard, uid: 'guard-uid'),
          ),
          isTrue,
        );
        expect(
          restored.matchesSession(
            _session(role: AppRole.guard, uid: 'other-uid'),
          ),
          isFalse,
        );
        expect(
          restored.matchesSession(
            _session(role: AppRole.fieldOfficer, uid: 'guard-uid'),
          ),
          isFalse,
        );
      },
    );

    test('legacy records without a uid cannot activate an app lock', () {
      final legacy = SavedAccount.fromJson(<String, dynamic>{
        'role': 'guard',
        'loginId': 'CISS/2026/001',
        'displayName': 'Legacy Guard',
        'biometricEnabled': true,
      });

      expect(legacy.uid, isEmpty);
      expect(
        legacy.matchesSession(_session(role: AppRole.guard, uid: 'guard-uid')),
        isFalse,
      );
    });

    test('app-lock preference is scoped to the current account uid', () async {
      final service = _InMemorySavedAccountsService(<SavedAccount>[
        SavedAccount(
          role: 'guard',
          loginId: 'CISS/2026/001',
          displayName: 'Locked Guard',
          lastLoginAt: DateTime.now(),
          uid: 'guard-uid',
          biometricEnabled: true,
        ),
        SavedAccount(
          role: 'guard',
          loginId: 'CISS/2026/002',
          displayName: 'Other Guard',
          lastLoginAt: DateTime.now(),
          uid: 'other-uid',
          biometricEnabled: false,
        ),
      ]);

      expect(
        await service.isBiometricAppLockEnabledFor(
          _session(role: AppRole.guard, uid: 'guard-uid'),
        ),
        isTrue,
      );
      expect(
        await service.isBiometricAppLockEnabledFor(
          _session(role: AppRole.guard, uid: 'other-uid'),
        ),
        isFalse,
      );
    });

    test(
      'persistence errors are surfaced instead of reporting a false lock',
      () async {
        final service = SavedAccountsService(
          storage: _InMemorySavedAccountsStorage(failWrites: true),
        );

        await expectLater(
          service.saveAccount(
            SavedAccount(
              role: 'guard',
              loginId: 'CISS/2026/001',
              displayName: 'Guard User',
              lastLoginAt: DateTime.now(),
              uid: 'guard-uid',
              biometricEnabled: true,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('removing a saved account persists the metadata removal', () async {
      final storage = _InMemorySavedAccountsStorage();
      final service = SavedAccountsService(storage: storage);
      await service.saveAccount(
        SavedAccount(
          role: 'guard',
          loginId: 'CISS/2026/001',
          displayName: 'Guard User',
          lastLoginAt: DateTime.now(),
          uid: 'guard-uid',
          biometricEnabled: true,
        ),
      );

      await service.removeAccount('guard', 'CISS/2026/001');

      expect(await service.loadAll(), isEmpty);
    });

    test(
      'preference read errors are surfaced before app-lock evaluation',
      () async {
        final service = SavedAccountsService(
          storage: _InMemorySavedAccountsStorage(failReads: true),
        );

        await expectLater(
          service.findForSession(
            _session(role: AppRole.guard, uid: 'guard-uid'),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  test(
    'legacy cleanup deletes only the retired credential key prefix',
    () async {
      final storage = _InMemoryLegacyStorage(<String, String>{
        'ciss_biometric_cred_guard_1234': 'retired-pin',
        'ciss_saved_accounts_v1': 'saved-accounts',
        'another_plugin_key': 'must-remain',
      });
      final cleanup = LegacyBiometricCredentialCleanup(storage: storage);

      await cleanup.purgeLegacyCredentials();

      expect(storage.deletedKeys, <String>['ciss_biometric_cred_guard_1234']);
      expect(
        storage.values,
        containsPair('ciss_saved_accounts_v1', 'saved-accounts'),
      );
      expect(storage.values, containsPair('another_plugin_key', 'must-remain'));
    },
  );

  test('legacy cleanup key selection uses the retired credential prefix', () {
    expect(
      legacyBiometricCredentialKeys(<String>[
        'ciss_biometric_cred_guard_1234',
        'ciss_saved_accounts_v1',
        'another_plugin_key',
      ]),
      <String>['ciss_biometric_cred_guard_1234'],
    );
  });

  test(
    'forgetting an account deletes its matching legacy credential key',
    () async {
      final storage = _InMemoryLegacyStorage(<String, String>{
        'ciss_biometric_cred_guard_CISS_2026_001': 'retired-pin',
        'another_plugin_key': 'must-remain',
      });

      await LegacyBiometricCredentialCleanup(
        storage: storage,
      ).purgeLegacyCredentialsForAccount(
        role: 'guard',
        loginId: 'CISS/2026/001',
      );

      expect(storage.deletedKeys, <String>[
        'ciss_biometric_cred_guard_CISS_2026_001',
      ]);
      expect(storage.values, containsPair('another_plugin_key', 'must-remain'));
    },
  );

  test('auth UI has no credential replay references', () {
    final loginSource =
        File(
          'lib/features/auth/presentation/role_login_screen.dart',
        ).readAsStringSync();
    final controllerSource =
        File(
          'lib/features/auth/application/auth_controller.dart',
        ).readAsStringSync();

    for (final forbidden in <String>[
      'getStoredPassword',
      'saveCredentials',
      'biometricCredentialStore',
      '_tryBiometricLogin',
    ]) {
      expect(loginSource.contains(forbidden), isFalse, reason: forbidden);
      expect(controllerSource.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test(
    'auth controller persists app-lock metadata before exposing a session',
    () {
      final source =
          File(
            'lib/features/auth/application/auth_controller.dart',
          ).readAsStringSync();
      final persist = source.indexOf('await _prepareAccountForSession(');
      final expose = source.indexOf('notifier.setSession(session)');

      expect(persist, greaterThanOrEqualTo(0));
      expect(expose, greaterThan(persist));
    },
  );
}
