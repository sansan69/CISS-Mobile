/// A backend response identified a different account than the authenticated
/// Firebase bearer token. This must never be downgraded to a claims fallback.
class AuthenticatedIdentityMismatchError implements Exception {
  const AuthenticatedIdentityMismatchError({
    required this.firebaseUid,
    required this.backendUid,
  });

  final String firebaseUid;
  final String backendUid;

  @override
  String toString() =>
      'AuthenticatedIdentityMismatchError: '
      'backend identity does not match the Firebase session.';
}
