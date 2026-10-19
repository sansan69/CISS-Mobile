import '../../core/i18n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/providers.dart';

class SyncHealthCard extends ConsumerWidget {
  const SyncHealthCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final queue = ref.watch(offlineQueueProvider);
    String time(DateTime? value) =>
        value?.toLocal().toString().split('.').first ??
        strings.label('syncNone');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.label('syncHealth'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(strings.label('syncScope')),
            Text(
              strings.fill(strings.label('syncCounts'), {
                'pending': queue.pendingCount,
                'rejected': queue.rejectedCount,
              }),
            ),
            Text(
              strings.fill(strings.label('syncOldest'), {
                'time': time(queue.oldestPending),
              }),
            ),
            Text(
              strings.fill(strings.label('syncAck'), {
                'time': time(queue.lastAcknowledgedAt),
              }),
            ),
            if (queue.lastFailureReason != null)
              Text(
                strings.fill(strings.label('syncFailure'), {
                  'reason': queue.lastFailureReason!,
                }),
              ),
            if (queue.rejectedCount > 0) Text(strings.label('syncRejected')),
            TextButton.icon(
              onPressed: () => ref.read(syncServiceProvider).processQueue(),
              icon: const Icon(Icons.sync),
              label: Text(strings.label('syncNow')),
            ),
          ],
        ),
      ),
    );
  }
}
