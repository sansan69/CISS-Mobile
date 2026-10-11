import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Single flat card primitive used across the app.
///
/// Replaces the former ModernCard / SectionCard / GlassCard variants with one
/// consistent surface: white fill, hairline border, small radius, no shadows.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
    this.radius = AppRadius.card,
    this.accent,
    this.tight = false,
    this.hasGlow = false,
    this.glowColor,
  });

  final Widget? child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final double radius;

  /// Optional left accent bar color (used sparingly for status emphasis).
  final Color? accent;

  /// If true, padding is removed and the child controls its own insets.
  final bool tight;

  /// Optional soft ambient glow for high-priority cards
  final bool hasGlow;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final effectiveGlowColor = glowColor ?? tokens.primary;

    final Widget surface = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hasGlow
            ? AppShadows.glow(effectiveGlowColor, opacity: 0.18, blur: 20)
            : AppShadows.card,
      ),
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: accent ?? tokens.specularBorder,
            width: accent != null ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap != null
            ? InkWell(onTap: onTap, child: _content(tokens))
            : _content(tokens),
      ),
    );

    if (margin == null) return surface;
    return Padding(padding: margin!, child: surface);
  }

  Widget _content(CissThemeTokens tokens) {
    if (tight) return child ?? const SizedBox.shrink();
    return Padding(padding: padding, child: child ?? const SizedBox.shrink());
  }
}
