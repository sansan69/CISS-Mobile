import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/brand.dart';
import '../../../core/haptics.dart';
import '../../../core/region/region_service.dart';
import '../../../shared/widgets/auth/login_background.dart';

/// Role selection hub — choose Guard or Field Officer.
///
/// Rendered as a static, flat screen: no entrance animations, no decorative
/// movement, clear role cards that respond only on press. Cards flex-fill the
/// available height (capped) so the screen stays dense on tall devices.
class LoginHubScreen extends StatelessWidget {
  const LoginHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final mediaHeight = MediaQuery.of(context).size.height;

    final bool isCompact = mediaHeight < 680;
    final double logoSize = isCompact ? 56 : 88;
    final double horizontalPadding = isCompact ? 16.0 : 24.0;
    final double cardGap = isCompact ? 12 : 16;

    return Scaffold(
      body: SecurityGridBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // ── Region switcher ──
              Consumer(
                builder: (context, ref, _) {
                  final savedCode = ref.watch(savedRegionProvider).value;
                  final regionName =
                      RegionService.instance.activeRegion?.name ??
                      (savedCode != null && savedCode.isNotEmpty
                          ? savedCode.toUpperCase()
                          : 'Region');
                  return Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: horizontalPadding,
                        top: isCompact ? 4 : 8,
                      ),
                      child: InkWell(
                        onTap: () => context.go('/region-select'),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: tokens.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 14,
                                color: tokens.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                regionName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 14,
                                color: tokens.inkMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // ── Brand mark ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isCompact ? 8 : 16,
                  horizontalPadding,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: logoSize,
                      height: logoSize,
                      padding: EdgeInsets.all(logoSize * 0.22),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.border),
                      ),
                      child: Image.asset(
                        kCompanyLogoAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 14),
                    Text(
                      kCompanyName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: tokens.primary,
                        letterSpacing: 2.0,
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
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Label + role cards (centered; cards flex-fill) ──
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // Reserve label + inter-card gaps; split the rest between
                    // the two cards, clamped so they never get absurd.
                    final double cardHeight = ((constraints.maxHeight -
                                20 - // label line
                                14 - // label → card 1
                                cardGap * 2) /
                            2)
                        .clamp(isCompact ? 112.0 : 140.0, isCompact ? 180.0 : 220.0);

                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Sign in as',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: tokens.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _RoleCard(
                              title: 'Guard',
                              tagline: 'Attendance, shifts, and duty reports',
                              icon: Icons.verified_user_rounded,
                              color: tokens.primary,
                              softColor: tokens.primarySoft,
                              height: cardHeight,
                              compact: isCompact,
                              onTap: () => context.go('/login/guard'),
                            ),
                            SizedBox(height: cardGap),
                            _RoleCard(
                              title: 'Field Officer',
                              tagline: 'Districts, work orders, and reports',
                              icon: Icons.admin_panel_settings_rounded,
                              color: tokens.accent,
                              softColor: tokens.accent.withValues(alpha: 0.1),
                              height: cardHeight,
                              compact: isCompact,
                              onTap: () => context.go('/login/field-officer'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Footer ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  isCompact ? 8 : 20,
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      '© 2026 $kCompanyName',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('$kCompanyPortalUrl/enroll'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Text(
                          'New guard? Enroll here',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
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
// Role card — flat, tappable, minimum 48dp target, flex-fill hero panel
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.softColor,
    required this.onTap,
    required this.height,
    this.compact = false,
  });

  final String title;
  final String tagline;
  final IconData icon;
  final Color color;
  final Color softColor;
  final VoidCallback onTap;
  final double height;
  final bool compact;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: widget.title,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          Haptics.light();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: _pressed
                  ? AppShadows.glow(widget.color)
                  : AppShadows.card,
            ),
            child: Material(
              color: tokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: BorderSide(
                  color: _pressed ? widget.color : tokens.specularBorder,
                  width: _pressed ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: SizedBox(
                  height: widget.height,
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 14 : 20,
                      vertical: widget.compact ? 12 : 16,
                    ),
                    child: Column(
                      children: <Widget>[
                        const Spacer(flex: 1),
                        Container(
                          width: widget.compact ? 46 : 58,
                          height: widget.compact ? 46 : 58,
                          decoration: BoxDecoration(
                            color: widget.softColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.color.withValues(alpha: 0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.2),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.color,
                            size: widget.compact ? 24 : 30,
                          ),
                        ),
                      SizedBox(height: widget.compact ? 10 : 14),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: widget.compact ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tagline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.inkMuted,
                          fontSize: widget.compact ? 12 : 14,
                        ),
                      ),
                      const Spacer(flex: 2),
                      if (!widget.compact) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Enter portal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: tokens.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: tokens.primary,
                            ),
                          ],
                        ),
                      ],
                    ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
