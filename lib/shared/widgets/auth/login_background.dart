import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

/// Subtle security-grid background painter for login screens.
///
/// Draws a diagonal crosshatch pattern that evokes security mesh or
/// wire fencing — on-brand for a security company without being literal.
/// Rendered as a static texture; motion-sensitive users and low-end
/// devices are not forced to repaint a full-screen pattern every frame.
class SecurityGridBackground extends StatelessWidget {
  const SecurityGridBackground({
    super.key,
    this.gridColor,
    this.dotColor,
    this.child,
  });

  final Color? gridColor;
  final Color? dotColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomPaint(
      painter: _SecurityGridPainter(
        isDark: isDark,
        scaffoldBg: tokens.canvas,
        gridColor: gridColor ??
            (isDark
                ? const Color(0xFF1A2A41).withValues(alpha: 0.25)
                : const Color(0xFFD9E3EA).withValues(alpha: 0.6)),
        dotColor: dotColor ??
            (isDark
                ? const Color(0xFF7CB8F0).withValues(alpha: 0.08)
                : const Color(0xFF0B4F82).withValues(alpha: 0.04)),
      ),
      child: child,
    );
  }
}

class _SecurityGridPainter extends CustomPainter {
  const _SecurityGridPainter({
    required this.gridColor,
    required this.dotColor,
    required this.isDark,
    required this.scaffoldBg,
  });

  final Color gridColor;
  final Color dotColor;
  final bool isDark;
  final Color scaffoldBg;

  static const double _spacing = 48.0;
  static const double _dotSpacing = _spacing * 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    // Diagonal crosshatch lines
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.6;

    // Primary diagonal (\)
    for (double x = -size.height; x < size.width + size.height; x += _spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }

    // Secondary diagonal (/)
    for (double x = -size.height; x < size.width + size.height; x += _spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }

    // Intersection dots
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width + _dotSpacing; x += _dotSpacing) {
      for (double y = 0; y < size.height + _dotSpacing; y += _dotSpacing) {
        if (x < size.width && y < size.height) {
          canvas.drawCircle(Offset(x, y), 2.0, dotPaint);
        }
      }
    }

    // Bottom gradient fade to ensure form readability
    final fadePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.transparent,
          scaffoldBg.withValues(alpha: 0.7),
          scaffoldBg.withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.45, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      fadePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SecurityGridPainter oldDelegate) => false;
}
