import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Compact, consistent connectivity indicator.
///
/// Shows a small badge when the device is offline so guards know data is
/// queued and will send when connection returns. Purely presentational —
/// the sync state is driven by the offline queue / connectivity streams.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : AppSpacing.sm,
        vertical: compact ? 4 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tokens.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, size: 14, color: tokens.warning),
          const SizedBox(width: 6),
          Text(
            'Offline',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: tokens.warning,
            ),
          ),
        ],
      ),
    );
  }
}
