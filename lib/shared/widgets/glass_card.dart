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
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  tokens.surface.withValues(alpha: 0.82),
                  tokens.surfaceMuted.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: accentColor?.withValues(alpha: 0.28) ??
                    tokens.border.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (accentColor ?? tokens.primaryStrong).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -10,
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
