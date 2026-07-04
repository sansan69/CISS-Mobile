import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_client.dart';
import 'mobile_repository.dart';
import '../region/region_service.dart';

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>((
  Ref ref,
) {
  return ref.read(regionServiceProvider).activeAuth;
});

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
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
  );
});

/// Drives the selected tab in [ClientShell].
/// Dashboard quick-action buttons write to this provider to navigate tabs.
final clientTabIndexProvider = StateProvider<int>((ref) => 0);

/// Drives the selected tab in [AdminShell].
final adminTabIndexProvider = StateProvider<int>((ref) => 0);

final Provider<MobileRepository> mobileRepositoryProvider =
    Provider<MobileRepository>((Ref ref) {
      return MobileRepository(
        ref.read(apiClientProvider),
        ref.read(firebaseAuthProvider),
        ref.read(regionServiceProvider),
      );
    });
