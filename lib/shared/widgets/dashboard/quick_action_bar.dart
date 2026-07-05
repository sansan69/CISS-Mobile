import 'package:flutter/material.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';

/// A horizontal scrollable action bar with prominent touch targets.
///
/// Each action shows an icon in a colored circle + label below.
/// Designed for dashboard shortcuts that need to be immediately tappable.
class QuickActionBar extends StatelessWidget {
  const QuickActionBar({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        itemBuilder:
            (BuildContext context, int index) =>
                _ActionItem(action: actions[index]),
        separatorBuilder:
            (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.sm),
        itemCount: actions.length,
      ),
    );
  }
}

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return SizedBox(
      width: 96,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.light();
            action.onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: tokens.border.withValues(alpha: 0.75)),
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: action.color.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(action.icon, color: action.color, size: 25),
                    ),
                    if (action.badge != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.danger,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tokens.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            action.badge!,
                            style: TextStyle(
                              color: tokens.surface,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
