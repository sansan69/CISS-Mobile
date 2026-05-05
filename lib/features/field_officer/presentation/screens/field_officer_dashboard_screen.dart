import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/metric_tile.dart';
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
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              return switch (index) {
                0 => BrandBanner(
                    title: 'Dashboard',
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
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                1 => _StatGrid(data: data),
                2 => _QuickActionsGrid(ref: ref),
                3 => _AttendanceCard(data: data),
                _ => const SizedBox.shrink(),
              };
            },
          ),
        );
      },
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.data});
  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: 'Total Guards',
                value: '${data.totalGuards}',
                helper: 'Registered in districts',
                icon: Icons.groups_2_outlined,
                accentColor: tokens.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'Active Guards',
                value: '${data.activeGuards}',
                helper: 'Currently deployed',
                icon: Icons.verified_outlined,
                accentColor: tokens.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        MetricTile(
          label: 'Checked In Today',
          value: '${data.attendanceSummary.checkedInToday}',
          helper: 'Attendance recorded today',
          icon: Icons.login_rounded,
          accentColor: tokens.accent,
        ),
      ],
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

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              _QuickActionTile(
                action: actions[0],
                onTap: () => ref
                    .read(fieldOfficerTabIndexProvider.notifier)
                    .state = actions[0].tabIndex,
              ),
              const SizedBox(height: AppSpacing.sm),
              _QuickActionTile(
                action: actions[2],
                onTap: () => ref
                    .read(fieldOfficerTabIndexProvider.notifier)
                    .state = actions[2].tabIndex,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            children: <Widget>[
              _QuickActionTile(
                action: actions[1],
                onTap: () => ref
                    .read(fieldOfficerTabIndexProvider.notifier)
                    .state = actions[1].tabIndex,
              ),
              const SizedBox(height: AppSpacing.sm),
              _QuickActionTile(
                action: actions[3],
                onTap: () => ref
                    .read(fieldOfficerTabIndexProvider.notifier)
                    .state = actions[3].tabIndex,
              ),
            ],
          ),
        ),
      ],
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});
  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: action.color.withValues(alpha: 0.5),
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(action.icon, color: action.color, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    action.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: tokens.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: tokens.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.data});
  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final districts = data.attendanceSummary.districts;
    final sites = data.attendanceSites;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md - 1),
              ),
              gradient: LinearGradient(
                colors: <Color>[tokens.primaryStrong, tokens.primary],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tokens.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.fact_check_outlined,
                        color: tokens.primaryStrong,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Attendance overview',
                              style: theme.textTheme.titleSmall),
                          Text(
                            data.attendanceSummary.date.isEmpty
                                ? 'Today'
                                : data.attendanceSummary.date,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: data.stateCode.isEmpty ? 'Live' : data.stateCode,
                      icon: Icons.radar_rounded,
                      tone: StatusChipTone.info,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (districts.isEmpty)
                  Text(
                    'Attendance will appear once guards check in today.',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  ...districts.map(
                    (d) => _ProgressLine(
                      label: d.district,
                      checkedIn: d.checkedInToday,
                      onDuty: d.onDutyNow,
                    ),
                  ),
                if (sites.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Divider(color: tokens.border, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Active sites',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.inkMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...sites.map(
                    (s) => _ProgressLine(
                      label: s.siteName.isEmpty ? 'Site' : s.siteName,
                      sublabel: s.district,
                      checkedIn: s.checkedInToday,
                      onDuty: s.onDutyNow,
                    ),
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

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.checkedIn,
    required this.onDuty,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final int checkedIn;
  final int onDuty;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final double p =
        checkedIn <= 0 ? 0 : (onDuty / checkedIn).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                      label.isEmpty ? 'Unassigned' : label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tokens.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sublabel != null && sublabel!.isNotEmpty)
                      Text(
                        sublabel!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                '$onDuty on duty · $checkedIn in',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: p,
              backgroundColor: tokens.primarySoft,
              valueColor:
                  AlwaysStoppedAnimation<Color>(tokens.primaryStrong),
            ),
          ),
        ],
      ),
    );
  }
}
