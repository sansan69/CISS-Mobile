import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class ModernCard extends StatelessWidget {
  const ModernCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.radius = 16,
  });

  final Widget? child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor ?? tokens.border,
                width: 1,
              ),
              boxShadow: AppShadows.card,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
