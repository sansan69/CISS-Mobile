import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/brand_banner.dart';
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

class FieldOfficerDashboardScreen extends ConsumerWidget {
  const FieldOfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(fieldOfficerDashboardProvider);
    final tokens = CissThemeTokens.of(context);

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
      data: (FieldOfficerDashboardSnapshot data) {
        final String districts = data.assignedDistricts.isEmpty
            ? 'No district assigned'
            : data.assignedDistricts.join(', ');

        return Scaffold(
          backgroundColor: tokens.canvas,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
            children: <Widget>[
              BrandBanner(
                title: 'Command Center',
                subtitle: '${data.name} · $districts',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SyncStatusBadge(),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => ref.invalidate(fieldOfficerDashboardProvider),
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Command Tiles
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: <Widget>[
                    _CommandTile(
                      label: 'Total Guards',
                      value: '${data.totalGuards}',
                      icon: Icons.groups_2_rounded,
                      accentColor: tokens.primary,
                      helper: 'Registered in $districts',
                    ),
                    const SizedBox(width: 12),
                    _DeploymentTile(
                      active: data.activeGuards,
                      total: data.totalGuards,
                      accentColor: tokens.success,
                    ),
                    const SizedBox(width: 12),
                    _CommandTile(
                      label: 'Check-ins',
                      value: '${data.attendanceSummary.checkedInToday}',
                      icon: Icons.login_rounded,
                      accentColor: tokens.accent,
                      helper: 'Today\'s total activity',
                    ),
                    const SizedBox(width: 12),
                    _ComplianceTile(
                      checkedIn: data.attendanceSummary.checkedInToday,
                      onDuty: data.totalGuards,
                      accentColor: tokens.warning,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'OPERATIONS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: tokens.inkMuted,
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _QuickActionsGrid(ref: ref),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AttendanceOverview(data: data),
              ),

              if (data.recentVisitReports.isNotEmpty ||
                  data.recentTrainingReports.isNotEmpty ||
                  data.recentWorkOrders.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PendingReportsSummary(data: data),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      accentColor: accentColor,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const Spacer(),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.inkMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              helper,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.inkMuted,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeploymentTile extends StatelessWidget {
  const _DeploymentTile({
    required this.active,
    required this.total,
    required this.accentColor,
  });

  final int active;
  final int total;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final double progress = total <= 0 ? 0.0 : (active / total).clamp(0, 1);
    final int percent = (progress * 100).toInt();

    return GlassCard(
      accentColor: accentColor,
      child: SizedBox(
        width: 160,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEPLOYMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkMuted,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$active of $total on duty',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.inkMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 6,
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    color: accentColor,
                    strokeCap: StrokeCap.round,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final List<_QuickAction> actions = <_QuickAction>[
      _QuickAction(
        label: 'Work Orders',
        icon: Icons.assignment_turned_in_rounded,
        color: tokens.primary,
        tabIndex: 1,
      ),
      _QuickAction(
        label: 'Guards',
        icon: Icons.groups_2_rounded,
        color: tokens.success,
        tabIndex: 2,
      ),
      _QuickAction(
        label: 'Visit Report',
        icon: Icons.fact_check_rounded,
        color: tokens.warning,
        tabIndex: 4,
      ),
      _QuickAction(
        label: 'Training',
        icon: Icons.school_rounded,
        color: tokens.accent,
        tabIndex: 4,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: actions.map((action) => _ActionCard(action: action, ref: ref)).toList(),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.tabIndex,
  });
  final String label;
  final IconData icon;
  final Color color;
  final int tabIndex;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.ref});
  final _QuickAction action;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(fieldOfficerTabIndexProvider.notifier).state = action.tabIndex,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          accentColor: action.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: tokens.inkMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceOverview extends ConsumerWidget {
  const _AttendanceOverview({required this.data});
  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final districts = data.attendanceSummary.districts;
    final sites = data.attendanceSites;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTENDANCE FEED',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: tokens.inkMuted,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Coverage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tokens.ink,
                            ),
                          ),
                          Text(
                            data.attendanceSummary.date.isEmpty ? 'Today' : data.attendanceSummary.date,
                            style: theme.textTheme.bodySmall,
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
              ),
              Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    if (districts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Waiting for morning check-ins...',
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      ...districts.map((d) => _ProgressLine(
                        label: d.district,
                        checkedIn: d.checkedInToday,
                        onDuty: d.onDutyNow,
                        accentColor: tokens.primary,
                      )),
                    
                    if (sites.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...sites.take(3).map((s) => _ProgressLine(
                        label: s.siteName,
                        sublabel: s.clientName,
                        checkedIn: s.checkedInToday,
                        onDuty: s.onDutyNow,
                        accentColor: tokens.success,
                      )),
                    ],
                  ],
                ),
              ),
              if (sites.length > 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextButton(
                    onPressed: () => ref.read(fieldOfficerTabIndexProvider.notifier).state = 3,
                    child: Text(
                      'View all ${sites.length} sites',
                      style: TextStyle(fontWeight: FontWeight.w700, color: tokens.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
    final double p = checkedIn <= 0 ? 0 : (onDuty / checkedIn).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.inkMuted),
                      ),
                  ],
                ),
              ),
              Text(
                '$onDuty / $checkedIn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
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

class _ComplianceTile extends StatelessWidget {
  const _ComplianceTile({
    required this.checkedIn,
    required this.onDuty,
    required this.accentColor,
  });

  final int checkedIn;
  final int onDuty;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final double progress =
        onDuty <= 0 ? 0.0 : (checkedIn / onDuty).clamp(0, 1);
    final int percent = (progress * 100).toInt();

    return GlassCard(
      accentColor: accentColor,
      child: SizedBox(
        width: 160,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMPLIANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkMuted,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$checkedIn of $onDuty present',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.inkMuted,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 6,
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    color: accentColor,
                    strokeCap: StrokeCap.round,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingReportsSummary extends StatelessWidget {
  const _PendingReportsSummary({required this.data});

  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);

    final int pendingOrders =
        data.recentWorkOrders.where((w) => w.assignedCount < w.totalManpower).length;
    final int pendingVisits =
        data.recentVisitReports.where((r) => r.status == 'draft').length;
    final int pendingTraining =
        data.recentTrainingReports.where((r) => r.status == 'draft').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PENDING REPORTS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: tokens.inkMuted,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (data.recentWorkOrders.isNotEmpty) ...[
                _ReportRow(
                  icon: Icons.assignment_late_rounded,
                  label: 'Work Orders',
                  count: data.recentWorkOrders.length,
                  accent: tokens.primary,
                  subtitle: pendingOrders > 0
                      ? '$pendingOrders need staffing'
                      : 'All staffed',
                ),
              ],
              if (data.recentVisitReports.isNotEmpty) ...[
                if (data.recentWorkOrders.isNotEmpty)
                  Divider(
                    height: 1,
                    color: tokens.border.withValues(alpha: 0.3),
                  ),
                _ReportRow(
                  icon: Icons.fact_check_rounded,
                  label: 'Visit Reports',
                  count: data.recentVisitReports.length,
                  accent: tokens.warning,
                  subtitle: pendingVisits > 0
                      ? '$pendingVisits drafts pending'
                      : 'All submitted',
                ),
              ],
              if (data.recentTrainingReports.isNotEmpty) ...[
                if (data.recentWorkOrders.isNotEmpty ||
                    data.recentVisitReports.isNotEmpty)
                  Divider(
                    height: 1,
                    color: tokens.border.withValues(alpha: 0.3),
                  ),
                _ReportRow(
                  icon: Icons.school_rounded,
                  label: 'Training Reports',
                  count: data.recentTrainingReports.length,
                  accent: tokens.success,
                  subtitle: pendingTraining > 0
                      ? '$pendingTraining drafts pending'
                      : 'All submitted',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.inkMuted,
                      ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: '$count',
            tone: StatusChipTone.info,
          ),
        ],
      ),
    );
  }
}
