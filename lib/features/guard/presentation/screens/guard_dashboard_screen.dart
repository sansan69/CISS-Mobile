import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/dashboard/activity_feed.dart';
import '../../../../../shared/widgets/dashboard/dashboard_header.dart';
import '../../../../../shared/widgets/dashboard/duty_status_card.dart';
import '../../../../../shared/widgets/dashboard/quick_action_bar.dart';
import '../../../../../shared/widgets/dashboard/stat_pill_row.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../core/cache/skeleton_widgets.dart';
import '../../../../../core/fcm/notification_service.dart';
import '../../../shared/notification_inbox_screen.dart';
import '../../guard_tab_provider.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_incidents_screen.dart';
import 'guard_patrol_screen.dart';
import 'guard_profile_screen.dart';

final FutureProvider<GuardDashboardSnapshot> guardDashboardProvider =
    FutureProvider<GuardDashboardSnapshot>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchGuardDashboard();
    });

/// Guard dashboard redesigned for clarity, branding, and speed.
///
/// Layout (top to bottom):
/// 1. Header — greeting + profile
/// 2. Duty status card — prominent shift/site info
/// 3. Quick actions — attendance, patrol, incident, payslip, profile
/// 4. Stats — present days, client, district
/// 5. Recent activity — last 5 attendance records
/// 6. Performance score (if available)
class GuardDashboardScreen extends ConsumerWidget {
  const GuardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(guardDashboardProvider);

    return snapshot.when(
      loading: () => const SkeletonPage(cardCount: 4),
      error: (Object error, _) => GuardErrorScaffold(
        title: 'Could not load dashboard',
        error: error,
        onRetry: () => ref.invalidate(guardDashboardProvider),
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

    final hasShift = data.nextShiftSiteName != null;
    final isOnDuty = data.nextShiftLabel != null &&
        data.nextShiftLabel!.toLowerCase().contains('duty');

    // Determine greeting based on time of day (IST)
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return ScreenScaffold(
      title: '',
      subtitle: '',
      onRefresh: () async => ref.invalidate(guardDashboardProvider),
      actions: <Widget>[
        const _NotificationButton(),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => ref.invalidate(guardDashboardProvider),
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
      ],
      children: <Widget>[
        const SizedBox(height: AppSpacing.sm),

        // 1. Header
        DashboardHeader(
          greeting: greeting,
          name: displayName,
          subtitle: data.employeeId,
          photoUrl: data.profilePhotoUrl,
          statusLabel: isOnDuty ? 'On Duty' : null,
          statusColor: isOnDuty ? tokens.success : null,
          onProfileTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const GuardProfileScreen(),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 2. Duty status
        DutyStatusCard(
          status: isOnDuty
              ? DutyStatus.onDuty
              : hasShift
                  ? DutyStatus.standby
                  : DutyStatus.offDuty,
          siteName: hasShift
              ? data.nextShiftSiteName!
              : 'No site assigned',
          shiftTime: hasShift && data.nextShiftDate != null
              ? '${data.nextShiftDate} · ${data.nextShiftLabel}'
              : null,
          trackingActive: isOnDuty,
          onTap: hasShift
              ? () => ref.read(guardTabIndexProvider.notifier).state = 1
              : null,
        ),

        const SizedBox(height: AppSpacing.lg),

        // 3. Quick actions
        QuickActionBar(
          actions: <QuickAction>[
            QuickAction(
              icon: Icons.fingerprint_rounded,
              label: 'Attendance',
              color: tokens.primary,
              onTap: () =>
                  ref.read(guardTabIndexProvider.notifier).state = 1,
            ),
            QuickAction(
              icon: Icons.route_rounded,
              label: 'Patrol',
              color: tokens.accent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuardPatrolScreen(),
                ),
              ),
            ),
            QuickAction(
              icon: Icons.report_gmailerrorred_rounded,
              label: 'Incident',
              color: tokens.danger,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuardIncidentsScreen(),
                ),
              ),
            ),
            QuickAction(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Payslip',
              color: tokens.warning,
              onTap: () =>
                  ref.read(guardTabIndexProvider.notifier).state = 3,
            ),
            QuickAction(
              icon: Icons.person_rounded,
              label: 'Profile',
              color: tokens.success,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuardProfileScreen(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 4. Stats row
        StatPillRow(
          pills: <StatPill>[
            StatPill(
              label: 'Present',
              value: '${data.presentDays}',
              accentColor: tokens.success,
              icon: Icons.check_circle_outline_rounded,
            ),
            StatPill(
              label: 'Absent',
              value: '${data.absentDays}',
              accentColor: tokens.danger,
              icon: Icons.cancel_outlined,
            ),
            StatPill(
              label: 'Working',
              value: '${data.workingDays}',
              accentColor: tokens.primary,
              icon: Icons.work_outline_rounded,
            ),
            StatPill(
              label: 'Client',
              value: data.clientName.isEmpty ? '—' : data.clientName,
              accentColor: tokens.accent,
              icon: Icons.apartment_rounded,
            ),
            StatPill(
              label: 'District',
              value: data.district.isEmpty ? '—' : data.district,
              accentColor: tokens.accent,
              icon: Icons.place_rounded,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // 5. Recent activity
        ActivityFeed(
          title: 'Recent activity',
          items: data.recentAttendance.take(5).map((item) {
            final isIn = item.status == 'In';
            return ActivityItem(
              icon: isIn ? Icons.login_rounded : Icons.logout_rounded,
              iconColor: isIn ? tokens.success : tokens.warning,
              iconBgColor: (isIn ? tokens.success : tokens.warning)
                  .withValues(alpha: 0.1),
              title: item.siteName,
              subtitle: '${item.status} · ${item.dateLabel}',
              trailing: item.time,
              onTap: () =>
                  ref.read(guardTabIndexProvider.notifier).state = 1,
            );
          }).toList(),
          onViewAll: () =>
              ref.read(guardTabIndexProvider.notifier).state = 1,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 6. Performance score (if available)
        if (data.latestEvalScore != null) _EvalCard(data: data),

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _EvalCard extends StatelessWidget {
  const _EvalCard({required this.data});

  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.warningSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.stars_rounded,
                  color: tokens.warning, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Performance score',
                    style: AppTypography.cardTitle(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.latestEvalPeriod ?? 'Latest period',
                    style: AppTypography.micro(context).copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${data.latestEvalScore}%',
              style: AppTypography.metric(context).copyWith(
                color: tokens.warning,
                fontSize: 28,
              ),
            ),
          ],
        ),
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
                  icon: const Icon(Icons.notifications_rounded, size: 22),
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
                      border: Border.all(color: tokens.canvas, width: 2),
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
              icon: const Icon(Icons.notifications_outlined, size: 22),
            ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
