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
    this.radius = AppRadius.card,
    this.hasGlow = false,
    this.glowColor,
  });

  final Widget? child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final double radius;
  final bool hasGlow;
  final Color? glowColor;

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
                color: borderColor ?? tokens.specularBorder,
                width: 1,
              ),
              boxShadow: hasGlow
                  ? AppShadows.glow(glowColor ?? tokens.primary)
                  : AppShadows.card,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
