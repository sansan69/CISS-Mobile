import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/sync/providers.dart';

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  String _getCategoryName(String path) {
    if (path.contains('/attendance/submit')) return 'Attendance Check-In';
    if (path.contains('/guard/incidents')) return 'Incident Report';
    if (path.contains('/guard/leave')) return 'Leave Request';
    if (path.contains('/mobile/token')) return 'FCM Token Registration';
    if (path.contains('/mobile/notifications')) return 'Notification Sync';
    if (path.contains('/field-officer/visit-reports')) {
      return 'Field Visit Report';
    }
    if (path.contains('/field-officer/training-reports')) {
      return 'Field Training Report';
    }
    return 'Sync Data';
  }

  IconData _getCategoryIcon(String path) {
    if (path.contains('/attendance/submit')) return Icons.alarm_on_rounded;
    if (path.contains('/guard/incidents')) return Icons.report_problem_rounded;
    if (path.contains('/guard/leave')) return Icons.event_busy_rounded;
    if (path.contains('/mobile/token')) {
      return Icons.settings_input_antenna_rounded;
    }
    if (path.contains('/mobile/notifications')) {
      return Icons.notifications_active_rounded;
    }
    if (path.contains('/field-officer/visit-reports')) {
      return Icons.assignment_turned_in_rounded;
    }
    if (path.contains('/field-officer/training-reports')) {
      return Icons.model_training_rounded;
    }
    return Icons.sync_rounded;
  }

  void _showSyncQueueDialog(
    BuildContext context,
    WidgetRef ref,
    OfflineQueue queue,
  ) {
    final tokens = CissThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final activeQueue = ref.watch(offlineQueueProvider);
            final requests = activeQueue.getQueuedRequests();
            final failedReqs = requests
                .where((r) => r.retryCount >= 15)
                .toList();
            final pendingReqs = requests
                .where((r) => r.retryCount < 15)
                .toList();

            return Dialog(
              backgroundColor: tokens.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: tokens.border, width: 1),
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: activeQueue.failedCount > 0
                                ? tokens.dangerSoft
                                : tokens.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            activeQueue.failedCount > 0
                                ? Icons.cloud_off_rounded
                                : Icons.cloud_sync_rounded,
                            color: activeQueue.failedCount > 0
                                ? tokens.danger
                                : tokens.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync Queue Status',
                                style: textTheme.titleMedium?.copyWith(
                                  color: tokens.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${activeQueue.failedCount} failed • ${activeQueue.pendingCount} pending',
                                style: textTheme.bodySmall?.copyWith(
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: tokens.inkMuted,
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.xl),

                    // Scrollable list of requests
                    Expanded(
                      child: requests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 48,
                                    color: tokens.success,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'All items synced!',
                                    style: textTheme.titleSmall?.copyWith(
                                      color: tokens.ink,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    'No pending or failed requests in queue.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                if (failedReqs.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: Text(
                                      'FAILED REQUESTS (STALLED)',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: tokens.danger,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  ...failedReqs.map((req) {
                                    return _buildRequestTile(
                                      context,
                                      req,
                                      tokens,
                                      isFailed: true,
                                    );
                                  }),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                if (pendingReqs.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: Text(
                                      'PENDING SYNC REQUESTS',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: tokens.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  ...pendingReqs.map((req) {
                                    return _buildRequestTile(
                                      context,
                                      req,
                                      tokens,
                                      isFailed: false,
                                    );
                                  }),
                                ],
                              ],
                            ),
                    ),

                    const Divider(height: AppSpacing.xl),

                    // Bottom action buttons
                    if (activeQueue.failedCount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.danger,
                              side: BorderSide(color: tokens.danger),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              await activeQueue.clearFailedRequests();
                            },
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 18,
                            ),
                            label: const Text('Clear Failed'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              await activeQueue.retryFailedRequests();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry Failed'),
                          ),
                        ],
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(color: tokens.primary),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestTile(
    BuildContext context,
    dynamic req,
    CissThemeTokens tokens, {
    required bool isFailed,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final dateStr =
        '${req.createdAt.hour.toString().padLeft(2, '0')}:${req.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isFailed
            ? tokens.dangerSoft.withValues(alpha: 0.4)
            : tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isFailed ? tokens.dangerSoft : tokens.border,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getCategoryIcon(req.path),
            size: 20,
            color: isFailed ? tokens.danger : tokens.inkMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getCategoryName(req.path),
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: textTheme.labelSmall?.copyWith(
                        color: tokens.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isFailed && req.lastError != null) ...[
                  Text(
                    'Error: ${req.lastError}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.danger,
                      fontSize: 11,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Pending sync (attempt ${req.retryCount}/15)',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.inkMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final queue = ref.watch(offlineQueueProvider);
    final size = queue.queueSize;
    final failedCount = queue.failedCount;

    if (size == 0) return const SizedBox.shrink();

    final isFailed = failedCount > 0;
    final backgroundColor = isFailed ? tokens.dangerSoft : tokens.warningSoft;
    final borderColor = isFailed ? tokens.danger : tokens.warning;
    final contentColor = isFailed ? tokens.danger : tokens.warning;
    final icon = isFailed
        ? Icons.cloud_off_rounded
        : Icons.sync_problem_rounded;
    final text = isFailed ? '$failedCount Failed' : '$size pending';

    return GestureDetector(
      onTap: () => _showSyncQueueDialog(context, ref, queue),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: contentColor),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: contentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
