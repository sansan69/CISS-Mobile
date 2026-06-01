import 'package:flutter/material.dart';
import '../../../app/theme/app_tokens.dart';

/// A horizontal scrollable action bar with prominent touch targets.
///
/// Each action shows an icon in a colored circle + label below.
/// Designed for dashboard shortcuts that need to be immediately tappable.
class QuickActionBar extends StatelessWidget {
  const QuickActionBar({
    super.key,
    required this.actions,
  });

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: actions.asMap().entries.map((entry) {
          final action = entry.value;
          final isLast = entry.key == actions.length - 1;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
              child: _ActionItem(action: action),
            ),
          );
        }).toList(),
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

    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      action.icon,
                      color: action.color,
                      size: 24,
                    ),
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
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                action.label,
                style: AppTypography.micro(context).copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
