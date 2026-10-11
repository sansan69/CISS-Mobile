import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/network/authenticated_identity_mismatch_error.dart';
import 'package:ciss_mobile/core/network/guard_pin_verification_adapter.dart';

class _FakeIsolatedGuardAuth implements IsolatedGuardAuth {
  _FakeIsolatedGuardAuth(this.uid, {this.failSignOut = false});

  final String? uid;
  final bool failSignOut;
  int signInCalls = 0;
  int signOutCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }

  @override
  Future<String?> signInWithCustomToken(String token) async {
    signInCalls += 1;
    return uid;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    if (failSignOut) throw StateError('temporary auth sign-out failed');
  }
}

class _FakeIsolatedGuardAuthFactory implements IsolatedGuardAuthFactory {
  _FakeIsolatedGuardAuthFactory(this.auth);

  final _FakeIsolatedGuardAuth auth;
  FirebaseOptions? receivedOptions;

  @override
  Future<IsolatedGuardAuth> create(FirebaseOptions options) async {
    receivedOptions = options;
    return auth;
  }
}

void main() {
  const regionalOptions = FirebaseOptions(
    apiKey: 'regional-key',
    appId: '1:123:android:regional',
    messagingSenderId: '123',
    projectId: 'regional-project',
    storageBucket: 'regional-project.appspot.com',
  );

  test(
    'isolated regional Guard verification uses the active regional options',
    () async {
      final auth = _FakeIsolatedGuardAuth('regional-guard-uid');
      final factory = _FakeIsolatedGuardAuthFactory(auth);
      final adapter = GuardPinVerificationAdapter(factory: factory);

      await adapter.verify(
        regionalOptions: regionalOptions,
        token: 'custom-token',
        expectedUid: 'regional-guard-uid',
      );

      expect(factory.receivedOptions, same(regionalOptions));
      expect(auth.signInCalls, 1);
      expect(auth.signOutCalls, 1);
      expect(auth.disposeCalls, 1);
    },
  );

  test(
    'isolated verifier disposes its regional session after a UID mismatch',
    () async {
      final auth = _FakeIsolatedGuardAuth('other-uid', failSignOut: true);
      final adapter = GuardPinVerificationAdapter(
        factory: _FakeIsolatedGuardAuthFactory(auth),
      );

      await expectLater(
        adapter.verify(
          regionalOptions: regionalOptions,
          token: 'custom-token',
          expectedUid: 'regional-guard-uid',
        ),
        throwsA(isA<AuthenticatedIdentityMismatchError>()),
      );

      expect(auth.signOutCalls, 1);
      expect(auth.disposeCalls, 1);
    },
  );
}
