import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

/// Surface card used in report detail sheets.
///
/// Formerly a frosted-glass panel; converted to a flat bordered surface for
/// consistency with the rest of the app and to avoid costly blur effects.
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
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: resolvedAccent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}
