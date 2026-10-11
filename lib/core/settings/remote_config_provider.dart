// lib/core/settings/remote_config_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/providers.dart';
import '../region/region_service.dart';
import '../../features/auth/application/auth_controller.dart';
import 'remote_config.dart';
import 'remote_config_store.dart';

typedef RemoteConfigFetch = Future<Map<String, dynamic>> Function();

/// Persists per-region/role [RemoteConfig] snapshots so a cold start can show
/// cached settings before the network responds.
final remoteConfigStoreProvider =
    Provider<RemoteConfigStore>((ref) => RemoteConfigStore());

/// Caches the server-driven [RemoteConfig] for the active region and role.
///
/// The production instance is created by [remoteConfigProvider] and resolves
/// its dependencies from Riverpod ([Ref]). For tests the notifier can be built
/// directly with injected [fetch], role, region and store, in which case it
/// keeps its state locally and never touches [Ref]. This keeps the two paths
/// (mounted provider vs. directly-constructed notifier) behaviourally identical
/// without requiring a [ProviderContainer] in unit tests.
class RemoteConfigNotifier extends Notifier<RemoteConfig> {
  RemoteConfigNotifier({
    RemoteConfigFetch? fetch,
    String? role,
    String? regionCode,
    RemoteConfigStore? store,
  })  : _injectedFetch = fetch,
        _injectedRole = role,
        _injectedRegion = regionCode,
        _injectedStore = store,
        _isInjected = fetch != null;

  final RemoteConfigFetch? _injectedFetch;
  final String? _injectedRole;
  final String? _injectedRegion;
  final RemoteConfigStore? _injectedStore;

  /// True when this instance was constructed with explicit dependencies
  /// (typically in tests) and therefore must not use [Ref].
  final bool _isInjected;

  RemoteConfig? _localState;
  bool _inFlight = false;

  static const Duration ttl = Duration(minutes: 15);

  @override
  RemoteConfig build() {
    if (_isInjected) return RemoteConfig.defaults();
    final store = ref.watch(remoteConfigStoreProvider);
    // Re-key on a role change so guard/field-officer never share a snapshot
    // (they can otherwise briefly see each other's flags after a switch). The
    // periodic refresh repopulates the new key.
    ref.listen(authSessionProvider, (previous, next) {
      final previousRole = previous?.valueOrNull?.role.name;
      final nextRole = next.valueOrNull?.role.name;
      if (previousRole == nextRole) return;
      state = store.read(_cacheKey) ?? RemoteConfig.defaults();
      refresh(force: true);
    });
    final key = _cacheKey;
    return store.read(key) ?? RemoteConfig.defaults();
  }

  @override
  RemoteConfig get state {
    if (_isInjected) return _localState ??= RemoteConfig.defaults();
    return super.state;
  }

  @override
  set state(RemoteConfig value) {
    if (_isInjected) {
      _localState = value;
      return;
    }
    super.state = value;
  }

  /// The active role for the cache key. On the production path this is the
  /// authenticated [AuthSession]'s role; until the session resolves it stays the
  /// stable `unknown` placeholder and the auth listener re-keys on change.
  String get _cacheRole {
    if (_injectedRole != null) return _injectedRole;
    if (_isInjected) return 'unknown';
    return ref.read(authSessionProvider).valueOrNull?.role.name ?? 'unknown';
  }

  String get _cacheKey => RemoteConfigStore.keyFor(
        _injectedRegion ??
            (_isInjected
                ? 'KL'
                : ref.read(regionServiceProvider).activeRegion?.code ?? 'KL'),
        _cacheRole,
      );

  RemoteConfigStore? get _store =>
      _injectedStore ??
      (_isInjected ? null : ref.read(remoteConfigStoreProvider));

  Future<void> refresh({bool force = false}) async {
    if (_inFlight) return;
    final current = state;
    if (!force && current.version != 0) {
      final age = DateTime.now().difference(current.fetchedAt);
      if (age < ttl) return;
    }
    _inFlight = true;
    try {
      final fetch =
          _injectedFetch ?? ref.read(mobileRepositoryProvider).fetchRemoteConfig;
      final json = await fetch();
      final next = RemoteConfig.fromJson(json);
      state = next;
      await _store?.write(_cacheKey, next);
    } catch (e) {
      debugPrint('remoteConfig refresh failed (keeping cached/defaults): $e');
    } finally {
      _inFlight = false;
    }
  }
}

final remoteConfigProvider =
    NotifierProvider<RemoteConfigNotifier, RemoteConfig>(RemoteConfigNotifier.new);
