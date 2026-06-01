import 'package:flutter/material.dart';
import '../../../app/theme/app_tokens.dart';

/// Clean dashboard header with greeting, name, profile photo, and optional status.
///
/// Designed for both Guard and Field Officer dashboards.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.greeting,
    required this.name,
    this.subtitle,
    this.photoUrl,
    this.statusLabel,
    this.statusColor,
    this.onProfileTap,
  });

  final String greeting;
  final String name;
  final String? subtitle;
  final String? photoUrl;
  final String? statusLabel;
  final Color? statusColor;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>
[
                Text(
                  greeting,
                  style: AppTypography.body(context).copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: AppTypography.display(context).copyWith(
                    color: tokens.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppTypography.micro(context).copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          GestureDetector(
            onTap: onProfileTap,
            child: Stack(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.surfaceStrong,
                    border: Border.all(
                      color: tokens.border,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: photoUrl != null && photoUrl!.isNotEmpty
                        ? Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              color: tokens.inkMuted,
                              size: 28,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            color: tokens.inkMuted,
                            size: 28,
                          ),
                  ),
                ),
                if (statusLabel != null && statusColor != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.surface,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
