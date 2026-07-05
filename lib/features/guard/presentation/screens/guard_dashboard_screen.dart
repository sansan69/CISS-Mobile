import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/cache/skeleton_widgets.dart';
import '../../../../../core/fcm/notification_service.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/dashboard/quick_action_bar.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/status_chip.dart';
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

class GuardDashboardScreen extends ConsumerWidget {
  const GuardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(guardDashboardProvider);

    return snapshot.when(
      loading: () => const SkeletonPage(cardCount: 4),
      error:
          (Object error, _) => GuardErrorScaffold(
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
    final isOnDuty =
        data.nextShiftLabel != null &&
        data.nextShiftLabel!.toLowerCase().contains('duty');
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return ScreenScaffold(
      title: 'Guard home',
      subtitle: data.employeeId,
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
        GuardHeroPanel(
          eyebrow: greeting,
          title: displayName,
          subtitle:
              hasShift
                  ? '${data.nextShiftSiteName} • ${data.nextShiftLabel ?? 'Shift ready'}'
                  : '${data.clientName.isEmpty ? 'CISS Workforce' : data.clientName} • ${data.district.isEmpty ? 'No district' : data.district}',
          icon: isOnDuty ? Icons.shield_rounded : Icons.badge_rounded,
          accentColor: isOnDuty ? tokens.success : tokens.primary,
          trailing: _HeroProfileAvatar(photoUrl: data.profilePhotoUrl),
        ),
        const SizedBox(height: AppSpacing.lg),
        GuardMetricStrip(
          items: <GuardMetricItem>[
            GuardMetricItem(
              label: 'Present',
              value: '${data.presentDays}',
              icon: Icons.check_circle_outline_rounded,
              color: tokens.success,
            ),
            GuardMetricItem(
              label: 'Absent',
              value: '${data.absentDays}',
              icon: Icons.cancel_outlined,
              color: tokens.danger,
            ),
            GuardMetricItem(
              label: 'Working',
              value: '${data.workingDays}',
              icon: Icons.work_outline_rounded,
              color: tokens.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GuardRecordCard(
          title: hasShift ? data.nextShiftSiteName! : 'Attendance status',
          subtitle:
              hasShift && data.nextShiftDate != null
                  ? '${data.nextShiftDate} • ${data.nextShiftLabel ?? 'Assigned shift'}'
                  : 'No site shift is currently assigned.',
          icon:
              isOnDuty
                  ? Icons.play_circle_filled_rounded
                  : Icons.schedule_rounded,
          chip: StatusChip(
            label:
                isOnDuty
                    ? 'On duty'
                    : hasShift
                    ? 'Standby'
                    : 'Off duty',
            tone:
                isOnDuty
                    ? StatusChipTone.success
                    : hasShift
                    ? StatusChipTone.warning
                    : StatusChipTone.neutral,
          ),
          onTap:
              hasShift
                  ? () => ref.read(guardTabIndexProvider.notifier).state = 1
                  : null,
        ),
        const SizedBox(height: AppSpacing.md),
        QuickActionBar(
          actions: <QuickAction>[
            QuickAction(
              icon: Icons.fingerprint_rounded,
              label: 'Attendance',
              color: tokens.primary,
              onTap: () => ref.read(guardTabIndexProvider.notifier).state = 1,
            ),
            QuickAction(
              icon: Icons.route_rounded,
              label: 'Patrol',
              color: tokens.accent,
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuardPatrolScreen(),
                    ),
                  ),
            ),
            QuickAction(
              icon: Icons.report_gmailerrorred_rounded,
              label: 'Incident',
              color: tokens.danger,
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuardIncidentsScreen(),
                    ),
                  ),
            ),
            QuickAction(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Payslip',
              color: tokens.warning,
              onTap: () => ref.read(guardTabIndexProvider.notifier).state = 3,
            ),
            QuickAction(
              icon: Icons.person_rounded,
              label: 'Profile',
              color: tokens.success,
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuardProfileScreen(),
                    ),
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GuardRecordCard(
          title:
              data.clientName.isEmpty ? 'Client not assigned' : data.clientName,
          subtitle:
              data.district.isEmpty
                  ? 'District details will appear after assignment.'
                  : 'District: ${data.district}',
          icon: Icons.apartment_rounded,
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuardProfileScreen(),
                ),
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _DashboardSectionHeader(
          title: 'Recent activity',
          actionLabel: 'View all',
          onTap: () => ref.read(guardTabIndexProvider.notifier).state = 1,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.recentAttendance.isEmpty)
          const GuardRecordCard(
            title: 'No attendance yet',
            subtitle: 'Your check-in and check-out activity will appear here.',
            icon: Icons.history_toggle_off_rounded,
          )
        else
          ...data.recentAttendance.take(5).map((item) {
            final isIn = item.status == 'In';
            return GuardRecordCard(
              title: item.siteName,
              subtitle: '${item.status} • ${item.dateLabel} • ${item.time}',
              icon: isIn ? Icons.login_rounded : Icons.logout_rounded,
              chip: StatusChip(
                label: item.status,
                tone: isIn ? StatusChipTone.success : StatusChipTone.warning,
              ),
              onTap: () => ref.read(guardTabIndexProvider.notifier).state = 1,
            );
          }),
        const SizedBox(height: AppSpacing.lg),
        if (data.latestEvalScore != null) _EvalCard(data: data),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _HeroProfileAvatar extends StatelessWidget {
  const _HeroProfileAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return CircleAvatar(
      radius: 23,
      backgroundColor: Colors.white.withValues(alpha: 0.16),
      backgroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child:
          url == null || url.isEmpty
              ? const Icon(Icons.person_rounded, color: Colors.white)
              : null,
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _EvalCard extends StatelessWidget {
  const _EvalCard({required this.data});

  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    return GuardRecordCard(
      title: 'Performance score',
      subtitle: data.latestEvalPeriod ?? 'Latest period',
      icon: Icons.stars_rounded,
      chip: StatusChip(
        label: '${data.latestEvalScore}%',
        tone: StatusChipTone.warning,
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
      data:
          (int count) =>
              count > 0
                  ? Stack(
                    children: <Widget>[
                      IconButton(
                        onPressed:
                            () => Navigator.of(context).push(
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
                    onPressed:
                        () => Navigator.of(context).push(
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
