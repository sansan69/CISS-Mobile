import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/ciss_error.dart';
import '../../../../shared/widgets/state_block.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/modern_hero.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../shared/widgets/modern_card.dart';

String guardErrorMessage(Object error) {
  return CissError.parse(error);
}

class GuardLoadingScaffold extends StatelessWidget {
  const GuardLoadingScaffold({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ModernHero(
                eyebrow: 'Loading',
                title: 'Guard Portal',
                subtitle: 'Preparing your workspace...',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    height: index == 0 ? 132 : 84,
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: tokens.border),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GuardErrorScaffold extends StatelessWidget {
  const GuardErrorScaffold({
    super.key,
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: StateBlock(
              icon: Icons.cloud_off_rounded,
              title: title,
              message: guardErrorMessage(error),
              action: FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GuardHeroPanel extends StatelessWidget {
  const GuardHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.accentColor,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final accent = accentColor ?? tokens.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.primaryStrong,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.primaryStrong.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -22,
            top: -28,
            child: Icon(
              icon,
              size: 112,
              color: Colors.white.withValues(alpha: 0.055),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 23),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GuardFormCard extends StatelessWidget {
  const GuardFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class GuardRecordCard extends StatelessWidget {
  const GuardRecordCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.chip,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final StatusChip? chip;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return ModernCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tokens.primaryStrong, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tokens.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.inkMuted,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          if (chip != null) ...[
            const SizedBox(width: AppSpacing.sm),
            chip!,
          ],
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class GuardMetricStrip extends StatelessWidget {
  const GuardMetricStrip({super.key, required this.items});

  final List<GuardMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            return Padding(
              padding: EdgeInsets.only(
                left: items.indexOf(item) == 0 ? 0 : AppSpacing.sm,
              ),
              child: MetricCard(
                label: item.label,
                value: item.value,
                color: item.color,
                width: 120,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class GuardMetricItem {
  const GuardMetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
