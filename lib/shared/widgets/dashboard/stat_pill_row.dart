import 'package:flutter/material.dart';
import '../../../app/theme/app_tokens.dart';

/// Horizontal row of compact stat pills.
///
/// Shows label + value in a minimal badge format. Ideal for
/// dashboard summary stats that don't need full cards.
class StatPillRow extends StatelessWidget {
  const StatPillRow({
    super.key,
    required this.pills,
  });

  final List<StatPill> pills;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: pills.asMap().entries.map((entry) {
          final pill = entry.value;
          final isLast = entry.key == pills.length - 1;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
              child: _Pill(pill: pill),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StatPill {
  const StatPill({
    required this.label,
    required this.value,
    this.accentColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color? accentColor;
  final IconData? icon;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.pill});

  final StatPill pill;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final accent = pill.accentColor ?? tokens.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: accent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (pill.icon != null) ...<Widget>[
                Icon(
                  pill.icon,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  pill.label,
                  style: AppTypography.micro(context).copyWith(
                    color: tokens.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pill.value,
            style: AppTypography.metric(context).copyWith(
              color: accent,
              fontSize: 24,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
