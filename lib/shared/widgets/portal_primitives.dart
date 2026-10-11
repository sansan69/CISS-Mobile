import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class PortalSurfaceCard extends StatelessWidget {
  const PortalSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.accentColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final resolvedAccent = accentColor ?? tokens.primary;

    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.xs),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color:
              accentColor == null
                  ? tokens.specularBorder
                  : resolvedAccent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                accentColor == null
                    ? tokens.surface
                    : resolvedAccent.withValues(alpha: 0.04),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PortalSectionHeading extends StatelessWidget {
  const PortalSectionHeading({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.inkMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                fontSize: 13,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
