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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color resolvedAccent = accentColor ?? tokens.primary;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? tokens.surface.withValues(alpha: 0.65)
                  : tokens.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark
                    ? resolvedAccent.withValues(alpha: 0.22)
                    : resolvedAccent.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: resolvedAccent.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
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
