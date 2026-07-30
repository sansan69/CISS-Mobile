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

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border, width: 1),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.inkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: tokens.ink,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
