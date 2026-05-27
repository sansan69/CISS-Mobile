import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/attendance_models.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/metric_tile.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../core/cache/skeleton_widgets.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../guard_tab_provider.dart';
import '../widgets/guard_portal_widgets.dart';
import 'guard_incidents_screen.dart';
import 'guard_patrol_screen.dart';

final FutureProvider<GuardDashboardSnapshot> guardDashboardProvider =
    FutureProvider<GuardDashboardSnapshot>((Ref ref) {
      return ref.watch(mobileRepositoryProvider).fetchGuardDashboard();
    });

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
      data: (GuardDashboardSnapshot data) {
        final String displayName =
            data.employeeName.isNotEmpty ? data.employeeName : data.employeeId;

        return ScreenScaffold(
          title: 'Dashboard',
          subtitle: displayName,
          actions: <Widget>[
            const SyncStatusBadge(),
            IconButton(
              onPressed: () => ref.invalidate(guardDashboardProvider),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
          children: <Widget>[
            // ── Shift status header ───────────────────────────────────────
            _ShiftStatusCard(data: data),

            const _PatrolStatusCard(),

            // ── Quick actions ─────────────────────────────────────────────
            _QuickActions(ref: ref, context: context),

            // ── Key metrics ───────────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricTile(
                    label: 'Client',
                    value: data.clientName.isEmpty
                        ? 'Unassigned'
                        : data.clientName,
                    helper: 'Deployment account',
                    icon: Icons.apartment_rounded,
                    accentColor: Theme.of(context)
                        .extension<CissThemeTokens>()!
                        .primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricTile(
                    label: 'District',
                    value: data.district.isEmpty ? 'Pending' : data.district,
                    helper: 'Current posting',
                    icon: Icons.place_outlined,
                    accentColor: Theme.of(context)
                        .extension<CissThemeTokens>()!
                        .accent,
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricTile(
                    label: 'Present days',
                    value: '${data.presentDays}',
                    helper: '${data.workingDays} days logged',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: Theme.of(context)
                        .extension<CissThemeTokens>()!
                        .success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricTile(
                    label: 'Working days',
                    value: '${data.workingDays}',
                    helper: 'Expected shifts',
                    icon: Icons.calendar_month_outlined,
                    accentColor: Theme.of(context)
                        .extension<CissThemeTokens>()!
                        .warning,
                  ),
                ),
              ],
            ),

            // ── Next shift ────────────────────────────────────────────────
            if (data.nextShiftSiteName != null)
              _NextShiftCard(data: data),

            // ── Recent attendance ─────────────────────────────────────────
            if (data.recentAttendance.isNotEmpty)
              _RecentActivityList(
                items: data.recentAttendance.take(3).toList(),
              )
            else
              const StateBlock(
                icon: Icons.history_toggle_off_rounded,
                title: 'No recent attendance yet',
                message:
                    'Check-ins and check-outs will appear here once duty activity is recorded.',
              ),

            // ── Latest evaluation ─────────────────────────────────────────
            if (data.latestEvalScore != null) _EvalScore(data: data),
          ],
        );
      },
    );
  }
}

// ── Shift status card ─────────────────────────────────────────────────────────

class _ShiftStatusCard extends StatelessWidget {
  const _ShiftStatusCard({required this.data});
  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final hasShift = data.nextShiftLabel != null;

    return PortalSurfaceCard(
      accentColor: hasShift ? tokens.success : tokens.primary,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Today's duty status",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: tokens.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasShift ? (data.nextShiftSiteName ?? 'Assigned') : 'On standby',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                  ),
                ),
                if (hasShift && data.nextShiftDate != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    data.nextShiftDate!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          StatusChip(
            label: data.nextShiftLabel ?? 'Standby',
            tone: hasShift ? StatusChipTone.success : StatusChipTone.neutral,
            icon: hasShift
                ? Icons.schedule_rounded
                : Icons.pause_circle_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _PatrolStatusCard extends ConsumerWidget {
  const _PatrolStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patrolAsync = ref.watch(guardPatrolStatusProvider);
    final tokens = CissThemeTokens.of(context);

    return patrolAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        if (!status.enabled) return const SizedBox.shrink();
        final activeDuty = status.activeDuty;
        return PortalSurfaceCard(
          accentColor: status.hourlyRequirement.dueNow
              ? tokens.danger
              : tokens.primary,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GuardPatrolScreen(),
              ),
            );
          },
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Patrol monitoring',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: tokens.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeDuty == null
                          ? 'Available after duty check-in'
                          : status.hourlyRequirement.enabled
                              ? (status.hourlyRequirement.dueNow
                                  ? 'Hourly night photo due now'
                                  : 'Next photo at ${status.hourlyRequirement.nextDueAt == null ? 'scheduled time' : status.hourlyRequirement.nextDueAt!.substring(11, 16)}')
                              : '${status.patrolPoints.length} patrol point${status.patrolPoints.length == 1 ? '' : 's'} configured',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: tokens.ink,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeDuty == null
                          ? 'Open patrol after starting attendance.'
                          : '${activeDuty.siteName}${activeDuty.dutyPointName != null ? ' • ${activeDuty.dutyPointName}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: status.hourlyRequirement.dueNow ? 'Due' : 'Open',
                tone: status.hourlyRequirement.dueNow
                    ? StatusChipTone.danger
                    : StatusChipTone.success,
                icon: status.hourlyRequirement.dueNow
                    ? Icons.alarm_on_rounded
                    : Icons.route_outlined,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Quick actions grid ────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.ref, required this.context});
  final WidgetRef ref;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final tokens = CissThemeTokens.of(ctx);

    final List<_Action> actions = <_Action>[
      _Action(
        icon: Icons.fact_check_rounded,
        label: 'Attendance',
        color: tokens.primary,
        onTap: () =>
            ref.read(guardTabIndexProvider.notifier).state = 1,
      ),
      _Action(
        icon: Icons.school_rounded,
        label: 'Training',
        color: tokens.success,
        onTap: () =>
            ref.read(guardTabIndexProvider.notifier).state = 2,
      ),
      _Action(
        icon: Icons.report_gmailerrorred_rounded,
        label: 'Incident',
        color: tokens.danger,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const GuardIncidentsScreen(),
          ),
        ),
      ),
      _Action(
        icon: Icons.route_outlined,
        label: 'Patrol',
        color: tokens.accent,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const GuardPatrolScreen(),
          ),
        ),
      ),
      _Action(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Payslip',
        color: tokens.warning,
        onTap: () =>
            ref.read(guardTabIndexProvider.notifier).state = 3,
      ),
    ];

    return PortalSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      accentColor: tokens.primary,
      child: Row(
        children: actions
            .map(
              (_Action a) => Expanded(child: _ActionButton(action: a)),
            )
            .toList(),
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Next shift ────────────────────────────────────────────────────────────────

class _NextShiftCard extends StatelessWidget {
  const _NextShiftCard({required this.data});
  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return PortalSurfaceCard(
      accentColor: tokens.primary,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.event_note_rounded,
              color: tokens.primaryStrong,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.nextShiftSiteName ?? 'Upcoming duty',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: tokens.primaryStrong,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${data.nextShiftDate ?? 'Date pending'} · ${data.nextShiftLabel ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.primaryStrong.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const StatusChip(
            label: 'Upcoming',
            tone: StatusChipTone.info,
          ),
        ],
      ),
    );
  }
}

// ── Recent attendance list ────────────────────────────────────────────────────

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.items});
  final List<AttendanceRecordModel> items;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return PortalSurfaceCard(
      accentColor: tokens.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recent attendance',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((AttendanceRecordModel item) {
            final bool isIn = item.status == 'In';
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isIn ? tokens.success : tokens.warning)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      isIn ? Icons.login_rounded : Icons.logout_rounded,
                      size: 16,
                      color: isIn ? tokens.success : tokens.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item.siteName,
                      style: Theme.of(context).textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    item.dateLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Latest evaluation score ───────────────────────────────────────────────────

class _EvalScore extends StatelessWidget {
  const _EvalScore({required this.data});
  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
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
            child: Icon(Icons.stars_rounded, color: tokens.warning, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Performance score',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  data.latestEvalPeriod ?? 'Latest period',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${data.latestEvalScore}%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: tokens.warning,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
