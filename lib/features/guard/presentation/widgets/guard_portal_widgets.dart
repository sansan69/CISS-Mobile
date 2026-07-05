import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/ciss_error.dart';
import '../../../../shared/widgets/state_block.dart';
import '../../../../shared/widgets/status_chip.dart';

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
              GuardHeroPanel(
                eyebrow: 'Loading',
                title: label,
                subtitle: 'Preparing your guard workspace.',
                icon: Icons.sync_rounded,
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
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: tokens.border.withValues(alpha: 0.55),
                      ),
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
        borderRadius: BorderRadius.circular(AppRadius.lg + 6),
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

class GuardMetricStrip extends StatelessWidget {
  const GuardMetricStrip({super.key, required this.items});

  final List<GuardMetricItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0)
              Container(
                height: 42,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: tokens.border.withValues(alpha: 0.7),
              ),
            Expanded(child: _GuardMetricCell(item: items[index])),
          ],
        ],
      ),
    );
  }
}

class _GuardMetricCell extends StatelessWidget {
  const _GuardMetricCell({required this.item});

  final GuardMetricItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(item.icon, size: 15, color: item.color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                item.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          item.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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

class GuardFormCard extends StatelessWidget {
  const GuardFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border.withValues(alpha: 0.75)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.ink.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
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
    final currentChip = chip;
    final currentTrailing = trailing;

    final content = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: tokens.primaryStrong, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
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
          if (currentChip != null || currentTrailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            if (currentChip case final Widget chip) chip,
            if (currentChip != null && currentTrailing != null)
              const SizedBox(width: AppSpacing.xs),
            if (currentTrailing case final Widget trailing) trailing,
          ] else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: content,
    );
  }
}
