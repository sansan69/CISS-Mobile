import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/widgets/modern_card.dart';
import '../../application/open_duty_session.dart';
import '../screens/guard_attendance_screen.dart';

/// The guard's open duty, including one that started before midnight.
///
/// Without this the dashboard simply went quiet at midnight: the guard saw no
/// sign of the tour they were still on, and a forgotten check-out was invisible
/// until payroll noticed. It reads the guard's own attendance log directly, so
/// it costs no extra request and inherits whatever scope the shell already
/// provides for that log.

class OpenDutySessionCard extends ConsumerWidget {
  const OpenDutySessionCard({super.key, this.onOpen});

  /// Defaults to opening the attendance screen, where the check-out is
  /// recorded and the server's early-check-out reason prompt runs.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recentAttendanceHistoryProvider).valueOrNull;
    final session =
        records == null
            ? null
            : openDutySession(records, now: ref.read(clockProvider)());
    if (session == null) return const SizedBox.shrink();

    final tokens = CissThemeTokens.of(context);
    final strings = AppStrings.of(context);
    final overdue = session.status == OpenDutyStatus.overdue;
    final accent = overdue ? tokens.danger : tokens.success;
    final since = strings.fill(
      session.startedBefore(ref.read(clockProvider)())
          ? strings.attendanceSinceYesterday
          : strings.attendanceSince,
      <String, Object>{'time': _clock(session.checkInAt)},
    );
    final place = <String>[
      session.siteName.trim(),
      session.dutyPointName.trim(),
    ].where((value) => value.isNotEmpty).join(' · ');

    return ModernCard(
      onTap:
          onOpen ??
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const GuardAttendanceScreen(),
            ),
          ),
      borderColor: accent.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            overdue ? Icons.error_outline_rounded : Icons.timelapse_rounded,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  overdue
                      ? strings.attendanceCheckOutMissing
                      : '${strings.attendanceOnDuty} $since',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  overdue ? strings.dutyCloseShiftHint : place,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, color: accent),
        ],
      ),
    );
  }

  static String _clock(DateTime moment) =>
      '${moment.hour.toString().padLeft(2, '0')}:'
      '${moment.minute.toString().padLeft(2, '0')}';
}
