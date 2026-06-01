import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/providers.dart';
import '../offline/local_report_store.dart';
import '../offline/offline_queue.dart';
import 'sync_service.dart';

final offlineQueueProvider = ChangeNotifierProvider<OfflineQueue>((ref) {
  return OfflineQueue();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.watch(mobileRepositoryProvider);
  final queue = ref.watch(offlineQueueProvider);
  final localReportStore = ref.watch(localReportStoreProvider);
  final service = SyncService(repository, queue, localReportStore);
  service.start();
  ref.onDispose(() => service.stop());
  return service;
});
