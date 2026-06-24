import 'package:flutter/material.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';

/// Clean activity feed list for dashboard recent items.
///
/// Shows icon, title, subtitle, and optional trailing badge.
class ActivityFeed extends StatelessWidget {
  const ActivityFeed({
    super.key,
    required this.title,
    required this.items,
    this.emptyTitle = 'No activity yet',
    this.emptyMessage = 'Recent actions will appear here.',
    this.onViewAll,
  });

  final String title;
  final List<ActivityItem> items;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: AppTypography.title(context).copyWith(
                  fontSize: 18,
                ),
              ),
              if (onViewAll != null && items.isNotEmpty)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View all',
                    style: AppTypography.bodyStrong(context).copyWith(
                      color: tokens.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            _EmptyState(title: emptyTitle, message: emptyMessage)
          else
            ...items.take(5).map((item) => _ActivityRow(item: item)),
        ],
      ),
    );
  }
}

class ActivityItem {
  const ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.onTap == null
              ? null
              : () {
                  Haptics.light();
                  item.onTap!.call();
                },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.iconBgColor,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: AppTypography.bodyStrong(context).copyWith(
                          color: tokens.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: AppTypography.micro(context).copyWith(
                            color: tokens.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.trailing != null)
                  Text(
                    item.trailing!,
                    style: AppTypography.micro(context).copyWith(
                      color: tokens.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.inbox_outlined,
            color: tokens.inkMuted.withValues(alpha: 0.5),
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.bodyStrong(context).copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTypography.micro(context).copyWith(
                    color: tokens.inkMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
