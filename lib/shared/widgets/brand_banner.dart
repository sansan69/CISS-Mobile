import 'package:flutter/material.dart';

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
    required this.subtitle,
    this.trailing,
    this.showBackButton = false,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(color: tokens.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Back button
          if (showBackButton) ...<Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                foregroundColor: tokens.ink,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Brand logo
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 11),

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
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.1,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
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
    );
  }
}
