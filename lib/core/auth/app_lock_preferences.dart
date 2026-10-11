import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';

/// In-memory, uid-scoped app-lock preferences for the active UI session.
/// Secure storage remains the durable source of truth; this makes completed
/// preference changes visible to AuthGate immediately.
class AppLockPreferencesNotifier extends StateNotifier<Map<String, bool>> {
  AppLockPreferencesNotifier() : super(const <String, bool>{});

  static String keyFor(AuthSession session) =>
      '${session.role.name}:${session.uid}';

  void setFor(AuthSession session, bool enabled) {
    state = <String, bool>{...state, keyFor(session): enabled};
  }
}

final appLockPreferencesProvider =
    StateNotifierProvider<AppLockPreferencesNotifier, Map<String, bool>>(
      (ref) => AppLockPreferencesNotifier(),
    );
