import 'package:flutter/material.dart';

/// Subtle security-grid background painter for login screens.
///
/// Draws a diagonal crosshatch pattern that evokes security mesh or
/// wire fencing — on-brand for a security company without being literal.
/// The grid animates very slowly to give the screen life without
/// distracting from the login form.
class SecurityGridBackground extends StatefulWidget {
  const SecurityGridBackground({
    super.key,
    this.gridColor,
    this.dotColor,
    this.child,
    this.animate = true,
  });

  final Color? gridColor;
  final Color? dotColor;
  final Widget? child;
  final bool animate;

  @override
  State<SecurityGridBackground> createState() => _SecurityGridBackgroundState();
}

class _SecurityGridBackgroundState extends State<SecurityGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    if (widget.animate) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _SecurityGridPainter(
            progress: _ctrl.value,
            isDark: isDark,
            gridColor: widget.gridColor ??
                (isDark
                    ? const Color(0xFF1A2A41).withValues(alpha: 0.5)
                    : const Color(0xFFD9E3EA)),
            dotColor: widget.dotColor ??
                (isDark
                    ? const Color(0xFF7CB8F0).withValues(alpha: 0.15)
                    : const Color(0xFF0B4F82).withValues(alpha: 0.08)),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SecurityGridPainter extends CustomPainter {
  const _SecurityGridPainter({
    required this.progress,
    required this.gridColor,
    required this.dotColor,
    required this.isDark,
  });

  final double progress;
  final Color gridColor;
  final Color dotColor;
  final bool isDark;

  static const double _spacing = 48.0;
  static const double _dotSpacing = _spacing * 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = progress * _spacing;

    // Diagonal crosshatch lines
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.6;

    // Primary diagonal (\)
    for (double x = -size.height; x < size.width + size.height; x += _spacing) {
      final startX = x + offset;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }

    // Secondary diagonal (/)
    for (double x = -size.height; x < size.width + size.height; x += _spacing) {
      final startX = x - offset;
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(startX + size.height, 0),
        paint,
      );
    }

    // Intersection dots
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width + _dotSpacing; x += _dotSpacing) {
      for (double y = 0; y < size.height + _dotSpacing; y += _dotSpacing) {
        final dx = x + offset * 0.3;
        final dy = y + offset * 0.3;
        if (dx < size.width && dy < size.height) {
          canvas.drawCircle(Offset(dx, dy), 2.0, dotPaint);
        }
      }
    }

    // Bottom gradient fade to ensure form readability
    final scaffoldBg = isDark ? const Color(0xFF0B1320) : Colors.white;
    final fadePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.transparent,
          scaffoldBg.withValues(alpha: 0.7),
          scaffoldBg.withValues(alpha: 0.95),
        ],
        stops: const [0.0, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      fadePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SecurityGridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
