import 'package:flutter/material.dart';
import '../../../app/theme/app_tokens.dart';

/// Prominent duty status card for guard dashboard.
///
/// Shows current duty state with color-coded background,
/// site name, and next shift info.
class DutyStatusCard extends StatelessWidget {
  const DutyStatusCard({
    super.key,
    required this.status,
    required this.siteName,
    this.shiftTime,
    this.onTap,
    this.trackingActive = false,
  });

  final DutyStatus status;
  final String siteName;
  final String? shiftTime;
  final VoidCallback? onTap;
  final bool trackingActive;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final (Color bgColor, Color textColor, IconData icon) = switch (status) {
      DutyStatus.onDuty => (
          tokens.successSoft,
          tokens.success,
          Icons.radio_button_checked_rounded
        ),
      DutyStatus.standby => (
          tokens.primarySoft,
          tokens.primary,
          Icons.pause_circle_outline_rounded
        ),
      DutyStatus.offDuty => (
          tokens.surfaceMuted,
          tokens.inkMuted,
          Icons.nights_stay_rounded
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: textColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      status.label.toUpperCase(),
                      style: AppTypography.label(context).copyWith(
                        color: textColor,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    if (trackingActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: tokens.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tracking',
                              style: AppTypography.micro(context).copyWith(
                                color: tokens.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  siteName,
                  style: AppTypography.title(context).copyWith(
                    color: tokens.ink,
                    fontSize: 20,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (shiftTime != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    shiftTime!,
                    style: AppTypography.body(context).copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum DutyStatus {
  onDuty('On Duty'),
  standby('On Standby'),
  offDuty('Off Duty');

  const DutyStatus(this.label);
  final String label;
}
