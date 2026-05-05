import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

enum StatusChipTone { neutral, info, success, warning, danger }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = StatusChipTone.neutral,
  });

  final String label;
  final IconData? icon;
  final StatusChipTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final _StatusStyle style = _styleFor(tone, tokens);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: style.foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _StatusStyle _styleFor(StatusChipTone tone, CissThemeTokens tokens) {
    switch (tone) {
      case StatusChipTone.info:
        return _StatusStyle(
          background: tokens.primarySoft,
          border: tokens.primary.withValues(alpha: 0.28),
          foreground: tokens.primaryStrong,
        );
      case StatusChipTone.success:
        return _StatusStyle(
          background: tokens.successSoft,
          border: tokens.success.withValues(alpha: 0.28),
          foreground: tokens.success,
        );
      case StatusChipTone.warning:
        return _StatusStyle(
          background: tokens.warningSoft,
          border: tokens.warning.withValues(alpha: 0.28),
          foreground: tokens.warning,
        );
      case StatusChipTone.danger:
        return _StatusStyle(
          background: tokens.dangerSoft,
          border: tokens.danger.withValues(alpha: 0.28),
          foreground: tokens.danger,
        );
      case StatusChipTone.neutral:
        return _StatusStyle(
          background: tokens.surfaceMuted,
          border: tokens.border,
          foreground: tokens.inkMuted,
        );
    }
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}
