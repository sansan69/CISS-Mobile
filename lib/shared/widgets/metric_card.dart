import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.backgroundColor,
    this.width,
  });

  final String label;
  final String value;
  final Color? color;
  final Color? backgroundColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final effectiveColor = color ?? tokens.primary;
    final effectiveBackground =
        backgroundColor ?? effectiveColor.withValues(alpha: 0.1);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: tokens.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: effectiveColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
