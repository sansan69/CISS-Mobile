import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_tokens.dart';

class PortalSurfaceCard extends StatelessWidget {
  const PortalSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.accentColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            tokens.surface,
            tokens.surfaceMuted,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: accentColor?.withValues(alpha: 0.22) ?? tokens.border,
        ),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: card,
      ),
    );
  }
}

class PortalSectionHeading extends StatelessWidget {
  const PortalSectionHeading({
    super.key,
    required this.title,
    this.action,
    this.compact = false,
  });

  final String title;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.roboto(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? 1.4 : 1.8,
              color: tokens.inkMuted,
              height: 1,
            ),
          ),
        ),
        if (action case final Widget actionWidget) actionWidget,
      ],
    );
  }
}

class PortalFieldLabel extends StatelessWidget {
  const PortalFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: tokens.inkMuted,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
