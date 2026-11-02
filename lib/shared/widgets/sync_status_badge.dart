import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/sync/providers.dart';
import '../../features/auth/application/auth_controller.dart';

/// Queue-health + offline-session indicator.
///
/// Shows the number of queued actions, how many exhausted their retries
/// (`blocked`, kept on disk — never silently deleted) and how many were dropped
/// by the hard queue cap (`dropped`, audit F-22). While the session is running
/// on the offline grace snapshot it also reads "Offline" so the user knows the
/// account has not been re-verified with the server.
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final queue = ref.watch(offlineQueueProvider);
    final offline = ref.watch(sessionOfflineProvider);
    final pending = queue.pendingCount;
    final blocked = queue.blockedCount;
    final evicted = queue.evictedCount;
    final isDanger = blocked > 0 || evicted > 0;

    final labelParts = <String>[
      if (offline) 'Offline',
      if (pending > 0) '$pending pending',
      if (blocked > 0) '$blocked blocked',
      if (evicted > 0) '$evicted dropped',
    ];
    final visible = labelParts.isNotEmpty;
    final label = labelParts.join(' · ');
    final foreground = isDanger ? tokens.danger : tokens.warning;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child:
          visible
              ? GestureDetector(
                onTap: onTap,
                child: Container(
                  key: ValueKey<String>('sync-status-$label'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDanger ? tokens.dangerSoft : tokens.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: foreground),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isDanger
                              ? Icons.error_outline_rounded
                              : offline
                              ? Icons.cloud_off_rounded
                              : Icons.sync_problem_rounded,
                          size: 16,
                          color: foreground,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : const SizedBox.shrink(key: ValueKey<String>('sync-status-none')),
    );
  }
}
