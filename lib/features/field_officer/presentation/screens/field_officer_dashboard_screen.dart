import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/metric_tile.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../core/cache/skeleton_widgets.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../field_officer_tab_provider.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import 'live_tracking_screen.dart';

final FutureProvider<FieldOfficerDashboardSnapshot>
fieldOfficerDashboardProvider = FutureProvider<FieldOfficerDashboardSnapshot>((
  Ref ref,
) {
  return ref.watch(mobileRepositoryProvider).fetchFieldOfficerDashboard();
});

enum _DashboardPane { today, overview }

class FieldOfficerDashboardScreen extends ConsumerStatefulWidget {
  const FieldOfficerDashboardScreen({super.key});

  @override
  ConsumerState<FieldOfficerDashboardScreen> createState() =>
      _FieldOfficerDashboardScreenState();
}

class _FieldOfficerDashboardScreenState
    extends ConsumerState<FieldOfficerDashboardScreen> {
  _DashboardPane _pane = _DashboardPane.today;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FieldOfficerDashboardSnapshot> snapshot = ref.watch(
      fieldOfficerDashboardProvider,
    );
    final CissThemeTokens tokens = CissThemeTokens.of(context);

    return snapshot.when(
      loading: () => const SkeletonPage(cardCount: 5),
      error: (Object error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StateBlock(
              icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              title: 'Could not load field dashboard',
              message: CissError.parse(error),
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
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            children: <Widget>[
              BrandBanner(
                title: 'Command Dashboard',
                subtitle: '${data.name} · $districts',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SyncStatusBadge(),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => ref.invalidate(fieldOfficerDashboardProvider),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _PaneSwitch(
                      selected: _pane,
                      onSelected: (_DashboardPane next) {
                        setState(() => _pane = next);
                      },
                    ),
                    const SizedBox(height: 16),
                    _ShortcutTabs(ref: ref),
                    const SizedBox(height: 18),
                    if (_pane == _DashboardPane.today)
                      _TodayPane(data: data)
                    else
                      _OverviewPane(data: data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaneSwitch extends StatelessWidget {
  const _PaneSwitch({
    required this.selected,
    required this.onSelected,
  });

  final _DashboardPane selected;
  final ValueChanged<_DashboardPane> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_DashboardPane>(
      segments: const <ButtonSegment<_DashboardPane>>[
        ButtonSegment<_DashboardPane>(
          value: _DashboardPane.today,
          label: Text('Today'),
          icon: Icon(Icons.today_rounded, size: 16),
        ),
        ButtonSegment<_DashboardPane>(
          value: _DashboardPane.overview,
          label: Text('Overview'),
          icon: Icon(Icons.dashboard_customize_rounded, size: 16),
        ),
      ],
      selected: <_DashboardPane>{selected},
      onSelectionChanged: (Set<_DashboardPane> next) =>
          onSelected(next.first),
      showSelectedIcon: false,
    );
  }
}

class _TodayPane extends StatelessWidget {
  const _TodayPane({required this.data});

  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final FieldOfficerTodayOverview today = data.todayOverview;
    final CissThemeTokens tokens = CissThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PortalSurfaceCard(
          accentColor: today.unassignedGuards > 0
              ? tokens.warning
              : tokens.success,
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
                          'Today\'s Brief',
                          style: GoogleFonts.roboto(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${today.sitesScheduled} sites · ${today.dutiesScheduled} duties',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: today.unassignedGuards > 0 ? 'Needs Action' : 'Stable',
                    tone: today.unassignedGuards > 0
                        ? StatusChipTone.warning
                        : StatusChipTone.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _HeroStat(
                      label: 'Assigned',
                      value: '${today.assignedGuards}/${today.requiredGuards}',
                    ),
                  ),
                  Expanded(
                    child: _HeroStat(
                      label: 'Checked In',
                      value: '${data.attendanceSummary.checkedInToday}',
                    ),
                  ),
                  Expanded(
                    child: _HeroStat(
                      label: 'Pending Reports',
                      value: '${today.pendingSiteReports}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const PortalSectionHeading(title: 'Today'),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: 'Guard Gaps',
                value: '${today.unassignedGuards}',
                helper: '${today.underAssignedSites} under-assigned sites',
                icon: Icons.shield_outlined,
                accentColor: today.unassignedGuards > 0
                    ? tokens.warning
                    : tokens.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'Attendance',
                value: '${today.sitesWithoutAttendance}',
                helper: 'sites with no check-ins',
                icon: Icons.fact_check_outlined,
                accentColor: today.sitesWithoutAttendance > 0
                    ? tokens.warning
                    : tokens.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: 'Visit Reports',
                value: '${today.visitReportsToday}',
                helper: 'submitted today',
                icon: Icons.assignment_rounded,
                accentColor: tokens.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'Training Logs',
                value: '${today.trainingReportsToday}',
                helper: 'submitted today',
                icon: Icons.school_outlined,
                accentColor: tokens.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const PortalSectionHeading(title: 'Sites'),
        const SizedBox(height: 12),
        if (data.todaySites.isEmpty)
          const StateBlock(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No active site duties today',
            message:
                'Today’s site details will appear here when work orders are scheduled.',
          )
        else
          ...data.todaySites.map(_TodaySiteCard.new),
      ],
    );
  }
}

class _OverviewPane extends StatelessWidget {
  const _OverviewPane({required this.data});

  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: 'Visible Guards',
                value: '${data.totalGuards}',
                helper: '${data.activeGuards} active',
                icon: Icons.groups_2_outlined,
                accentColor: tokens.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'Sites In Scope',
                value: '${data.totalSitesInScope}',
                helper: '${data.assignedDistricts.length} districts',
                icon: Icons.map_outlined,
                accentColor: tokens.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: 'Checked In',
                value: '${data.attendanceSummary.checkedInToday}',
                helper: 'attendance logs today',
                icon: Icons.login_rounded,
                accentColor: tokens.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'On Duty',
                value: '${data.attendanceSummary.onDutyNow}',
                helper: 'latest live status',
                icon: Icons.badge_outlined,
                accentColor: tokens.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const PortalSectionHeading(title: 'District Coverage'),
        const SizedBox(height: 12),
        PortalSurfaceCard(
          child: data.attendanceSummary.districts.isEmpty
              ? Text(
                  'No district attendance has been logged yet today.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.inkMuted,
                  ),
                )
              : Column(
                  children: data.attendanceSummary.districts
                      .map(
                        (FieldOfficerDistrictAttendance district) =>
                            _DistrictCoverageLine(district: district),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 20),
        const PortalSectionHeading(title: 'Recent Activity'),
        const SizedBox(height: 12),
        _RecentOverviewCard(data: data),
      ],
    );
  }
}

class _ShortcutTabs extends StatelessWidget {
  const _ShortcutTabs({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);
    final List<_ShortcutAction> shortcuts = <_ShortcutAction>[
      _ShortcutAction('Orders', Icons.assignment_turned_in_rounded, 1),
      _ShortcutAction('Guards', Icons.groups_2_rounded, 2),
      _ShortcutAction('Attendance', Icons.fact_check_rounded, 3),
      _ShortcutAction('Reports', Icons.edit_note_rounded, 4),
      _ShortcutAction('More', Icons.grid_view_rounded, 5),
    ];

    // Add live tracking shortcut
    final liveAction = _ShortcutAction(
      'Live Track',
      Icons.my_location_rounded,
      -1,
    );

    final allShortcuts = [...shortcuts, liveAction];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: allShortcuts
            .map(
              (_ShortcutAction action) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ActionChip(
                  avatar: Icon(
                    action.icon,
                    size: 18,
                    color: action.tabIndex == -1
                        ? tokens.success
                        : tokens.primaryStrong,
                  ),
                  label: Text(action.label),
                  backgroundColor: tokens.surface,
                  side: BorderSide(
                    color: action.tabIndex == -1
                        ? tokens.success.withValues(alpha: 0.4)
                        : tokens.border,
                  ),
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: () {
                    if (action.tabIndex == -1) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LiveTrackingScreen(),
                        ),
                      );
                    } else {
                      ref.read(fieldOfficerTabIndexProvider.notifier).state =
                          action.tabIndex;
                    }
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShortcutAction {
  const _ShortcutAction(this.label, this.icon, this.tabIndex);

  final String label;
  final IconData icon;
  final int tabIndex;
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: tokens.ink,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tokens.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _TodaySiteCard extends StatelessWidget {
  const _TodaySiteCard(this.site);

  final FieldOfficerTodaySiteBrief site;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);
    final bool fullyAssigned = site.assignedGuards >= site.requiredGuards;
    final bool hasAttendance = site.checkedInToday > 0;
    final bool hasReport = site.hasVisitReport || site.hasTrainingReport;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PortalSurfaceCard(
        accentColor: fullyAssigned ? tokens.success : tokens.warning,
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
                        site.siteName.isEmpty ? 'Site' : site.siteName,
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (site.clientName.isNotEmpty) site.clientName,
                          if (site.district.isNotEmpty) site.district,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: fullyAssigned ? 'Covered' : 'Pending',
                  tone: fullyAssigned
                      ? StatusChipTone.success
                      : StatusChipTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniMetric(
                    label: 'Duty',
                    value: '${site.dutyCount}',
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: 'Guards',
                    value: '${site.assignedGuards}/${site.requiredGuards}',
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: 'Check-ins',
                    value: '${site.checkedInToday}',
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: 'Live',
                    value: '${site.onDutyNow}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                StatusChip(
                  label: hasAttendance ? 'Attendance in' : 'No attendance',
                  tone: hasAttendance
                      ? StatusChipTone.success
                      : StatusChipTone.warning,
                ),
                StatusChip(
                  label: hasReport ? 'Report filed' : 'Report pending',
                  tone: hasReport
                      ? StatusChipTone.info
                      : StatusChipTone.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: tokens.ink,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tokens.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _DistrictCoverageLine extends StatelessWidget {
  const _DistrictCoverageLine({required this.district});

  final FieldOfficerDistrictAttendance district;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              district.district.isEmpty ? 'District' : district.district,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tokens.ink,
              ),
            ),
          ),
          Text(
            '${district.checkedInToday} checked in',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(
            label: '${district.onDutyNow} live',
            tone: StatusChipTone.info,
          ),
        ],
      ),
    );
  }
}

class _RecentOverviewCard extends StatelessWidget {
  const _RecentOverviewCard({required this.data});

  final FieldOfficerDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);

    return PortalSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RecentLine(
            label: 'Upcoming work orders',
            value: '${data.upcomingWorkOrders.length}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _RecentLine(
            label: 'Recent visit reports',
            value: '${data.recentVisitReports.length}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _RecentLine(
            label: 'Recent training reports',
            value: '${data.recentTrainingReports.length}',
          ),
          if (data.recentWorkOrders.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              data.recentWorkOrders.first.siteName.isEmpty
                  ? 'Latest site update available'
                  : 'Latest: ${data.recentWorkOrders.first.siteName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentLine extends StatelessWidget {
  const _RecentLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final CissThemeTokens tokens = CissThemeTokens.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.ink,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: tokens.primaryStrong,
          ),
        ),
      ],
    );
  }
}
