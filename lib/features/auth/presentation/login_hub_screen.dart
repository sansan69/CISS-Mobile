import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/brand.dart';
import '../../../core/haptics.dart';
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
      duration: const Duration(milliseconds: 900),
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
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
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

    final bool isCompact = mediaHeight < 680;
    final bool isShort = mediaHeight < 780;
    final double logoSize = isCompact ? 48 : (isShort ? 56 : 72);
    final double titleFontSize = isCompact ? 20.0 : (isShort ? 24.0 : 28.0);
    final double cardGap = isCompact ? 12.0 : 16.0;
    final double horizontalPadding = isCompact ? 16.0 : 24.0;
    final double brandTopPadding = isCompact ? 12.0 : (isShort ? 20.0 : 32.0);

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
                  opacity: _fade(0.0, 0.35),
                  child: SlideTransition(
                    position: _slide(0.0, 0.35),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: logoSize,
                          height: logoSize,
                          padding: EdgeInsets.all(logoSize * 0.22),
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: tokens.primary.withValues(alpha: 0.15),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            kCompanyLogoAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          kCompanyName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w800,
                            color: tokens.primary,
                            letterSpacing: 2.8,
                            height: 1,
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 4),
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
                padding: EdgeInsets.fromLTRB(horizontalPadding,
                    isCompact ? 16 : 24, horizontalPadding, isCompact ? 6 : 10),
                child: FadeTransition(
                  opacity: _fade(0.1, 0.45),
                  child: SlideTransition(
                    position: _slide(0.1, 0.45),
                    child: Text(
                      'SELECT YOUR PORTAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCompact ? 10 : 11,
                        fontWeight: FontWeight.w800,
                        color: tokens.inkMuted,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Role cards — content-driven (no Expanded forcing) ──
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Card 1 — Guard Operations
                        FadeTransition(
                          opacity: _fade(0.12, 0.52),
                          child: SlideTransition(
                            position: _slide(0.12, 0.56),
                            child: _RoleCard(
                              title: 'GUARD OPERATIONS',
                              tagline: 'Attendance · Shifts · Duty reports',
                              icon: Icons.verified_user_rounded,
                              color: tokens.primary,
                              softColor: tokens.primarySoft,
                              introDelay: const Duration(milliseconds: 300),
                              compact: isCompact,
                              onTap: () => context.go('/login/guard'),
                            ),
                          ),
                        ),
                        SizedBox(height: cardGap),

                        // Card 2 — Field Command
                        FadeTransition(
                          opacity: _fade(0.22, 0.62),
                          child: SlideTransition(
                            position: _slide(0.22, 0.66),
                            child: _RoleCard(
                              title: 'FIELD COMMAND',
                              tagline: 'Districts · Work orders · Reports',
                              icon: Icons.admin_panel_settings_rounded,
                              color: tokens.accent,
                              softColor: tokens.accent.withValues(alpha: 0.1),
                              introDelay: const Duration(milliseconds: 500),
                              compact: isCompact,
                              onTap: () => context.go('/login/field-officer'),
                            ),
                          ),
                        ),
                        SizedBox(height: cardGap),

                        // Card 3 — Admin / Client
                        FadeTransition(
                          opacity: _fade(0.32, 0.72),
                          child: SlideTransition(
                            position: _slide(0.32, 0.76),
                            child: _RoleCard(
                              title: 'ADMIN / CLIENT',
                              tagline: 'Dashboard · Reports · Settings',
                              icon: Icons.shield_rounded,
                              color: tokens.danger,
                              softColor: tokens.danger.withValues(alpha: 0.08),
                              introDelay: const Duration(milliseconds: 700),
                              compact: isCompact,
                              showLeftBorder: true,
                              onTap: () => context.go('/login/admin'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Footer ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 0, horizontalPadding, isCompact ? 8 : 16),
                child: FadeTransition(
                  opacity: _fade(0.5, 1.0),
                  child: Column(
                    children: [
                      Text(
                        '© 2026 $kCompanyName · Secured by CISS Core',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.inkMuted.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => context.go('/enroll'),
                        child: Text(
                          'Don\'t have an account? Enroll as Guard',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => context.go('/region-select'),
                        child: Text(
                          'Change state',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tokens.inkMuted,
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Role card — horizontal Row layout for compact, content-driven cards
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.softColor,
    required this.introDelay,
    required this.onTap,
    this.compact = false,
    this.showLeftBorder = false,
  });

  final String title;
  final String tagline;
  final IconData icon;
  final Color color;
  final Color softColor;
  final Duration introDelay;
  final VoidCallback onTap;
  final bool compact;
  final bool showLeftBorder;

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
      duration: const Duration(milliseconds: 700),
    );
    _introAnim = CurvedAnimation(
      parent: _introCtrl,
      curve: Curves.easeOutBack,
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
    final theme = Theme.of(context);
    final bool veryCompact = widget.compact;

    final double iconSize = veryCompact ? 42 : 52;
    final double iconRadius = veryCompact ? 12 : 14;
    final double hPad = veryCompact ? 14 : 20;
    final double vPad = veryCompact ? 12 : 18;
    final double titleSize = veryCompact ? 17 : 20;
    final double arrowSize = veryCompact ? 18 : 22;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Haptics.light();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _introAnim,
          builder: (context, _) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _pressed
                      ? widget.color.withValues(alpha: 0.5)
                      : tokens.border.withValues(alpha: 0.5),
                  width: _pressed ? 1.5 : 1,
                ),
                boxShadow: _pressed
                    ? const <BoxShadow>[]
                    : <BoxShadow>[
                        BoxShadow(
                          color: tokens.ink.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -2,
                        ),
                      ],
              ),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    // Left accent border (Admin/Client card only)
                    if (widget.showLeftBorder)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              widget.color.withValues(alpha: 0.9),
                              widget.color.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            widget.showLeftBorder ? hPad - 4 : hPad,
                            vPad,
                            hPad,
                            vPad),
                        child: Row(
                          children: <Widget>[
                            // Icon
                            AnimatedBuilder(
                              animation: _introAnim,
                              builder: (context, _) {
                                return Transform.scale(
                                  scale: _introAnim.value.clamp(0.0, 1.0),
                                  child: Container(
                                    width: iconSize,
                                    height: iconSize,
                                    decoration: BoxDecoration(
                                      color: widget.softColor,
                                      borderRadius:
                                          BorderRadius.circular(iconRadius),
                                    ),
                                    child: Icon(
                                      widget.icon,
                                      color: widget.color,
                                      size: iconSize * 0.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),

                            // Title + Tagline
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.ink,
                                      height: 1.1,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    widget.tagline,
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: tokens.inkMuted,
                                      fontSize: veryCompact ? 11 : 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Arrow
                            AnimatedBuilder(
                              animation: _introAnim,
                              builder: (context, _) {
                                return Transform.translate(
                                  offset: Offset(
                                      (1 - _introAnim.value) * 12, 0),
                                  child: Opacity(
                                    opacity: _introAnim.value,
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: widget.color.withValues(alpha: 0.5),
                                      size: arrowSize,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
