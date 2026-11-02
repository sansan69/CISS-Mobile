import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/settings/module_gate.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../shared/widgets/modern_hero.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/metric_card.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/section_header.dart';
import '../../../../../shared/widgets/primary_action.dart';
import '../../../../../shared/widgets/action_row.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../core/fcm/notification_service.dart';
import '../../../shared/notification_inbox_screen.dart';
import '../../guard_tab_provider.dart';
import 'guard_incidents_screen.dart';
import 'guard_patrol_screen.dart';
import 'guard_payslips_screen.dart';
import 'guard_duties_screen.dart';
import 'guard_training_leaderboard_screen.dart';

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
      loading:
          () => const Scaffold(
            body: Column(
              children: <Widget>[
                BrandBanner(title: 'Guard', subtitle: 'Preparing dashboard'),
                Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
      error:
          (Object error, _) => Scaffold(
            body: Column(
              children: <Widget>[
                const BrandBanner(title: 'Guard', subtitle: 'Dashboard'),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: StateBlock(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load dashboard',
                        message: error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        action: FilledButton.tonal(
                          onPressed:
                              () => ref.invalidate(guardDashboardProvider),
                          child: const Text('Try again'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      data: (GuardDashboardSnapshot data) => _DashboardBody(data: data),
    );
  }
}

Widget _hPad(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), child: child);

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final displayName =
        data.employeeName.isNotEmpty ? data.employeeName : data.employeeId;
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final hasShift = data.nextShiftSiteName != null;
    final isOnDuty =
        data.nextShiftLabel != null &&
        data.nextShiftLabel!.toLowerCase().contains('duty');

    final initials =
        displayName.isNotEmpty
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

    void openAttendance() =>
        ref.read(guardTabIndexProvider.notifier).state = 1;

    final moreActions = <Widget>[
      ActionRow(
        icon: Icons.event_note_outlined,
        label: 'Upcoming duties',
        onTap: () => _push(context, const GuardDutiesScreen()),
      ),
      if (moduleEnabled(ref, 'payslips'))
        ActionRow(
          icon: Icons.receipt_long_rounded,
          label: 'Salary slips',
          onTap: () => _push(context, const GuardPayslipsScreen()),
        ),
      ActionRow(
        icon: Icons.route_rounded,
        label: 'Patrol',
        onTap: () => _push(context, const GuardPatrolScreen()),
      ),
      if (moduleEnabled(ref, 'incidents'))
        ActionRow(
          icon: Icons.shield_outlined,
          label: 'Incidents',
          onTap: () => _push(context, const GuardIncidentsScreen()),
        ),
      if (moduleEnabled(ref, 'training'))
        ActionRow(
          icon: Icons.menu_book_rounded,
          label: 'Training',
          onTap: () => _push(context, const GuardTrainingLeaderboardScreen()),
        ),
    ];

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(guardDashboardProvider),
          child: ListView(
            padding: EdgeInsets.only(
              bottom:
                  AppSpacing.xxl + MediaQuery.of(context).padding.bottom + 24,
            ),
            children: <Widget>[
              ModernHero(
                eyebrow: greeting,
                title: displayName,
                subtitle:
                    hasShift
                        ? '${data.nextShiftSiteName} • ${data.nextShiftLabel ?? 'Shift'}'
                        : '${data.clientName.isEmpty ? 'CISS Workforce' : data.clientName} • ${data.district.isEmpty ? 'No district' : data.district}',
                avatarText: initials,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SyncStatusBadge(
                      onTap: () => ref.read(syncServiceProvider).processQueue(),
                    ),
                    const _NotificationButton(),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              _hPad(
                PrimaryAction(
                  icon:
                      isOnDuty
                          ? Icons.logout_rounded
                          : Icons.how_to_reg_rounded,
                  label: isOnDuty ? 'Check out' : 'Mark attendance',
                  sublabel:
                      hasShift
                          ? data.nextShiftSiteName
                          : 'Scan the duty QR at your post',
                  onTap: openAttendance,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              _hPad(
                _DutyCard(
                  data: data,
                  tokens: tokens,
                  onOpen: openAttendance,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              _hPad(const SectionHeader(label: 'MORE')),
              const SizedBox(height: AppSpacing.xs),
              _hPad(
                ModernCard(
                  padding: EdgeInsets.zero,
                  child: _ActionRows(children: moreActions),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              _hPad(const SectionHeader(label: 'THIS MONTH')),
              const SizedBox(height: AppSpacing.sm),
              _hPad(
                Row(
                  children: <Widget>[
                    Expanded(
                      child: MetricCard(
                        label: 'Present',
                        value: '${data.presentDays}',
                        color: tokens.success,
                        backgroundColor: tokens.successSoft,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricCard(
                        label: 'Absent',
                        value: '${data.absentDays}',
                        color: tokens.danger,
                        backgroundColor: tokens.dangerSoft,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricCard(
                        label: 'Working',
                        value: '${data.workingDays}',
                        color: tokens.primary,
                        backgroundColor: tokens.primarySoft,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              _hPad(
                SectionHeader(
                  label: 'RECENT ACTIVITY',
                  actionLabel: 'View all',
                  onActionTap: openAttendance,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _hPad(_RecentActivity(data: data, onOpen: openAttendance)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRows extends StatelessWidget {
  const _ActionRows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    if (children.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Divider(height: 1, thickness: 1, color: tokens.border));
      }
    }
    return Column(children: rows);
  }
}

class _DutyCard extends StatelessWidget {
  const _DutyCard({
    required this.data,
    required this.tokens,
    required this.onOpen,
  });

  final GuardDashboardSnapshot data;
  final CissThemeTokens tokens;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasShift = data.nextShiftSiteName != null;
    final detail = <String>[
      if (data.nextShiftDate != null) data.nextShiftDate!,
      if (data.nextShiftLabel != null) data.nextShiftLabel!,
    ].join(' • ');

    return ModernCard(
      onTap: hasShift ? onOpen : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              color: tokens.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Your duty', style: AppTypography.cardTitle(context)),
                const SizedBox(height: 3),
                Text(
                  hasShift
                      ? '${data.nextShiftSiteName}${detail.isEmpty ? '' : ' • $detail'}'
                      : 'No duty assigned yet',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.micro(
                    context,
                  ).copyWith(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          if (hasShift)
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.inkMuted,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.data, required this.onOpen});

  final GuardDashboardSnapshot data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (data.recentAttendance.isEmpty) {
      return ModernCard(
        child: Row(
          children: <Widget>[
            Icon(
              Icons.history_toggle_off_rounded,
              color: tokens.inkMuted,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Your check-in and check-out activity will appear here.',
                style: AppTypography.body(
                  context,
                ).copyWith(color: tokens.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children:
          data.recentAttendance.take(3).map((item) {
            final isIn = item.status == 'In';
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ModernCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: onOpen,
                child: Row(
                  children: <Widget>[
                    Icon(
                      isIn ? Icons.login_rounded : Icons.logout_rounded,
                      color: isIn ? tokens.success : tokens.warning,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.siteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyStrong(context),
                          ),
                          Text(
                            '${item.dateLabel} • ${item.time}',
                            style: AppTypography.micro(
                              context,
                            ).copyWith(color: tokens.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
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
                        icon: Icon(
                          Icons.notifications_rounded,
                          color: tokens.surface,
                          size: 22,
                        ),
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
                            border: Border.all(
                              color: tokens.primaryStrong,
                              width: 2,
                            ),
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
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: tokens.surface,
                      size: 22,
                    ),
                  ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
