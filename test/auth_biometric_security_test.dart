import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/legacy_biometric_credential_cleanup.dart';
import 'package:ciss_mobile/core/auth/saved_accounts_service.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';

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
    test('serializes a stable uid and matches only that role and session', () {
      final account = SavedAccount(
        role: 'fieldOfficer',
        loginId: 'officer@cissindia.co.in',
        displayName: 'Officer',
        lastLoginAt: DateTime.utc(2026, 8, 19),
        uid: 'firebase-uid-1',
        biometricEnabled: true,
      );

      final restored = SavedAccount.fromJson(account.toJson());

      expect(restored.uid, 'firebase-uid-1');
      expect(restored.biometricEnabled, isTrue);
      expect(
        restored.matchesSession(
          _session(role: AppRole.fieldOfficer, uid: 'firebase-uid-1'),
        ),
        isTrue,
      );
      expect(
        restored.matchesSession(
          _session(role: AppRole.fieldOfficer, uid: 'different-user'),
        ),
        isFalse,
      );
      expect(
        restored.matchesSession(
          _session(role: AppRole.guard, uid: 'firebase-uid-1'),
        ),
        isFalse,
      );
    });

    test('legacy saved-account records cannot activate an app lock', () {
      final legacy = SavedAccount.fromJson(<String, dynamic>{
        'role': 'guard',
        'loginId': '9876543210',
        'displayName': 'Guard',
        'lastLoginAt': '2026-08-19T00:00:00.000Z',
        'biometricEnabled': true,
      });

      expect(legacy.uid, isEmpty);
      expect(
        legacy.matchesSession(_session(role: AppRole.guard, uid: 'uid-1')),
        isFalse,
      );
    });
  });

  test('legacy cleanup targets only retired biometric credential keys', () {
    final keys =
        legacyBiometricCredentialKeys(<String>[
          'ciss_biometric_cred_guard_9876543210',
          'ciss_saved_accounts_v1',
          'offline_queue_key',
          'ciss_biometric_cred_fieldOfficer_officer_example_com',
        ]).toList();

    expect(keys, <String>[
      'ciss_biometric_cred_guard_9876543210',
      'ciss_biometric_cred_fieldOfficer_officer_example_com',
    ]);
  });
}
