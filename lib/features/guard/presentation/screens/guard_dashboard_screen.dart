import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/modern_hero.dart';
import '../../../../../shared/widgets/metric_card.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../core/fcm/notification_service.dart';
import '../../../shared/notification_inbox_screen.dart';
import '../../guard_tab_provider.dart';
import 'guard_incidents_screen.dart';
import 'guard_patrol_screen.dart';
import 'guard_payslips_screen.dart';
import 'guard_leave_screen.dart';

final FutureProvider<GuardDashboardSnapshot> guardDashboardProvider =
    FutureProvider<GuardDashboardSnapshot>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchGuardDashboard();
});

class GuardDashboardScreen extends ConsumerWidget {
  const GuardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(guardDashboardProvider);

    return snapshot.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StateBlock(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load dashboard',
              message: error.toString().replaceFirst('Exception: ', ''),
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(guardDashboardProvider),
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      ),
      data: (GuardDashboardSnapshot data) => _DashboardBody(data: data),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final displayName =
        data.employeeName.isNotEmpty ? data.employeeName : data.employeeId;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final hasShift = data.nextShiftSiteName != null;
    final isOnDuty = data.nextShiftLabel != null &&
        data.nextShiftLabel!.toLowerCase().contains('duty');

    final initials = displayName.isNotEmpty
        ? displayName
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join()
            .toUpperCase()
        : data.employeeId.isNotEmpty
            ? data.employeeId.substring(0, 2).toUpperCase()
            : 'GU';

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(guardDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl + 80),
            children: <Widget>[
              ModernHero(
                eyebrow: greeting,
                title: displayName,
                subtitle: hasShift
                    ? '${data.nextShiftSiteName} • ${data.nextShiftLabel ?? 'Shift'}'
                    : '${data.clientName.isEmpty ? 'CISS Workforce' : data.clientName} • ${data.district.isEmpty ? 'No district' : data.district}',
                avatarText: initials,
                trailing: const _NotificationButton(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Metric Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      MetricCard(
                        label: 'Present',
                        value: '${data.presentDays}',
                        color: tokens.success,
                        backgroundColor: tokens.successSoft,
                        width: 130,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      MetricCard(
                        label: 'Absent',
                        value: '${data.absentDays}',
                        color: tokens.danger,
                        backgroundColor: tokens.dangerSoft,
                        width: 130,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      MetricCard(
                        label: 'Working',
                        value: '${data.workingDays}',
                        color: tokens.primary,
                        backgroundColor: tokens.primarySoft,
                        width: 130,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Next Shift Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ModernCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  onTap: hasShift
                      ? () =>
                          ref.read(guardTabIndexProvider.notifier).state = 1
                      : null,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isOnDuty
                              ? tokens.successSoft
                              : tokens.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          hasShift
                              ? Icons.play_circle_filled_rounded
                              : Icons.schedule_rounded,
                          color: isOnDuty ? tokens.success : tokens.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              hasShift
                                  ? data.nextShiftSiteName!
                                  : 'Attendance Status',
                              style: AppTypography.cardTitle(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasShift && data.nextShiftDate != null
                                  ? '${data.nextShiftDate} • ${data.nextShiftLabel ?? 'Assigned shift'}'
                                  : 'No site shift is currently assigned.',
                              style: AppTypography.micro(context).copyWith(
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: isOnDuty
                            ? 'On Duty'
                            : hasShift
                                ? 'Standby'
                                : 'Off Duty',
                        tone: isOnDuty
                            ? StatusChipTone.success
                            : hasShift
                                ? StatusChipTone.warning
                                : StatusChipTone.neutral,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Eval Score + Payslip Card
              if (data.latestEvalScore != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: ModernCard(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.stars_rounded,
                              color: tokens.accent, size: 26),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Latest Evaluation',
                                style: AppTypography.cardTitle(context),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data.latestEvalPeriod ??
                                    'Current period',
                                style: AppTypography.micro(context)
                                    .copyWith(color: tokens.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: tokens.warningSoft,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${data.latestEvalScore!.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (data.leaveBalance != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: ModernCard(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.event_available_rounded,
                              color: tokens.primary, size: 26),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Leave Balance',
                                  style: AppTypography.cardTitle(context)),
                              const SizedBox(height: 2),
                              Text(
                                '${data.leaveBalance!.balance} remaining · ${data.leaveBalance!.entitled} entitled · ${data.leaveBalance!.taken} taken',
                                style: AppTypography.micro(context)
                                    .copyWith(color: tokens.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: tokens.inkMuted, size: 20),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const GuardLeaveScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Quick Actions',
                        style: AppTypography.title(context)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ModernCard(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GuardPayslipsScreen(),
                              ),
                            ),
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.receipt_long_rounded,
                                    color: tokens.primary, size: 28),
                                const SizedBox(height: 8),
                                Text('Payslips',
                                    style: AppTypography.micro(context)
                                        .copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ModernCard(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GuardPatrolScreen(),
                              ),
                            ),
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.route_rounded,
                                    color: tokens.accent, size: 28),
                                const SizedBox(height: 8),
                                Text('Patrol',
                                    style: AppTypography.micro(context)
                                        .copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ModernCard(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GuardIncidentsScreen(),
                              ),
                            ),
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.report_gmailerrorred_rounded,
                                    color: tokens.danger, size: 28),
                                const SizedBox(height: 8),
                                Text('Incident',
                                    style: AppTypography.micro(context)
                                        .copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Recent Activity
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Recent Activity',
                            style: AppTypography.title(context)),
                        TextButton(
                          onPressed: () =>
                              ref.read(guardTabIndexProvider.notifier).state = 1,
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (data.recentAttendance.isEmpty)
                      ModernCard(
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.history_toggle_off_rounded,
                                color: tokens.inkMuted, size: 24),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Your check-in and check-out activity will appear here.',
                              style: AppTypography.body(context).copyWith(
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...data.recentAttendance.take(5).map((item) {
                        final isIn = item.status == 'In';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ModernCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            onTap: () =>
                                ref.read(guardTabIndexProvider.notifier).state =
                                    1,
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  isIn
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  color: isIn ? tokens.success : tokens.warning,
                                  size: 22,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(item.siteName,
                                          style: AppTypography
                                              .bodyStrong(context)),
                                      Text(
                                        '${item.status} • ${item.dateLabel} • ${item.time}',
                                        style: AppTypography
                                            .micro(context)
                                            .copyWith(color: tokens.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip(
                                  label: item.status,
                                  tone: isIn
                                      ? StatusChipTone.success
                                      : StatusChipTone.warning,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            ref.read(guardTabIndexProvider.notifier).state = 1,
        backgroundColor: tokens.success,
        foregroundColor: tokens.surface,
        icon: const Icon(Icons.login_rounded),
        label: const Text('Check In'),
      ),
    );
  }
}

class _NotificationButton extends ConsumerWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final unreadAsync = ref.watch(NotificationService.unreadCountProvider);

    return unreadAsync.when(
      data: (int count) => count > 0
          ? Stack(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationInboxScreen(),
                    ),
                  ),
                  icon: Icon(Icons.notifications_rounded,
                      color: tokens.surface, size: 22),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: tokens.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.primaryStrong, width: 2),
                    ),
                  ),
                ),
              ],
            )
          : IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationInboxScreen(),
                ),
              ),
              icon: Icon(Icons.notifications_outlined,
                  color: tokens.surface, size: 22),
            ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
