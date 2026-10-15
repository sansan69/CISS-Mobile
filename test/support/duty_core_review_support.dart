import 'package:firebase_auth/firebase_auth.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/offline/willingness_queue.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'guard_redesign_fixtures.dart';

class Store implements WillingnessStore {
  List<Map<String, dynamic>> rows = [];
  @override
  Future<List<Map<String, dynamic>>> read() async => rows;
  @override
  Future<void> write(List<Map<String, dynamic>> r) async {
    rows = r;
  }
}

class Auth implements FirebaseAuth {
  String uid = 'auth-a';
  @override
  User? get currentUser => TestUser(uid);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestUser implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token-$uid';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class Region implements RegionService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class Session extends AuthSessionNotifier {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    role: AppRole.guard,
    displayName: 'A',
    primaryId: 'A',
    uid: 'auth-a',
  );
}

class Repo extends NoNetworkRepository {
  @override
  String get dutyApiBaseUrl => 'https://a.invalid';
}
