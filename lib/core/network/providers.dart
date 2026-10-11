import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_client.dart';
import 'auth_repository.dart';
import 'mobile_repository.dart';
import '../region/region_service.dart';
import '../settings/remote_config_provider.dart';

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>((
  Ref ref,
) {
  ref.watch(regionGraphRevisionProvider);
  return ref.read(regionServiceProvider).activeAuth;
});

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  ref.watch(regionGraphRevisionProvider);
  final auth = ref.read(firebaseAuthProvider);
  final regionService = ref.read(regionServiceProvider);
  return ApiClient(
    baseUrl: regionService.activeApiUrl,
    authTokenProvider: () async {
      final user = auth.currentUser;
      if (user == null) return null;
      // false = return cached token; Firebase auto-refreshes when < 5 min left.
      // Using true (force-refresh) here triggers idTokenChanges(), which
      // re-runs authSessionProvider → resolveCurrentSession() → another
      // getIdToken(true) → infinite token-refresh loop.
      return user.getIdToken(false);
    },
    authTokenRefreshProvider: () async {
      final user = auth.currentUser;
      if (user == null) return null;
      return user.getIdToken(true);
    },
    onModuleDisabled: () =>
        ref.read(remoteConfigProvider.notifier).refresh(force: true),
  );
});

final Provider<MobileRepository> mobileRepositoryProvider =
    Provider<MobileRepository>((Ref ref) {
      return MobileRepository(
        ref.read(apiClientProvider),
        ref.read(firebaseAuthProvider),
        ref.read(regionServiceProvider),
      );
    });

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => ref.read(mobileRepositoryProvider));
