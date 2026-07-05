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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color:
              accentColor == null
                  ? tokens.border
                  : resolvedAccent.withValues(alpha: 0.32),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                accentColor == null
                    ? tokens.surface
                    : resolvedAccent.withValues(alpha: 0.035),
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
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.inkMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
