import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/settings/module_gate.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../../../shared/utils/initials.dart';
import '../../../../../shared/widgets/modern_hero.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/section_header.dart';
import '../../../../../shared/widgets/primary_action.dart';
import '../../../../../shared/widgets/action_row.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../core/fcm/notification_service.dart';
import '../../../shared/notification_inbox_screen.dart';
import '../../../shared/readiness_banner.dart';
import '../widgets/open_duty_session_card.dart';
import '../../guard_tab_provider.dart';
import 'guard_incidents_screen.dart';
import 'guard_patrol_screen.dart';
import 'guard_duties_screen.dart';
import 'guard_profile_screen.dart';
import '../../application/duty_willingness_controller.dart';
import '../../../../../core/models/duty_models.dart';
import 'guard_payslips_screen.dart';
import 'guard_leave_screen.dart';
import 'guard_training_screen.dart';

final FutureProvider<GuardDashboardSnapshot> guardDashboardProvider =
    FutureProvider<GuardDashboardSnapshot>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchGuardDashboard();
    });

class GuardDashboardScreen extends ConsumerWidget {
  const GuardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(guardDashboardProvider);
    final tokens = CissThemeTokens.of(context);
    final duties = ref.watch(guardDutiesProvider).valueOrNull;
    final profile = ref.watch(guardProfileProvider).valueOrNull;
    final nextDuty =
        duties
            ?.where(
              (d) =>
                  d.kind == DutyKind.assigned ||
                  moduleEnabled(ref, 'workOrders'),
            )
            .firstOrNull;
    final data = snapshot.valueOrNull;
    final name = data?.employeeName.trim() ?? '';
    final employeeId = data?.employeeId.trim() ?? '';
    final displayName =
        name.isNotEmpty
            ? name
            : employeeId.isNotEmpty
            ? employeeId
            : 'Guard';
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    void openAttendance() => ref.read(guardTabIndexProvider.notifier).state = 1;
    void openDuty() => _push(context, const GuardDutiesScreen());

    final moreActions = <Widget>[
      ActionRow(
        icon: Icons.event_note_outlined,
        label: 'Upcoming duty',
        onTap: openDuty,
      ),
      if (moduleEnabled(ref, 'payslips'))
        ActionRow(
          icon: Icons.payments_outlined,
          label: 'Payslips',
          onTap: () => _push(context, const GuardPayslipsScreen()),
        ),
      if (moduleEnabled(ref, 'leave'))
        ActionRow(
          icon: Icons.calendar_today_rounded,
          label: 'Leave',
          onTap: () => _push(context, const GuardLeaveScreen()),
        ),
      if (moduleEnabled(ref, 'patrol'))
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
          onTap: () => _push(context, const GuardTrainingScreen()),
        ),
    ];

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(guardDashboardProvider);
            try {
              await ref.read(guardDashboardProvider.future);
            } catch (_) {
              // The provider renders the failure and retry action. Keep the
              // pull-to-refresh callback settled without an uncaught future.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: 120 + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              ModernHero(
                eyebrow: greeting,
                title: displayName,
                subtitle:
                    data == null
                        ? 'Your workforce home'
                        : <String>[
                          data.clientName.trim(),
                          data.district.trim(),
                        ].where((value) => value.isNotEmpty).join(' • '),
                avatarText: initials(displayName, fallback: 'GU'),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    SyncStatusBadge(
                      onTap: () => ref.read(syncServiceProvider).processQueue(),
                    ),
                    const _NotificationButton(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _hPad(
                PrimaryAction(
                  icon: Icons.how_to_reg_rounded,
                  label: 'Mark attendance',
                  sublabel: 'Scan the duty QR at your post',
                  onTap: openAttendance,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // The open tour comes before the setup prompt: a guard who is
              // still on duty across midnight needs to see it, not a checklist.
              _hPad(const OpenDutySessionCard()),
              const SizedBox(height: AppSpacing.md),
              // Setup gaps go directly under the main action: a guard who
              // cannot be tracked needs to know before starting a shift.
              _hPad(const ReadinessBanner()),
              const SizedBox(height: AppSpacing.md),
              _hPad(
                snapshot.when(
                  skipLoadingOnRefresh: true,
                  loading: () => const _DashboardPlaceholder(),
                  error:
                      (error, _) => StateBlock(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load dashboard',
                        message:
                            'Attendance is still available. Pull to refresh or try again.',
                        action: FilledButton.tonal(
                          onPressed:
                              () => ref.invalidate(guardDashboardProvider),
                          child: const Text('Try again'),
                        ),
                      ),
                  data:
                      (value) =>
                          nextDuty == null
                              ? _DutyCard(data: value, onOpen: openDuty)
                              : ModernCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nextDuty.isExam && nextDuty.canRespond
                                          ? 'Exam duty available'
                                          : nextDuty.status == 'cancelled'
                                          ? 'Duty cancelled'
                                          : 'Next scheduled duty',
                                      style: AppTypography.cardTitle(context),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(nextDuty.siteName),
                                    Text(formatDutyDate(nextDuty.date)),
                                    if (nextDuty.isExam)
                                      const Text(
                                        'Expressing willingness does not confirm assignment.',
                                      ),
                                    ActionRow(
                                      icon: Icons.event_note_outlined,
                                      label: 'View duty details',
                                      onTap: openDuty,
                                    ),
                                  ],
                                ),
                              ),
                ),
              ),
              if (profile?.categoryLabel != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    profile!.categoryLabel!,
                    style: AppTypography.label(context),
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
              if (data != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                _hPad(const SectionHeader(label: 'THIS MONTH')),
                const SizedBox(height: AppSpacing.sm),
                _hPad(
                  ModernCard(
                    child: Column(
                      children: <Widget>[
                        _MonthCount(label: 'Present', value: data.presentDays),
                        const Divider(),
                        _MonthCount(label: 'Absent', value: data.absentDays),
                        const Divider(),
                        _MonthCount(label: 'Working', value: data.workingDays),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _hPad(
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        'RECENT ACTIVITY',
                        style: AppTypography.micro(
                          context,
                        ).copyWith(color: tokens.inkMuted),
                      ),
                      TextButton(
                        onPressed: openAttendance,
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _hPad(_RecentActivity(data: data, onOpen: openAttendance)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _hPad(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: child,
);
void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();
  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Semantics(
      label: 'Loading dashboard',
      child: ModernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(height: 16, width: 140, color: tokens.primarySoft),
            const SizedBox(height: AppSpacing.sm),
            Container(height: 14, color: tokens.primarySoft),
            const SizedBox(height: AppSpacing.sm),
            Container(height: 14, width: 180, color: tokens.primarySoft),
          ],
        ),
      ),
    );
  }
}

class _MonthCount extends StatelessWidget {
  const _MonthCount({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(label, style: AppTypography.body(context))),
      Text('$value', style: AppTypography.bodyStrong(context)),
    ],
  );
}

class _ActionRows extends StatelessWidget {
  const _ActionRows({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Column(
      children: <Widget>[
        for (var index = 0; index < children.length; index++) ...<Widget>[
          children[index],
          if (index < children.length - 1)
            Divider(height: 1, thickness: 1, color: tokens.border),
        ],
      ],
    );
  }
}

class _DutyCard extends StatelessWidget {
  const _DutyCard({required this.data, required this.onOpen});
  final GuardDashboardSnapshot data;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final site = data.nextShiftSiteName?.trim() ?? '';
    final detail = <String>[
      formatDutyDate(data.nextShiftDate),
      data.nextShiftLabel?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' • ');
    final message =
        data.nextShiftUnavailable
            ? 'Duty details are unavailable'
            : site.isEmpty
            ? 'No upcoming assignment. You can mark attendance without an assigned duty.'
            : '$site${detail.isEmpty ? '' : ' • $detail'}';
    return ModernCard(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Icon(Icons.event_note_outlined, color: tokens.primary, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Your duty', style: AppTypography.cardTitle(context)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  maxLines: site.isEmpty ? 4 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    context,
                  ).copyWith(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, color: tokens.inkMuted, size: 20),
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
