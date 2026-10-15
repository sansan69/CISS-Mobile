import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/haptics/haptic_event.dart';
import 'pressable.dart';

/// The single primary action on a screen.
///
/// One per screen: the thing the user came to do. Fills with Brand Navy,
/// is at least 56 px tall, and carries a `medium` haptic on press. Secondary
/// actions belong in [ActionRow]s, not here.
class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final background = enabled ? tokens.primary : tokens.border;
    final foreground =
        enabled ? Theme.of(context).colorScheme.onPrimary : tokens.inkMuted;

    return PressableScale(
      semanticLabel: sublabel == null ? label : '$label, $sublabel',
      onTap: enabled ? onTap : null,
      haptic: enabled ? HapticEvent.medium : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: foreground, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    softWrap: true,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      softWrap: true,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
