import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'portal_primitives.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final String? helper;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final effectiveAccent = accentColor ?? tokens.primary;

    return PortalSurfaceCard(
      accentColor: effectiveAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: effectiveAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: effectiveAccent.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(icon, color: effectiveAccent, size: 18),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.inkMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (helper != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              helper!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
