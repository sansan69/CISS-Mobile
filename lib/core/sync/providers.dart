import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/tracking_buffer.dart';
import '../network/providers.dart';
import '../offline/offline_queue.dart';
import 'sync_service.dart';
import '../../features/guard/application/duty_willingness_controller.dart';
import '../../features/auth/application/auth_controller.dart';
import 'dart:async';

final offlineQueueProvider = ChangeNotifierProvider<OfflineQueue>((ref) {
  return OfflineQueue();
});

/// Buffers location samples captured while offline so [SyncService] can flush
/// them in a single batch once connectivity returns.
final trackingBufferProvider = Provider<TrackingBuffer>((ref) {
  return TrackingBuffer();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.read(mobileRepositoryProvider);
  final queue = ref.read(offlineQueueProvider);
  final trackingBuffer = ref.read(trackingBufferProvider);
  final service = SyncService(
    repository,
    queue,
    trackingBuffer,
    syncWillingness: () => ref.read(dutyWillingnessControllerProvider).sync(),
  );
  ref.listen(authSessionProvider, (previous, next) {
    if (next.valueOrNull != null) {
      unawaited(
        ref
            .read(dutyWillingnessControllerProvider)
            .sync()
            .catchError((Object _) {}),
      );
    }
  });
  service.start();
  ref.onDispose(service.stop);
  return service;
});
