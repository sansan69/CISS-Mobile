import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// A compact donut chart for showing proportional distributions.
///
/// Each [DonutSegment] renders as an arc with [color] and [label].
/// The center shows a total value when [showTotal] is true.
class MiniDonutChart extends StatelessWidget {
  const MiniDonutChart({
    super.key,
    required this.segments,
    this.size = 120,
    this.strokeWidth = 18,
    this.showTotal = true,
    this.totalLabel,
  });

  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
  final bool showTotal;
  final String? totalLabel;

  double get _total =>
      segments.fold<double>(0.0, (sum, s) => sum + s.value);

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    // Filter out zero-value segments
    final activeSegments =
        segments.where((s) => s.value > 0).toList();

    if (activeSegments.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(fontSize: 12, color: tokens.inkMuted),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: activeSegments,
              strokeWidth: strokeWidth,
              total: _total,
            ),
            child: showTotal
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _total % 1 == 0
                              ? '${_total.toInt()}'
                              : _total.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: size * 0.18,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                          ),
                        ),
                        if (totalLabel != null)
                          Text(
                            totalLabel!,
                            style: TextStyle(
                              fontSize: size * 0.09,
                              color: tokens.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: activeSegments.map((s) {
              final pct = _total > 0 ? (s.value / _total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color ?? tokens.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// A single donut segment entry.
class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final double value;
  final Color? color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.total,
  });

  final List<DonutSegment> segments;
  final double strokeWidth;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -math.pi / 2; // Start from top

    for (final segment in segments) {
      final sweepAngle = total > 0
          ? (segment.value / total) * math.pi * 2
          : 0.0;

      final paint = Paint()
        ..color = segment.color ?? Colors.blue
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.total != total ||
      oldDelegate.strokeWidth != strokeWidth;
}
