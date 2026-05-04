import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/brand.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class LoginHubScreen extends StatefulWidget {
  const LoginHubScreen({super.key});

  @override
  State<LoginHubScreen> createState() => _LoginHubScreenState();
}

class _LoginHubScreenState extends State<LoginHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(double from, double to) => CurvedAnimation(
    parent: _ctrl,
    curve: Interval(from, to, curve: Curves.easeOut),
  );

  Animation<Offset> _slide(double from, double to) =>
      Tween<Offset>(begin: const Offset(0, 0.055), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(from, to, curve: Curves.easeOutCubic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Brand mark — high prominence identity
                FadeTransition(
                  opacity: _fade(0.0, 0.5),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 20),
                        Container(
                          width: 88,
                          height: 88,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: tokens.primary.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          kCompanyName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: tokens.primary,
                            letterSpacing: 3,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          kCompanyTagline,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.inkMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                FadeTransition(
                  opacity: _fade(0.08, 0.55),
                  child: SlideTransition(
                    position: _slide(0.08, 0.65),
                    child: Center(
                      child: Text(
                        'Select your portal',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Guard portal
                SizedBox(
                  height: 230,
                  child: FadeTransition(
                    opacity: _fade(0.12, 0.65),
                    child: SlideTransition(
                      position: _slide(0.12, 0.75),
                      child: _RoleCard(
                        title: 'GUARD\nOPERATIONS',
                        tagline: 'Attendance  ·  Shifts  ·  Duty reports',
                        icon: Icons.verified_user_rounded,
                        accentColor: tokens.primary,
                        softColor: tokens.primarySoft,
                        infographic: _InfographicType.guard,
                        introDelay: const Duration(milliseconds: 360),
                        onTap: () => context.go('/login/guard'),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Field command portal
                SizedBox(
                  height: 230,
                  child: FadeTransition(
                    opacity: _fade(0.22, 0.75),
                    child: SlideTransition(
                      position: _slide(0.22, 0.85),
                      child: _RoleCard(
                        title: 'FIELD\nCOMMAND',
                        tagline: 'Districts  ·  Work orders  ·  Reports',
                        icon: Icons.admin_panel_settings_rounded,
                        accentColor: tokens.accent,
                        softColor: tokens.warningSoft,
                        infographic: _InfographicType.field,
                        introDelay: const Duration(milliseconds: 490),
                        onTap: () => context.go('/login/field-officer'),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                FadeTransition(
                  opacity: _fade(0.5, 1.0),
                  child: Center(
                    child: Text(
                      '© 2026 $kCompanyName · Secured',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.inkMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _InfographicType { guard, field }

// ─────────────────────────────────────────────────────────────────────────────
// Role card
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.tagline,
    required this.icon,
    required this.accentColor,
    required this.softColor,
    required this.infographic,
    required this.introDelay,
    required this.onTap,
  });

  final String title;
  final String tagline;
  final IconData icon;
  final Color accentColor;
  final Color softColor;
  final _InfographicType infographic;
  final Duration introDelay;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _introCtrl;
  late final Animation<double> _introAnim;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _introAnim = CurvedAnimation(
      parent: _introCtrl,
      curve: Curves.easeInOut,
    );
    // Stagger the infographic entrance after the card's own fade-in
    Future.delayed(widget.introDelay, () {
      if (mounted) _introCtrl.forward();
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.974 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _pressed
                      ? widget.accentColor.withValues(alpha: 0.5)
                      : tokens.border.withValues(alpha: 0.5),
                ),
                boxShadow: _pressed ? const <BoxShadow>[] : AppShadows.card,
              ),
              child: Stack(
                children: <Widget>[
                  // Role-colour stripe at top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 4,
                    child: ColoredBox(
                      color: widget.accentColor.withValues(alpha: 0.55),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Icon — top-left
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: widget.softColor,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 23,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Infographic — fills the flex space between icon & text
                        Expanded(
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _introAnim,
                              builder: (context, _) {
                                return widget.infographic == _InfographicType.guard
                                    ? CustomPaint(
                                        painter: _AttendancePainter(
                                          color: widget.accentColor,
                                          progress: _introAnim.value,
                                        ),
                                        size: const Size(92, 66),
                                      )
                                    : CustomPaint(
                                        painter: _NetworkPainter(
                                          color: widget.accentColor,
                                          progress: _introAnim.value,
                                        ),
                                        size: const Size(92, 80),
                                      );
                              },
                            ),
                          ),
                        ),

                        // Role name in display font
                        Text(
                          widget.title,
                          style: GoogleFonts.rajdhani(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                            height: 0.95,
                            letterSpacing: 0.4,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          widget.tagline,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.inkMuted,
                            letterSpacing: 0.1,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // CTA row
                        Row(
                          children: <Widget>[
                            Text(
                              'Enter portal',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: widget.accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: widget.accentColor,
                              size: 14,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guard infographic — attendance dot grid
//
// 5 columns (Mon–Fri) × 4 rows (weeks) = 20 dots.
// Each dot fills in with a staggered easeOutBack pop.
// Present = filled, absent = hollow ring, future = ghost.
// "Today" gets an outer pulse ring.
// ─────────────────────────────────────────────────────────────────────────────

class _AttendancePainter extends CustomPainter {
  const _AttendancePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  static const int _cols = 5;
  static const int _rows = 4;
  static const int _total = _cols * _rows;
  static const double _dotR = 4.6;
  static const double _colGap = 16.0;
  static const double _rowGap = 16.0;

  // Dot classification by index (row * 5 + col)
  static const Set<int> _present = {
    0, 1, 2,       // week 1: Mon Tue Wed
    5, 6, 7,       // week 2: Mon Tue Wed
    9,             // week 2: Fri
    10, 11, 12,    // week 3: Mon Tue Wed
    14,            // week 3: Fri
    15, 16,        // week 4: Mon Tue  ← most recent (today = 16)
  };
  static const Set<int> _absent = {3, 8};      // Thu of week 1 & 2
  // rest are "future" dots

  // "Today" is the last present dot: index 16 → row 3, col 1
  static const int _todayIdx = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final totalW = (_cols - 1) * _colGap;
    final totalH = (_rows - 1) * _rowGap;
    final ox = (size.width - totalW) / 2;
    final oy = (size.height - totalH) / 2;

    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final idx = r * _cols + c;
        final x = ox + c * _colGap;
        final y = oy + r * _rowGap;

        // Each dot has its own progress threshold for a stagger effect
        final threshold = (idx / (_total - 1)) * 0.72;
        if (progress <= threshold) continue;

        final dotP = ((progress - threshold) / 0.28).clamp(0.0, 1.0);

        if (_present.contains(idx)) {
          final scl = Curves.easeOutBack.transform(dotP).clamp(0.0, 1.25);
          canvas.drawCircle(
            Offset(x, y),
            _dotR * scl,
            Paint()..color = color.withValues(alpha: dotP * 0.88),
          );
        } else if (_absent.contains(idx)) {
          canvas.drawCircle(
            Offset(x, y),
            _dotR * 0.82,
            Paint()
              ..color = color.withValues(alpha: dotP * 0.14)
              ..style = PaintingStyle.fill,
          );
          canvas.drawCircle(
            Offset(x, y),
            _dotR * 0.82,
            Paint()
              ..color = color.withValues(alpha: dotP * 0.38)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9,
          );
        } else {
          // future
          canvas.drawCircle(
            Offset(x, y),
            _dotR * 0.65,
            Paint()
              ..color = color.withValues(alpha: dotP * 0.1)
              ..style = PaintingStyle.fill,
          );
        }
      }
    }

    // "Today" pulse ring — appears after the grid is mostly filled
    if (progress > 0.86) {
      final ringP = ((progress - 0.86) / 0.14).clamp(0.0, 1.0);
      final todayC = _todayIdx % _cols;
      final todayR = _todayIdx ~/ _cols;
      canvas.drawCircle(
        Offset(ox + todayC * _colGap, oy + todayR * _rowGap),
        _dotR + 3.8,
        Paint()
          ..color = color.withValues(alpha: ringP * 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_AttendancePainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Field command infographic — hub-and-spoke network
//
// Central command node + 6 guard/site nodes arranged in a hexagon.
// Animation phases:
//   Phase 1 (0.00 → 0.50): spokes draw outward from centre
//   Phase 2 (0.30 → 0.90): guard nodes pop in with stagger
//   Phase 3 (0.52 → 0.85): centre command node fills in
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  // (angleDeg, orbitalRadius, isActive)
  static const List<(double, double, bool)> _nodes = [
    (-90, 32, true),    // top
    (-30, 36, true),    // upper-right
    (30, 33, false),    // lower-right
    (90, 34, true),     // bottom
    (150, 36, false),   // lower-left
    (210, 32, true),    // upper-left
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 2;

    // ── Phase 1: spokes ──────────────────────────────────────────────────────
    final lineP = (progress / 0.5).clamp(0.0, 1.0);

    for (int i = 0; i < _nodes.length; i++) {
      final (angleDeg, radius, _) = _nodes[i];
      final rad = angleDeg * math.pi / 180;
      final nx = cx + radius * math.cos(rad);
      final ny = cy + radius * math.sin(rad);

      // Each spoke reveals with its own micro-stagger
      final spokeFrac =
          ((lineP - i / _nodes.length * 0.35) / 0.65).clamp(0.0, 1.0);
      if (spokeFrac <= 0) continue;

      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + (nx - cx) * spokeFrac, cy + (ny - cy) * spokeFrac),
        Paint()
          ..color = color.withValues(alpha: spokeFrac * 0.2)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Phase 2: guard/site nodes ────────────────────────────────────────────
    final nodeP = ((progress - 0.30) / 0.60).clamp(0.0, 1.0);

    for (int i = 0; i < _nodes.length; i++) {
      final (angleDeg, radius, isActive) = _nodes[i];
      final rad = angleDeg * math.pi / 180;
      final nx = cx + radius * math.cos(rad);
      final ny = cy + radius * math.sin(rad);

      final nodeFrac =
          ((nodeP - i / _nodes.length * 0.50) / 0.50).clamp(0.0, 1.0);
      if (nodeFrac <= 0) continue;

      final scl = Curves.easeOutBack.transform(nodeFrac).clamp(0.0, 1.25);

      if (isActive) {
        canvas.drawCircle(
          Offset(nx, ny),
          5.2 * scl,
          Paint()..color = color.withValues(alpha: 0.82 * nodeFrac),
        );
      } else {
        canvas.drawCircle(
          Offset(nx, ny),
          4.6,
          Paint()
            ..color = color.withValues(alpha: 0.14 * nodeFrac)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(nx, ny),
          4.6,
          Paint()
            ..color = color.withValues(alpha: 0.42 * nodeFrac)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    // ── Phase 3: central command node ────────────────────────────────────────
    final centerP = ((progress - 0.52) / 0.33).clamp(0.0, 1.0);
    if (centerP > 0) {
      final scl = Curves.easeOutBack.transform(centerP).clamp(0.0, 1.25);
      // Outer filled circle
      canvas.drawCircle(
        Offset(cx, cy),
        9.0 * scl,
        Paint()..color = color.withValues(alpha: centerP),
      );
      // Inner white dot (command symbol)
      canvas.drawCircle(
        Offset(cx, cy),
        4.2 * scl,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.38 * centerP)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_NetworkPainter old) =>
      old.progress != progress || old.color != color;
}
