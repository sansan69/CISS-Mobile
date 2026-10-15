import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'brand_banner.dart';

class ModernHero extends StatelessWidget {
  const ModernHero({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.avatarText,
    this.avatarChild,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final String? avatarText;
  final Widget? avatarChild;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final foreground = Theme.of(context).colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: tokens.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder:
                (context, constraints) => Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: CissBrandMark(
                        inverse: true,
                        compact: true,
                        foregroundColor: foreground,
                      ),
                    ),
                    if (trailing != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: trailing!,
                      ),
                  ],
                ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: foreground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (avatarText != null || avatarChild != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child:
                      avatarChild ??
                      Text(
                        avatarText ?? '',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
