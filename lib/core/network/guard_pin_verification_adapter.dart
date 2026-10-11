import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import 'authenticated_identity_mismatch_error.dart';

/// An isolated Firebase Auth session used solely to verify a guard PIN.
/// It cannot replace or sign out the app's primary regional Firebase session.
abstract interface class IsolatedGuardAuth {
  Future<String?> signInWithCustomToken(String token);

  Future<void> signOut();

  Future<void> dispose();
}

abstract interface class IsolatedGuardAuthFactory {
  Future<IsolatedGuardAuth> create(FirebaseOptions options);
}

class FirebaseIsolatedGuardAuthFactory implements IsolatedGuardAuthFactory {
  const FirebaseIsolatedGuardAuthFactory();

  @override
  Future<IsolatedGuardAuth> create(FirebaseOptions options) async {
    final app = await Firebase.initializeApp(
      name: 'biometric-verification-${const Uuid().v4()}',
      options: options,
    );
    return _FirebaseIsolatedGuardAuth(app);
  }
}

class _FirebaseIsolatedGuardAuth implements IsolatedGuardAuth {
  _FirebaseIsolatedGuardAuth(this._app)
    : _auth = FirebaseAuth.instanceFor(app: _app);

  final FirebaseApp _app;
  final FirebaseAuth _auth;

  @override
  Future<String?> signInWithCustomToken(String token) async {
    return (await _auth.signInWithCustomToken(token)).user?.uid;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> dispose() => _app.delete();
}

class GuardPinVerificationAdapter {
  GuardPinVerificationAdapter({IsolatedGuardAuthFactory? factory})
    : _factory = factory ?? const FirebaseIsolatedGuardAuthFactory();

  final IsolatedGuardAuthFactory _factory;

  Future<void> verify({
    required FirebaseOptions regionalOptions,
    required String token,
    required String expectedUid,
  }) async {
    final auth = await _factory.create(regionalOptions);
    try {
      final uid = await auth.signInWithCustomToken(token);
      if (uid != expectedUid) {
        throw AuthenticatedIdentityMismatchError(
          firebaseUid: uid ?? '',
          backendUid: expectedUid,
        );
      }
    } finally {
      try {
        await auth.signOut();
      } catch (_) {
        // The temporary app is disposed below; cleanup cannot mutate primary
        // Firebase authentication or turn verification into a sign-in.
      }
      try {
        await auth.dispose();
      } catch (_) {}
    }
  }
}
