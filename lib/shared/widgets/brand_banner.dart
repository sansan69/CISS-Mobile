import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/brand.dart';

/// Unified header banner used on screens that don't use ScreenScaffold.
///
/// Visually identical to ScreenScaffold's AppBar: logo, company name, and
/// screen context title. Use this inside a Scaffold body when you need the
/// header inline rather than in an AppBar (e.g. when the header should scroll
/// with the content).
///
/// [title] and [subtitle] identify the current screen for the user.
/// [trailing] optional widget displayed to the right of the title.
class BrandBanner extends StatelessWidget {
  const BrandBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBackButton = false,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border(bottom: BorderSide(color: tokens.border)),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Back button
            if (showBackButton) ...<Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: onBack ?? () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(foregroundColor: tokens.ink),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
            ],

            const CissLogoBadge(),
            const SizedBox(width: AppSpacing.sm),

            // Title block
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Company name — always visible
                  Text(
                    kCompanyName.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.primaryStrong,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Screen title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.inkMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Trailing widget
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The CISS logo treatment shared by every branded header.
class CissLogoBadge extends StatelessWidget {
  const CissLogoBadge({super.key, this.inverse = false, this.size = 44});

  final bool inverse;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final padding = size <= 36 ? 5.0 : 7.0;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color:
            inverse ? Colors.white.withValues(alpha: 0.14) : tokens.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: inverse ? Colors.white.withValues(alpha: 0.18) : tokens.border,
        ),
      ),
      child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
    );
  }
}

/// Compact logo + company-name lockup for hero surfaces.
class CissBrandMark extends StatelessWidget {
  const CissBrandMark({super.key, this.inverse = false, this.compact = false});

  final bool inverse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color =
        inverse ? Colors.white : CissThemeTokens.of(context).primaryStrong;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CissLogoBadge(inverse: inverse, size: compact ? 36 : 44),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            kCompanyName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? 1.0 : 1.3,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Branded AppBar for detail pages that are not using [ScreenScaffold].
class CissAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CissAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showBackButton = true,
    this.onBack,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  double get _toolbarHeight => subtitle == null ? 72 : 84;

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0) + 1);

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final bottomContent = _CissAppBarBottom(content: bottom, tokens: tokens);

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: _toolbarHeight,
      leading:
          showBackButton
              ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: onBack ?? () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(foregroundColor: tokens.ink),
              )
              : null,
      title: Padding(
        padding: EdgeInsets.fromLTRB(showBackButton ? 4 : 16, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const CissLogoBadge(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    kCompanyName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.primaryStrong,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: subtitle == null ? 17 : 15,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.inkMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[...actions, const SizedBox(width: AppSpacing.xs)],
      bottom: bottomContent,
    );
  }
}

class _CissAppBarBottom extends StatelessWidget implements PreferredSizeWidget {
  const _CissAppBarBottom({required this.content, required this.tokens});

  final PreferredSizeWidget? content;
  final CissThemeTokens tokens;

  @override
  Size get preferredSize =>
      Size.fromHeight((content?.preferredSize.height ?? 0) + 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (content != null) content!,
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
            boxShadow: AppShadows.subtle,
          ),
          child: const SizedBox(height: 1, width: double.infinity),
        ),
      ],
    );
  }
}
