import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache/preload_controller.dart';
import '../core/fcm/notification_service.dart';
import '../core/fcm/providers.dart';
import '../core/models/auth_session.dart';
import '../core/network/mobile_repository.dart';
import '../core/network/providers.dart';
import '../core/offline/offline_queue.dart';
import '../core/offline/offline_request.dart';
import '../core/offline/willingness_queue.dart';
import '../core/models/duty_models.dart';
import '../features/guard/application/duty_willingness_controller.dart';
import '../core/region/region_service.dart';
import '../core/settings/remote_config.dart';
import '../core/settings/remote_config_provider.dart';
import '../core/sync/providers.dart';
import '../core/sync/sync_service.dart';
import '../features/auth/application/auth_controller.dart';

Never _blocked(Invocation invocation) =>
    throw StateError(
      'Preview blocks service calls (${invocation.memberName}). No data was sent or saved.',
    );

class _PreviewSession extends AuthSessionNotifier {
  @override
  Future<AuthSession?> build() async => null;
}

/// Fixtures override reads; every other call fails before any live client or
/// network/storage fallback is created. No mutation can report mock success.
class _PreviewRepository implements MobileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => _blocked(invocation);
}

class _PreviewSync implements SyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) => _blocked(invocation);
}

class _PreviewNotifications implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => _blocked(invocation);
}

class _PreviewAuth implements AuthController {
  @override
  dynamic noSuchMethod(Invocation invocation) => _blocked(invocation);
}

class _PreviewRegion implements RegionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => _blocked(invocation);
}

class _PreviewQueue extends OfflineQueue {
  @override
  bool get isInitialized => false;
  @override
  int get queueSize => 0;
  @override
  List<OfflineRequest> getQueuedRequests() => const <OfflineRequest>[];
  @override
  Future<void> init() =>
      throw StateError('Preview blocks local queue initialization.');
  @override
  Future<void> enqueue({
    required String path,
    required String method,
    required Map<String, dynamic> body,
  }) => throw StateError('Preview blocks offline mutation. No data was saved.');
  @override
  Future<void> removeRequest(String id) =>
      throw StateError('Preview blocks queue mutation.');
  @override
  Future<void> updateRequest(OfflineRequest request) =>
      throw StateError('Preview blocks queue mutation.');
  @override
  Future<void> clear() => throw StateError('Preview blocks queue mutation.');
}

class _BlockedWillingnessStore implements WillingnessStore {
  @override
  Future<List<Map<String, dynamic>>> read() =>
      throw StateError('Preview blocks willingness storage.');
  @override
  Future<void> write(List<Map<String, dynamic>> rows) =>
      throw StateError('Preview blocks willingness storage.');
}

class _PreviewWillingnessQueue extends WillingnessQueue {
  _PreviewWillingnessQueue() : super(_BlockedWillingnessStore());
  @override
  Future<WillingnessOperation> choose({
    required String ownerUid,
    required String apiBaseUrl,
    required String workOrderId,
    required WillingnessStatus response,
    required int expectedVersion,
  }) =>
      throw StateError(
        'Preview blocks offline willingness. No data was sent or saved.',
      );
}

class _PreviewConfig extends RemoteConfigNotifier {
  @override
  RemoteConfig build() => RemoteConfig.defaults();
  @override
  Future<void> refresh({bool force = false}) async {}
}

/// Install in each fixture scope as well as the root: Riverpod providers without
/// declared dependencies must not inherit a production parent when a role or
/// its data providers have been overridden in a nested scope.
List<Override> previewSafetyOverrides({
  AuthSession? fixtureSession,
}) => <Override>[
  dutyWillingnessControllerProvider.overrideWith(
    (ref) => DutyWillingnessController(ref),
  ),
  willingnessQueueProvider.overrideWith((ref) => _PreviewWillingnessQueue()),
  dutyResponseProvider.overrideWith((ref, id) => null),
  dutyResponseHistoryProvider.overrideWith(
    (ref) => const <WillingnessOperation>[],
  ),
  mobileRepositoryProvider.overrideWithValue(_PreviewRepository()),
  authRepositoryProvider.overrideWithValue(_PreviewRepository()),
  apiClientProvider.overrideWith(
    (ref) => throw StateError('Preview blocks HTTP clients.'),
  ),
  firebaseAuthProvider.overrideWith(
    (ref) => throw StateError('Preview blocks Firebase clients.'),
  ),
  regionServiceProvider.overrideWithValue(_PreviewRegion()),
  savedRegionProvider.overrideWith((ref) async => null),
  authControllerProvider.overrideWithValue(_PreviewAuth()),
  authSessionProvider.overrideWith(
    fixtureSession == null
        ? _PreviewSession.new
        : () => _FixtureSession(fixtureSession),
  ),
  workspaceAccessSessionKeyProvider.overrideWith(
    (ref) =>
        fixtureSession == null
            ? null
            : '${fixtureSession.role.name}:${fixtureSession.uid}',
  ),
  remoteConfigProvider.overrideWith(_PreviewConfig.new),
  syncServiceProvider.overrideWithValue(_PreviewSync()),
  offlineQueueProvider.overrideWith((ref) => _PreviewQueue()),
  notificationServiceProvider.overrideWithValue(_PreviewNotifications()),
  NotificationService.unreadCountProvider.overrideWith(
    (ref) => Stream<int>.value(0),
  ),
  NotificationService.notificationsProvider.overrideWithValue(
    const AsyncData(<Map<String, dynamic>>[]),
  ),
  // Keep the real preload path, but bind it to the fixture's local Ref.
  preloadControllerProvider.overrideWith((ref) => PreloadController(ref)),
];

class _FixtureSession extends AuthSessionNotifier {
  _FixtureSession(this._session);
  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}
