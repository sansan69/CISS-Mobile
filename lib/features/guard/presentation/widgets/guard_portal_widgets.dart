import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/ciss_error.dart';
import '../../../../shared/widgets/portal_primitives.dart';
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
            ),
          ],
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

class GuardFormCard extends StatelessWidget {
  const GuardFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return PortalSurfaceCard(
      accentColor: tokens.primary,
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
    final currentChip = chip;
    final currentTrailing = trailing;

    final content = PortalSurfaceCard(
      accentColor: tokens.primary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: tokens.primaryStrong, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
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
            if (currentTrailing case final Widget trailing) trailing,
          ],
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
