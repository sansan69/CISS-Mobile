import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/sync/providers.dart';

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final queue = ref.watch(offlineQueueProvider);
    final size = queue.queueSize;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child:
          size == 0
              ? const SizedBox.shrink()
              : GestureDetector(
                onTap: onTap,
                child: Container(
                  key: const ValueKey('pending'),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: tokens.warning),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.sync_problem_rounded,
                        size: 16,
                        color: tokens.warning,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$size pending',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: tokens.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
