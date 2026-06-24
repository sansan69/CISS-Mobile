import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/haptics.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/dashboard/activity_feed.dart';
import '../../../../../shared/widgets/dashboard/dashboard_header.dart';
import '../../../../../shared/widgets/dashboard/quick_action_bar.dart';
import '../../../../../shared/widgets/dashboard/stat_pill_row.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../field_officer_tab_provider.dart';

final FutureProvider<FieldOfficerDashboardSnapshot>
    fieldOfficerDashboardProvider = FutureProvider<FieldOfficerDashboardSnapshot>((
  Ref ref,
) {
  return ref.read(mobileRepositoryProvider).fetchFieldOfficerDashboard();
});

/// Field Officer dashboard redesigned for command-center clarity.
///
/// Layout (top to bottom):
/// 1. Header — greeting + name + district badge
/// 2. Stat pills — total guards, active/on-duty, check-ins today
/// 3. Quick actions — orders, guards, attendance, reports, alerts
/// 4. Attendance coverage — district/site progress bars
/// 5. Pending items — work orders, visit reports, training (if any)
class FieldOfficerDashboardScreen extends ConsumerWidget {
  const FieldOfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(fieldOfficerDashboardProvider);

    return snapshot.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StateBlock(
              icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              title: 'Could not load field dashboard',
              message: error.toString().replaceFirst('Exception: ', ''),
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(fieldOfficerDashboardProvider),
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      ),
      data: (FieldOfficerDashboardSnapshot data) => _DashboardBody(data: data),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    final districts = data.assignedDistricts.isEmpty
        ? 'No district assigned'
        : data.assignedDistricts.join(', ');

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final summary = data.attendanceSummary;
    final checkedIn = summary.checkedInToday;
    final onDuty = summary.onDutyNow;
    final coverage = checkedIn <= 0
        ? 0.0
        : (onDuty / checkedIn).clamp(0, 1).toDouble();

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            Haptics.medium();
            ref.invalidate(fieldOfficerDashboardProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.sm,
              0,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              // Top bar: sync + refresh
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    const SyncStatusBadge(),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () =>
                          ref.invalidate(fieldOfficerDashboardProvider),
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: tokens.inkMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // 1. Header
              DashboardHeader(
                greeting: greeting,
                name: data.name,
                subtitle: districts,
              ),

              const SizedBox(height: AppSpacing.lg),

              // 2. Stat pills
              StatPillRow(
                pills: <StatPill>[
                  StatPill(
                    label: 'Total Guards',
                    value: '${data.totalGuards}',
                    accentColor: tokens.primary,
                    icon: Icons.groups_2_rounded,
                  ),
                  StatPill(
                    label: 'On Duty',
                    value: '$onDuty',
                    accentColor: tokens.success,
                    icon: Icons.radio_button_checked_rounded,
                  ),
                  StatPill(
                    label: 'Check-ins',
                    value: '$checkedIn',
                    accentColor: tokens.accent,
                    icon: Icons.login_rounded,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // 3. Quick actions
              QuickActionBar(
                actions: <QuickAction>[
                  QuickAction(
                    icon: Icons.assignment_turned_in_rounded,
                    label: 'Orders',
                    color: tokens.primary,
                    onTap: () => ref
                        .read(fieldOfficerTabIndexProvider.notifier)
                        .state = 1,
                  ),
                  QuickAction(
                    icon: Icons.groups_2_rounded,
                    label: 'Guards',
                    color: tokens.success,
                    onTap: () => ref
                        .read(fieldOfficerTabIndexProvider.notifier)
                        .state = 2,
                  ),
                  QuickAction(
                    icon: Icons.fact_check_rounded,
                    label: 'Attendance',
                    color: tokens.warning,
                    onTap: () => ref
                        .read(fieldOfficerTabIndexProvider.notifier)
                        .state = 3,
                  ),
                  QuickAction(
                    icon: Icons.edit_note_rounded,
                    label: 'Reports',
                    color: tokens.accent,
                    onTap: () => ref
                        .read(fieldOfficerTabIndexProvider.notifier)
                        .state = 4,
                  ),
                  QuickAction(
                    icon: Icons.notifications_active_rounded,
                    label: 'Alerts',
                    color: tokens.danger,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // 4. Attendance coverage
              _AttendanceCoverage(
                data: data,
                coverage: coverage,
                onViewAll: () => ref
                    .read(fieldOfficerTabIndexProvider.notifier)
                    .state = 3,
              ),

              const SizedBox(height: AppSpacing.xl),

              // 5. Pending items (if any)
              if (data.recentWorkOrders.isNotEmpty ||
                  data.recentVisitReports.isNotEmpty ||
                  data.recentTrainingReports.isNotEmpty)
                _PendingItems(data: data),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Attendance coverage section ──────────────────────────────────────────────

class _AttendanceCoverage extends StatelessWidget {
  const _AttendanceCoverage({
    required this.data,
    required this.coverage,
    this.onViewAll,
  });

  final FieldOfficerDashboardSnapshot data;
  final double coverage;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final summary = data.attendanceSummary;
    final districts = summary.districts;
    final sites = data.attendanceSites;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Attendance coverage',
                style: AppTypography.title(context).copyWith(fontSize: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${(coverage * 100).toInt()}%',
                  style: AppTypography.label(context).copyWith(
                    color: tokens.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Daily Coverage',
                              style: AppTypography.cardTitle(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.date.isEmpty
                                  ? 'Today'
                                  : summary.date,
                              style: AppTypography.micro(context).copyWith(
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: data.stateCode.isEmpty
                            ? 'LIVE'
                            : data.stateCode,
                        icon: Icons.radar_rounded,
                        tone: StatusChipTone.info,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: tokens.border.withValues(alpha: 0.3),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: <Widget>[
                      if (districts.isEmpty)
                        Text(
                          'Waiting for morning check-ins...',
                          style: AppTypography.body(context).copyWith(
                            fontStyle: FontStyle.italic,
                            color: tokens.inkMuted,
                          ),
                        )
                      else
                        ...districts.map(
                          (d) => _ProgressLine(
                            label: d.district,
                            checkedIn: d.checkedInToday,
                            onDuty: d.onDutyNow,
                            accentColor: tokens.primary,
                          ),
                        ),
                      if (sites.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Divider(
                          height: 1,
                          color: tokens.border.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...sites.take(3).map(
                          (s) => _ProgressLine(
                            label: s.siteName,
                            sublabel: s.clientName,
                            checkedIn: s.checkedInToday,
                            onDuty: s.onDutyNow,
                            accentColor: tokens.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (sites.length > 3 && onViewAll != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextButton(
                      onPressed: onViewAll,
                      child: Text(
                        'View all ${sites.length} sites',
                        style: AppTypography.bodyStrong(context).copyWith(
                          color: tokens.primary,
                          fontSize: 13,
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

// ── Pending items ────────────────────────────────────────────────────────────

class _PendingItems extends StatelessWidget {
  const _PendingItems({required this.data});

  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final pendingOrders = data.recentWorkOrders
        .where((w) => w.assignedCount < w.totalManpower)
        .length;
    final pendingVisits = data.recentVisitReports
        .where((r) => r.status == 'draft')
        .length;
    final pendingTraining = data.recentTrainingReports
        .where((r) => r.status == 'draft')
        .length;

    final items = <ActivityItem>[];

    if (data.recentWorkOrders.isNotEmpty) {
      items.add(
        ActivityItem(
          icon: Icons.assignment_late_rounded,
          iconColor: tokens.primary,
          iconBgColor: tokens.primarySoft,
          title: 'Work Orders',
          subtitle: pendingOrders > 0
              ? '$pendingOrders need staffing'
              : 'All staffed',
          trailing: '${data.recentWorkOrders.length}',
        ),
      );
    }

    if (data.recentVisitReports.isNotEmpty) {
      items.add(
        ActivityItem(
          icon: Icons.fact_check_rounded,
          iconColor: tokens.warning,
          iconBgColor: tokens.warningSoft,
          title: 'Visit Reports',
          subtitle: pendingVisits > 0
              ? '$pendingVisits drafts pending'
              : 'All submitted',
          trailing: '${data.recentVisitReports.length}',
        ),
      );
    }

    if (data.recentTrainingReports.isNotEmpty) {
      items.add(
        ActivityItem(
          icon: Icons.school_rounded,
          iconColor: tokens.success,
          iconBgColor: tokens.successSoft,
          title: 'Training Reports',
          subtitle: pendingTraining > 0
              ? '$pendingTraining drafts pending'
              : 'All submitted',
          trailing: '${data.recentTrainingReports.length}',
        ),
      );
    }

    return ActivityFeed(
      title: 'Pending items',
      items: items,
    );
  }
}

// ── Progress line widget ─────────────────────────────────────────────────────

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.checkedIn,
    required this.onDuty,
    required this.accentColor,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final int checkedIn;
  final int onDuty;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final p = checkedIn <= 0
        ? 0.0
        : (onDuty / checkedIn).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: AppTypography.bodyStrong(context).copyWith(
                        color: tokens.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        style: AppTypography.micro(context).copyWith(
                          color: tokens.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$onDuty / $checkedIn',
                style: AppTypography.bodyStrong(context).copyWith(
                  color: accentColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: p,
              backgroundColor: accentColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
