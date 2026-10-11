import '../models/auth_session.dart';

/// The authentication operations used by the application session layer.
///
/// Keeping this narrow makes the authentication lifecycle independently
/// testable while the production implementation remains [MobileRepository].
abstract interface class AuthRepository {
  Future<AuthSession?> resolveCurrentSession();

  Future<AuthSession> signInGuard({
    required String loginIdOrPhone,
    required String pin,
  });

  Future<AuthSession> signInFieldOfficer({
    required String email,
    required String password,
  });

  /// Verifies a guard PIN without changing the primary Firebase identity.
  Future<void> verifyCurrentGuardPin({
    required AuthSession expectedSession,
    required String loginIdOrPhone,
    required String pin,
  });

  /// Reauthenticates the current field-officer Firebase user in place.
  Future<void> verifyCurrentFieldOfficerPassword({
    required AuthSession expectedSession,
    required String email,
    required String password,
  });

  Future<void> signOut();
}
