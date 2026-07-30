import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Uppercase section label with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.actionLabel,
    this.onActionTap,
    this.padding,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: tokens.inkMuted,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
