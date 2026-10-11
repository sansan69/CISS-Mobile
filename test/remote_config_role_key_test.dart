import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:ciss_mobile/core/settings/remote_config_store.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedSessionNotifier extends AuthSessionNotifier {
  _FixedSessionNotifier(this.session);
  final AuthSession? session;

  @override
  Future<AuthSession?> build() async => session;
}

/// Records the cache key the provider reads so the test can assert the active
/// role is part of it (production must not fall back to a shared `unknown` key).
class _RecordingStore extends RemoteConfigStore {
  final reads = <String>[];

  @override
  RemoteConfig? read(String key) {
    reads.add(key);
    return null;
  }

  @override
  Future<void> write(String key, RemoteConfig cfg) async {}
}

AuthSession _session(AppRole role) => AuthSession(
      role: role,
      displayName: role.label,
      primaryId: 'p',
      uid: 'u',
    );

/// The auth session resolves asynchronously, so the notifier re-keys after the
/// first microtask; wait for it before reading the recorded cache key.
Future<String> _keyForRoleAsync(AppRole role) async {
  final store = _RecordingStore();
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(() => _FixedSessionNotifier(_session(role))),
      remoteConfigStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  container.read(remoteConfigProvider);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  expect(store.reads, isNotEmpty);
  return store.reads.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache key includes the active role, not "unknown"', () async {
    expect(await _keyForRoleAsync(AppRole.guard), 'KL:guard');
  });

  test('guard and field officer do not share a snapshot', () async {
    expect(
      await _keyForRoleAsync(AppRole.guard),
      isNot(await _keyForRoleAsync(AppRole.fieldOfficer)),
    );
  });
}
