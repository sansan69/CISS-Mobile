import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/sync/providers.dart';

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final queue = ref.watch(offlineQueueProvider);
    final size = queue.queueSize;

    if (size == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tokens.warning),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.sync_problem_rounded, size: 16, color: tokens.warning),
          const SizedBox(width: 6),
          Text(
            '$size pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.warning,
            ),
          ),
        ],
      ),
    );
  }
}
