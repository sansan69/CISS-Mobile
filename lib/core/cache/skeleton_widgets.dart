import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Animated shimmer loading placeholder.
///
/// Renders animated shimmer cards instead of a static spinner or empty boxes.
/// Use [cardCount] to control how many placeholder rows to show.
class SkeletonPage extends StatefulWidget {
  const SkeletonPage({super.key, this.cardCount = 4});
  final int cardCount;

  @override
  State<SkeletonPage> createState() => _SkeletonPageState();
}

class _SkeletonPageState extends State<SkeletonPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: widget.cardCount,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ShimmerCard(
              animation: _controller,
              tokens: tokens,
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.animation, required this.tokens});
  final Animation<double> animation;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.border.withValues(alpha: 0.3),
            tokens.border.withValues(alpha: 0.15),
            tokens.border.withValues(alpha: 0.3),
          ],
          stops: [
            animation.value - 0.3,
            animation.value,
            animation.value + 0.3,
          ].map((v) => v.clamp(0.0, 1.0)).toList(),
        ),
      ),
    );
  }
}
