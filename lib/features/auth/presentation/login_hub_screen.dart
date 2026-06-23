import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/brand.dart';
import '../../../shared/widgets/auth/login_background.dart';

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
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(double from, double to) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(from, to, curve: Curves.easeOutCubic),
      );

  Animation<Offset> _slide(double from, double to) =>
      Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(from, to, curve: Curves.easeOutCubic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final mediaHeight = MediaQuery.of(context).size.height;

    // Determine responsive sizing
    final bool isCompact = mediaHeight < 700;
    final bool isShort = mediaHeight < 800;
    final double logoSize = isCompact ? 52 : (isShort ? 64 : 80);
    final double logoPadding = isCompact ? 12 : 16;
    final double brandTopPadding = isCompact ? 16.0 : (isShort ? 24.0 : 40.0);
    final double titleFontSize = isCompact ? 22.0 : (isShort ? 26.0 : 32.0);
    final double titleLetterSpacing = isCompact ? 2.0 : (isShort ? 2.8 : 3.5);
    final double labelTopPadding = isCompact ? 14.0 : (isShort ? 20.0 : 36.0);
    final double cardGap = isCompact ? 8.0 : (isShort ? 10.0 : 14.0);
    final double horizontalPadding = isCompact ? 14.0 : 20.0;

    return Scaffold(
      body: SecurityGridBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // ── Brand mark ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, brandTopPadding, horizontalPadding, 0),
                child: FadeTransition(
                  opacity: _fade(0.0, 0.4),
                  child: SlideTransition(
                    position: _slide(0.0, 0.4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: logoSize,
                          height: logoSize,
                          padding: EdgeInsets.all(logoPadding),
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: tokens.primary.withValues(alpha: 0.18),
                                blurRadius: 32,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            kCompanyLogoAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: isCompact ? 8 : 16),
                        Text(
                          kCompanyName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w800,
                            color: tokens.primary,
                            letterSpacing: titleLetterSpacing,
                            height: 1,
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 6),
                          Text(
                            kCompanyTagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: tokens.inkMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Portal selector label ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, labelTopPadding, horizontalPadding, 0),
                child: FadeTransition(
                  opacity: _fade(0.1, 0.5),
                  child: SlideTransition(
                    position: _slide(0.1, 0.5),
                    child: Text(
                      'SELECT YOUR PORTAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCompact ? 10 : 12,
                        fontWeight: FontWeight.w800,
                        color: tokens.inkMuted,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Role cards (fill remaining space) ──
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: <Widget>[
                      const Spacer(flex: 1),
                      Expanded(
                        flex: isCompact ? 9 : 10,
                        child: Padding(
                          padding: EdgeInsets.only(top: cardGap + 4),
                          child: FadeTransition(
                            opacity: _fade(0.15, 0.6),
                            child: SlideTransition(
                              position: _slide(0.15, 0.65),
                              child: _RoleCard(
                                title: isCompact
                                    ? 'GUARD OPERATIONS'
                                    : 'GUARD\nOPERATIONS',
                                tagline: isCompact
                                    ? 'Attendance · Shifts · Duty reports'
                                    : 'Attendance  ·  Shifts  ·  Duty reports',
                                icon: Icons.verified_user_rounded,
                                accentColor: tokens.primary,
                                softColor: tokens.primarySoft,
                                darkSoftColor:
                                    tokens.primary.withValues(alpha: 0.12),
                                infographic: _InfographicType.guard,
                                introDelay: const Duration(milliseconds: 360),
                                compact: isCompact,
                                onTap: () => context.go('/login/guard'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: cardGap),
                      Expanded(
                        flex: isCompact ? 9 : 10,
                        child: FadeTransition(
                          opacity: _fade(0.25, 0.7),
                          child: SlideTransition(
                            position: _slide(0.25, 0.75),
                            child: _RoleCard(
                              title: isCompact
                                  ? 'FIELD COMMAND'
                                  : 'FIELD\nCOMMAND',
                              tagline: isCompact
                                  ? 'Districts · Work orders · Reports'
                                  : 'Districts  ·  Work orders  ·  Reports',
                              icon: Icons.admin_panel_settings_rounded,
                              accentColor: tokens.accent,
                              softColor: tokens.accent.withValues(alpha: 0.1),
                              darkSoftColor:
                                  tokens.accent.withValues(alpha: 0.12),
                              infographic: _InfographicType.field,
                              introDelay: const Duration(milliseconds: 490),
                              compact: isCompact,
                              showPortalButton: false,
                              onTap: () => context.go('/login/field-officer'),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),

              // ── Footer ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 0, horizontalPadding, isCompact ? 8 : 20),
                child: FadeTransition(
                  opacity: _fade(0.5, 1.0),
                  child: Text(
                    '© 2026 $kCompanyName · Secured by CISS Core',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.inkMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
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
    required this.darkSoftColor,
    required this.infographic,
    required this.introDelay,
    required this.onTap,
    this.compact = false,
    this.showPortalButton = true,
  });

  final String title;
  final String tagline;
  final IconData icon;
  final Color accentColor;
  final Color softColor;
  final Color darkSoftColor;
  final _InfographicType infographic;
  final Duration introDelay;
  final VoidCallback onTap;
  final bool compact;
  final bool showPortalButton;

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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = constraints.maxHeight;
            final bool veryTight = cardHeight < 130;
            final bool tight = cardHeight < 160;
            final double iconSize = tight ? 36 : (widget.compact ? 42 : 50);
            final double iconRadius = tight ? 10 : (widget.compact ? 12 : 14);
            final double titleSize = veryTight ? 18 : (tight ? 22 : (widget.compact ? 28 : 36));
            final double infographicHeight = tight ? (cardHeight * 0.12) : (cardHeight * 0.15);
            final double contentPadH = tight ? 14.0 : (widget.compact ? 18.0 : 22.0);
            final double contentPadV = tight ? 10.0 : (widget.compact ? 14.0 : 20.0);

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _pressed
                      ? widget.accentColor.withValues(alpha: 0.5)
                      : tokens.border.withValues(alpha: 0.6),
                  width: _pressed ? 1.5 : 1,
                ),
                boxShadow: _pressed
                    ? const <BoxShadow>[]
                    : <BoxShadow>[
                        BoxShadow(
                          color: tokens.ink.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                          spreadRadius: -2,
                        ),
                      ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: <Widget>[
                  // Top accent bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.accentColor.withValues(alpha: 0.8),
                            widget.accentColor.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Background pattern
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 140,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            widget.darkSoftColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        contentPadH, contentPadV, contentPadH, contentPadV),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Icon
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: widget.softColor,
                            borderRadius: BorderRadius.circular(iconRadius),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: iconSize * 0.52,
                          ),
                        ),
                        // Infographic
                        if (!veryTight)
                          Expanded(
                            child: Center(
                              child: AnimatedBuilder(
                                animation: _introAnim,
                                builder: (context, _) {
                                  return widget.infographic ==
                                          _InfographicType.guard
                                      ? CustomPaint(
                                          painter: _AttendancePainter(
                                            color: widget.accentColor,
                                            progress: _introAnim.value,
                                          ),
                                          size: Size(
                                            100,
                                            infographicHeight.clamp(16, 72),
                                          ),
                                        )
                                      : CustomPaint(
                                          painter: _NetworkPainter(
                                            color: widget.accentColor,
                                            progress: _introAnim.value,
                                          ),
                                          size: Size(
                                            100,
                                            infographicHeight.clamp(16, 88),
                                          ),
                                        );
                                },
                              ),
                            ),
                          ),
                        // Title
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                            height: 0.95,
                            letterSpacing: 0.4,
                          ),
                        ),
                        SizedBox(height: tight ? 4 : 8),
                        // Tagline
                        if (!veryTight)
                          Text(
                            widget.tagline,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: tokens.inkMuted,
                                  letterSpacing: 0.1,
                                ),
                          ),
                        SizedBox(height: tight ? 8 : 16),
                        // CTA button
                        if (widget.showPortalButton)
                        Row(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: tight ? 10 : 14,
                                vertical: tight ? 5 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: widget.softColor,
                                borderRadius:
                                    BorderRadius.circular(tight ? 8 : 10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Enter portal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: widget.accentColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: tight ? 11 : null,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: widget.accentColor,
                                    size: tight ? 14 : 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guard infographic — attendance dot grid
// ─────────────────────────────────────────────────────────────────────────────

class _AttendancePainter extends CustomPainter {
  const _AttendancePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  static const int _cols = 5;
  static const int _rows = 4;
  static const int _total = _cols * _rows;
  static const double _dotR = 4.8;
  static const double _colGap = 17.0;
  static const double _rowGap = 17.0;

  static const Set<int> _present = {
    0, 1, 2, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16,
  };
  static const Set<int> _absent = {3, 8};
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
          canvas.drawCircle(
            Offset(x, y),
            _dotR * 0.65,
            Paint()
              ..color = color.withValues(alpha: dotP * 0.1)
              ..style = PaintingStyle.fill,
          );
        }

        // Today pulse
        if (idx == _todayIdx && dotP >= 0.85) {
          final pulse = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(x, y),
            _dotR * (1.0 + pulse * 0.5),
            Paint()
              ..color = color.withValues(alpha: (1.0 - pulse) * 0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AttendancePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Field infographic — node network
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  static const List<Offset> _nodes = [
    Offset(26, 50),
    Offset(62, 20),
    Offset(34, 8),
    Offset(56, 40),
    Offset(12, 30),
    Offset(78, 48),
    Offset(44, 62),
    Offset(68, 72),
  ];

  static const List<({int from, int to})> _edges = [
    (from: 0, to: 1),
    (from: 1, to: 3),
    (from: 0, to: 4),
    (from: 4, to: 2),
    (from: 2, to: 1),
    (from: 3, to: 6),
    (from: 6, to: 7),
    (from: 1, to: 5),
    (from: 5, to: 7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final total = (_edges.length + _nodes.length).toDouble();

    for (int i = 0; i < _edges.length; i++) {
      final edgeP = ((i.toDouble() / total) + progress * 0.6).clamp(0.0, 1.0);
      final edge = _edges[i];
      canvas.drawLine(
        _nodes[edge.from],
        _nodes[edge.to],
        Paint()
          ..color = color.withValues(alpha: edgeP * 0.2)
          ..strokeWidth = 1.2,
      );
    }

    for (int i = 0; i < _nodes.length; i++) {
      final nodeP =
          (((_edges.length + i).toDouble() / total) + progress * 0.4)
              .clamp(0.0, 1.0);
      final r = 3.5 * Curves.easeOutBack.transform(nodeP).clamp(0.0, 1.4);
      canvas.drawCircle(
        _nodes[i],
        r,
        Paint()..color = color.withValues(alpha: nodeP * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
