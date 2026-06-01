import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/providers.dart';
import '../offline/offline_queue.dart';
import 'sync_service.dart';

final offlineQueueProvider = ChangeNotifierProvider<OfflineQueue>((ref) {
  return OfflineQueue();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.read(mobileRepositoryProvider);
  final queue = ref.read(offlineQueueProvider);
  final service = SyncService(repository, queue);
  service.start();
  ref.onDispose(service.stop);
  return service;
});
