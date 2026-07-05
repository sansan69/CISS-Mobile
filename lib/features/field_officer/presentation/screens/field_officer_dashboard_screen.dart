import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/haptics.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/modern_hero.dart';
import '../../../../../shared/widgets/metric_card.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../field_officer_tab_provider.dart';

final FutureProvider<FieldOfficerDashboardSnapshot>
    fieldOfficerDashboardProvider = FutureProvider<FieldOfficerDashboardSnapshot>((
  Ref ref,
) {
  return ref.read(mobileRepositoryProvider).fetchFieldOfficerDashboard();
});

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
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl + 80),
            children: <Widget>[
              ModernHero(
                eyebrow: 'Field Officer',
                title: greeting,
                subtitle: districts,
                avatarText: data.name.isNotEmpty
                    ? data.name.substring(0, 1).toUpperCase()
                    : 'FO',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SyncStatusBadge(),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () =>
                          ref.invalidate(fieldOfficerDashboardProvider),
                      icon: Icon(Icons.refresh_rounded,
                          color: tokens.surface, size: 20),
                    ),
                  ],
                ),
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
                        label: 'My Guards',
                        value: '${data.totalGuards}',
                        color: tokens.primary,
                        backgroundColor: tokens.primarySoft,
                        width: 140,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      MetricCard(
                        label: 'On Duty',
                        value: '$onDuty',
                        color: tokens.success,
                        backgroundColor: tokens.successSoft,
                        width: 140,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      MetricCard(
                        label: 'Check-ins',
                        value: '$checkedIn',
                        color: tokens.accent,
                        backgroundColor: tokens.warningSoft,
                        width: 140,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _QuickActionChip(
                        icon: Icons.assignment_turned_in_rounded,
                        label: 'Orders',
                        color: tokens.primary,
                        onTap: () => _navigateToDuties(ref, 0),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _QuickActionChip(
                        icon: Icons.groups_2_rounded,
                        label: 'Guards',
                        color: tokens.success,
                        onTap: () => _navigateToDuties(ref, 1),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _QuickActionChip(
                        icon: Icons.fact_check_rounded,
                        label: 'Attendance',
                        color: tokens.warning,
                        onTap: () => _navigateToDuties(ref, 2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _QuickActionChip(
                        icon: Icons.edit_note_rounded,
                        label: 'Reports',
                        color: tokens.accent,
                        onTap: () => ref
                            .read(fieldOfficerTabIndexProvider.notifier)
                            .state = 2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Attendance Coverage
              _AttendanceCoverage(
                data: data,
                coverage: coverage,
                onViewAll: () => _navigateToDuties(ref, 2),
              ),

              // Pending Items
              if (data.recentWorkOrders.isNotEmpty ||
                  data.recentVisitReports.isNotEmpty ||
                  data.recentTrainingReports.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _PendingItems(data: data),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: tokens.success,
        foregroundColor: tokens.surface,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Report'),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _navigateToDuties(WidgetRef ref, int subIndex) {
  ref.read(fieldOfficerTabIndexProvider.notifier).state = 1;
  ref.read(fieldOfficerDutiesSubIndexProvider.notifier).state = subIndex;
}

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
                'Attendance Coverage',
                style: AppTypography.title(context),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${(coverage * 100).toInt()}%',
                  style: AppTypography.label(context).copyWith(
                    color: tokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ModernCard(
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
                            'Daily Coverage',
                            style: AppTypography.cardTitle(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summary.date.isEmpty ? 'Today' : summary.date,
                            style: AppTypography.micro(context).copyWith(
                              color: tokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: data.stateCode.isEmpty ? 'LIVE' : data.stateCode,
                      icon: Icons.radar_rounded,
                      tone: StatusChipTone.info,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
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
                if (sites.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: tokens.border),
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
                if (sites.length > 3 && onViewAll != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
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

class _PendingItems extends StatelessWidget {
  const _PendingItems({required this.data});

  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final pendingOrders = data.recentWorkOrders
        .where((w) => w.assignedCount < w.totalManpower)
        .length;
    final pendingVisits =
        data.recentVisitReports.where((r) => r.status == 'draft').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Pending Items', style: AppTypography.title(context)),
          const SizedBox(height: AppSpacing.md),
          ModernCard(
            child: Column(
              children: <Widget>[
                if (data.recentWorkOrders.isNotEmpty)
                  _PendingRow(
                    icon: Icons.assignment_late_rounded,
                    iconColor: tokens.primary,
                    iconBgColor: tokens.primarySoft,
                    title: 'Work Orders',
                    subtitle: pendingOrders > 0
                        ? '$pendingOrders need staffing'
                        : 'All staffed',
                    count: '${data.recentWorkOrders.length}',
                  ),
                if (data.recentVisitReports.isNotEmpty) ...[
                  if (data.recentWorkOrders.isNotEmpty)
                    Divider(height: 1, color: tokens.border),
                  _PendingRow(
                    icon: Icons.fact_check_rounded,
                    iconColor: tokens.warning,
                    iconBgColor: tokens.warningSoft,
                    title: 'Visit Reports',
                    subtitle: pendingVisits > 0
                        ? '$pendingVisits drafts pending'
                        : 'All submitted',
                    count: '${data.recentVisitReports.length}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String count;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTypography.bodyStrong(context)),
                Text(
                  subtitle,
                  style: AppTypography.micro(context).copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            count,
            style: AppTypography.metric(context).copyWith(
              fontSize: 20,
              color: tokens.primary,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final p = checkedIn <= 0 ? 0.0 : (onDuty / checkedIn).clamp(0, 1).toDouble();

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
                      style: AppTypography.bodyStrong(context),
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
