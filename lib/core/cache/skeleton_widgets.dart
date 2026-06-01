import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// A shimmer skeleton that mimics a card with a title line and subtitle line.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({
    super.key,
    this.height = 88,
    this.widthFactor = 1.0,
  });

  final double height;
  final double widthFactor;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final shimmer = ColorTween(
      begin: tokens.surfaceMuted,
      end: tokens.surfaceMuted.withValues(alpha: 0.3),
    ).animate(_ctrl);

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        return FractionallySizedBox(
          widthFactor: widget.widthFactor,
          child: Container(
            height: widget.height,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: shimmer.value ?? tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      },
    );
  }
}

/// A shimmer skeleton that mimics the dashboard metric tiles row.
class SkeletonMetricRow extends StatefulWidget {
  const SkeletonMetricRow({super.key});

  @override
  State<SkeletonMetricRow> createState() => _SkeletonMetricRowState();
}

class _SkeletonMetricRowState extends State<SkeletonMetricRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final shimmer = ColorTween(
      begin: tokens.surfaceMuted,
      end: tokens.surfaceMuted.withValues(alpha: 0.3),
    ).animate(_ctrl);

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final color = shimmer.value ?? tokens.surfaceMuted;
        return Row(
          children: [
            Expanded(child: _metricSkeleton(color)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _metricSkeleton(color)),
          ],
        );
      },
    );
  }

  Widget _metricSkeleton(Color color) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}

/// A full-page skeleton that mimics ScreenScaffold with cards.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key, this.cardCount = 4});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CissThemeTokens.of(context).canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Header skeleton
            const SkeletonCard(height: 48, widthFactor: 0.5),
            const SizedBox(height: 16),
            // Metric row skeleton
            const SkeletonMetricRow(),
            const SizedBox(height: 12),
            const SkeletonMetricRow(),
            const SizedBox(height: 16),
            // Card skeletons
            for (int i = 0; i < cardCount; i++) ...[
              const SkeletonCard(),
            ],
          ],
        ),
      ),
    );
  }
}
