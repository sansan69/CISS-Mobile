import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/auth_session.dart';
import '../../../core/models/guard_pin_status.dart';
import '../../../core/network/providers.dart';

final StreamProvider<AuthSession?> authSessionProvider =
    StreamProvider<AuthSession?>((Ref ref) async* {
      final auth = ref.watch(firebaseAuthProvider);
      await for (final User? user in auth.idTokenChanges()) {
        if (user == null) {
          yield null;
          continue;
        }

        yield await ref.read(mobileRepositoryProvider).resolveCurrentSession();
      }
    });

class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  Future<AuthSession> signInAsGuard({
    required String loginIdOrPhone,
    required String pin,
  }) async {
    final session = await _ref
        .read(mobileRepositoryProvider)
        .signInGuard(loginIdOrPhone: loginIdOrPhone, pin: pin);
    _ref.invalidate(authSessionProvider);
    return session;
  }

  Future<GuardPinStatus> checkGuardPinStatus({required String loginIdOrPhone}) {
    return _ref
        .read(mobileRepositoryProvider)
        .checkGuardPinStatus(loginIdOrPhone: loginIdOrPhone);
  }

  Future<void> setupGuardPin({
    required String employeeId,
    required String phoneNumber,
    required String dateOfBirth,
    required String pin,
  }) {
    return _ref
        .read(mobileRepositoryProvider)
        .setupGuardPin(
          employeeId: employeeId,
          phoneNumber: phoneNumber,
          dateOfBirth: dateOfBirth,
          pin: pin,
        );
  }

  Future<AuthSession> signInAsFieldOfficer({
    required String email,
    required String password,
  }) async {
    final session = await _ref
        .read(mobileRepositoryProvider)
        .signInFieldOfficer(email: email, password: password);
    _ref.invalidate(authSessionProvider);
    return session;
  }

  Future<void> signOut() async {
    await _ref.read(mobileRepositoryProvider).signOut();
    _ref.invalidate(authSessionProvider);
  }
}

final Provider<AuthController> authControllerProvider =
    Provider<AuthController>((Ref ref) => AuthController(ref));
