import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/tracking_buffer.dart';
import '../network/providers.dart';
import '../offline/offline_queue.dart';
import 'sync_service.dart';

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
  final service = SyncService(repository, queue, trackingBuffer);
  service.start();
  ref.onDispose(service.stop);
  return service;
});
