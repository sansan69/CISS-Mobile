/// Thrown when the backend rejects a Firebase-authenticated mobile session.
///
/// A 401/403 response from `/api/mobile/session` is an authorization decision,
/// not a recoverable transport problem. Keeping it typed prevents callers from
/// accidentally treating a denied account as an offline session.
class AuthoritativeSessionDeniedError implements Exception {
  const AuthoritativeSessionDeniedError(this.statusCode);

  final int statusCode;

  @override
  String toString() =>
      'AuthoritativeSessionDeniedError: mobile session denied (HTTP $statusCode).';
}

/// Thrown when the authoritative session endpoint cannot produce a valid
/// application session for an authenticated Firebase user.
class AuthoritativeSessionResolutionError implements Exception {
  const AuthoritativeSessionResolutionError(this.message);

  final String message;

  @override
  String toString() => 'AuthoritativeSessionResolutionError: $message';
}

/// Thrown when `/api/mobile/session` could not be reached at all: no HTTP
/// response was received (connection refused/reset, DNS, timeout).
///
/// This is *not* an authorization decision. Callers may restore a bounded
/// offline session snapshot for the same uid, but must never treat a 4xx/5xx,
/// malformed payload, or UID mismatch as transport — those stay
/// [AuthoritativeSessionDeniedError]/[AuthoritativeSessionResolutionError] and
/// fail closed.
class AuthoritativeSessionTransportError implements Exception {
  const AuthoritativeSessionTransportError([this.message]);

  final String? message;

  @override
  String toString() =>
      'AuthoritativeSessionTransportError: mobile session unreachable'
      '${message == null ? '' : ' ($message)'}.';
}
