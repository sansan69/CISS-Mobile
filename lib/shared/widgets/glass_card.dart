import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accentColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final Color resolvedAccent = accentColor ?? tokens.primary;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tokens.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: accentColor?.withValues(alpha: 0.34) ?? tokens.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: resolvedAccent.withValues(alpha: 0.06),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
