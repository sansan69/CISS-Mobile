import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/providers.dart';

/// Firebase identity events reduced to the only detail the session gate needs:
/// the authenticated Firebase UID. This avoids exposing an application session
/// before it has been resolved and lets lifecycle ordering be tested without a
/// platform Firebase implementation.
abstract interface class FirebaseAuthStateSource {
  String? get currentUid;

  Stream<String?> get idTokenUidChanges;
}

class _FirebaseAuthStateSource implements FirebaseAuthStateSource {
  _FirebaseAuthStateSource(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> get idTokenUidChanges =>
      _auth.idTokenChanges().map((User? user) => user?.uid);
}

final firebaseAuthStateSourceProvider = Provider<FirebaseAuthStateSource>((
  ref,
) {
  return _FirebaseAuthStateSource(ref.watch(firebaseAuthProvider));
});
