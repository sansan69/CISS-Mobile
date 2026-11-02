import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'pressable.dart';

/// A compact secondary action: icon, label, optional trailing text + chevron.
///
/// Use a short stack of these instead of equal-weight tile grids. At least
/// 56 px tall; focused on one intent per row.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Semantics(
      button: true,
      label: trailing == null ? label : '$label, $trailing',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: tokens.surface,
          child: Row(
            children: <Widget>[
              Icon(icon, color: tokens.primary, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: tokens.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.inkMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
