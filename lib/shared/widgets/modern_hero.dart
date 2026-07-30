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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.primary, tokens.primaryStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (avatarText != null || avatarChild != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child:
                      avatarChild ??
                      Text(
                        avatarText ?? '',
                        style: const TextStyle(
                          fontSize: 20,
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
