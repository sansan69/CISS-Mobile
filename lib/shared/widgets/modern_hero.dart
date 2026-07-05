import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.primary, tokens.primaryStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child:
                      avatarChild ??
                      Text(
                        avatarText ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                ),
              ],
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}
