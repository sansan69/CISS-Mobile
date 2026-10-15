import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/permissions/device_readiness.dart';
import '../../shared/widgets/modern_card.dart';
import 'device_readiness_screen.dart';

/// One-line prompt on guard Home and both "More" hubs while a required
/// permission is outstanding.
///
/// It renders from the cached snapshot, so showing it costs no platform read.
/// Advisory items (battery exemption, auto-start) deliberately do not raise it:
/// they cannot block a punch and the tracking-health card already reports them.
class ReadinessBanner extends ConsumerWidget {
  const ReadinessBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final tokens = CissThemeTokens.of(context);
    final snapshot = ref.watch(readinessCacheProvider);
    final blocking = snapshot?.blocking ?? const <ReadinessItem>[];
    if (snapshot == null || blocking.isEmpty) return const SizedBox.shrink();

    final missing = buildReadinessSteps(
      snapshot,
      strings,
    ).where((step) => blocking.contains(step.item)).map((step) => step.title);

    return ModernCard(
      onTap:
          onTap ??
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DeviceReadinessScreen(),
            ),
          ),
      borderColor: tokens.warning.withValues(alpha: 0.45),
      backgroundColor: tokens.warningSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.rule_folder_rounded, color: tokens.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.readinessBannerTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${strings.readinessBannerBody} ${missing.join(' · ')}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, color: tokens.warning),
        ],
      ),
    );
  }
}
