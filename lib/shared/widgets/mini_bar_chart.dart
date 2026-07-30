import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// A simple horizontal bar chart for showing proportional values.
///
/// Each [MiniBarItem] renders as a labeled row with a filled bar whose width
/// is proportional to [value] / [maxValue]. Bars use [color] with a soft
/// background fill.
///
/// Useful for dashboard infographics like "Daily attendance per client."
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.items,
    this.maxValue,
    this.barHeight = 20,
    this.barRadius = 4,
    this.showValues = true,
    this.animate = false,
  });

  final List<MiniBarItem> items;
  final double? maxValue;
  final double barHeight;
  final double barRadius;
  final bool showValues;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final effectiveMax = maxValue ??
        items.fold<double>(0.0, (m, i) => m > i.value ? m : i.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final fraction =
            effectiveMax > 0 ? (item.value / effectiveMax).clamp(0.0, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                  if (showValues)
                    Text(
                      '${item.value}${item.suffix ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.inkMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(barRadius),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: barHeight,
                  backgroundColor: item.barBackgroundColor ??
                      tokens.surfaceMuted,
                  color: item.color ?? tokens.primary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// A single bar entry in [MiniBarChart].
class MiniBarItem {
  const MiniBarItem({
    required this.label,
    required this.value,
    this.color,
    this.barBackgroundColor,
    this.suffix,
  });

  final String label;
  final double value;
  final Color? color;
  final Color? barBackgroundColor;
  final String? suffix;
}
