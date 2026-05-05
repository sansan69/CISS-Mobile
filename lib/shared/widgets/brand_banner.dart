import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/brand.dart';

/// Full-bleed brand header used on auth and onboarding screens.
///
/// Company identity (logo + name + tagline) sits at the top as the primary
/// statement. The screen-specific [title] and [subtitle] appear below a
/// hairline divider as supporting context.
class BrandBanner extends StatelessWidget {
  const BrandBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            isDark
                ? const Color(0xFF0A1F3A)
                : tokens.primaryStrong,
            isDark
                ? const Color(0xFF061428)
                : const Color(0xFF062D52),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Company identity ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Logo — larger, on a frosted circle background
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      kCompanyName.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tokens.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      kCompanyTagline,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                        height: 1.3,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Hairline divider — separates brand from screen context
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Screen context ───────────────────────────────────────────────
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.4,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
