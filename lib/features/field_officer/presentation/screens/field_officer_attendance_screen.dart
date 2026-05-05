import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/metric_tile.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import 'field_officer_dashboard_screen.dart';

final StateProvider<String?> attendanceSelectedDateProvider =
    StateProvider<String?>((Ref ref) => null);

final FutureProvider<List<FieldOfficerAttendanceEntry>>
fieldOfficerGuardAttendanceProvider =
    FutureProvider<List<FieldOfficerAttendanceEntry>>((Ref ref) {
  final date = ref.watch(attendanceSelectedDateProvider);
  return ref
      .read(mobileRepositoryProvider)
      .fetchFieldOfficerGuardAttendance(date: date);
});

class FieldOfficerGuardAttendanceScreen extends ConsumerStatefulWidget {
  const FieldOfficerGuardAttendanceScreen({super.key});

  @override
  ConsumerState<FieldOfficerGuardAttendanceScreen> createState() =>
      _FieldOfficerGuardAttendanceScreenState();
}

class _FieldOfficerGuardAttendanceScreenState
    extends ConsumerState<FieldOfficerGuardAttendanceScreen> {
  DateTime? _selectedDate;
  String? _selectedClient;
  static final DateFormat _displayFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  void _refresh() {
    ref
      ..invalidate(fieldOfficerDashboardProvider)
      ..invalidate(fieldOfficerGuardAttendanceProvider);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      ref.read(attendanceSelectedDateProvider.notifier).state =
          _apiFmt.format(picked);
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    ref.read(attendanceSelectedDateProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(fieldOfficerDashboardProvider);
    final entriesAsync = ref.watch(fieldOfficerGuardAttendanceProvider);

    return ScreenScaffold(
      title: 'Guard Attendance',
      subtitle: _selectedDate != null ? _displayFmt.format(_selectedDate!) : 'Today\'s check-in status',
      actions: <Widget>[
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
      ],
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(_selectedDate != null ? _displayFmt.format(_selectedDate!) : 'Pick date'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ),
            if (_selectedDate != null) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: _clearDate,
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(backgroundColor: CissThemeTokens.of(context).surfaceStrong),
              ),
            ],
          ],
        ),
        dashboardAsync.when(
          loading: () => const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox.shrink(),
          data: (dashboard) {
            if (dashboard.attendanceSites.isEmpty && dashboard.attendanceSummary.districts.isEmpty) {
              return const StateBlock(
                icon: Icons.event_busy_outlined,
                title: 'No attendance data',
                message: 'Records will appear once guards check in today.',
              );
            }
            return _buildAttendanceContent(dashboard, entriesAsync);
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceContent(
    FieldOfficerDashboardSnapshot dashboard,
    AsyncValue<List<FieldOfficerAttendanceEntry>> entriesAsync,
  ) {
    final tokens = CissThemeTokens.of(context);
    var sites = dashboard.attendanceSites;

    final clientNames = sites
        .map((s) => s.clientName)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (_selectedClient != null) {
      sites = sites.where((s) => s.clientName == _selectedClient).toList();
    }

    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: 'On duty now',
                value: '${dashboard.attendanceSummary.onDutyNow}',
                helper: 'Currently checked in',
                icon: Icons.verified_outlined,
                accentColor: tokens.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'Checked in today',
                value: '${dashboard.attendanceSummary.checkedInToday}',
                helper: 'Total check-ins',
                icon: Icons.login_rounded,
                accentColor: tokens.primary,
              ),
            ),
          ],
        ),
        if (clientNames.length > 1) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                FilterChip(
                  label: const Text('All clients'),
                  selected: _selectedClient == null,
                  onSelected: (_) => setState(() => _selectedClient = null),
                  showCheckmark: false,
                ),
                const SizedBox(width: AppSpacing.xs),
                ...clientNames.map((c) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: Text(c),
                    selected: c == _selectedClient,
                    onSelected: (_) => setState(() => _selectedClient = c == _selectedClient ? null : c),
                    showCheckmark: false,
                  ),
                )),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        entriesAsync.when(
          loading: () => const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),
          error: (_, _) {
            if (sites.isEmpty) return const SizedBox.shrink();
            return Column(children: _buildSiteCards(sites));
          },
          data: (entries) {
            var filteredEntries = entries;
            if (_selectedClient != null) {
              filteredEntries = entries
                  .where((e) => e.clientName == _selectedClient || (_selectedClient == 'General' && e.clientName.isEmpty))
                  .toList();
            }

            if (sites.isEmpty && filteredEntries.isEmpty) return const SizedBox.shrink();
            return Column(
              children: <Widget>[
                if (sites.isNotEmpty) ..._buildSiteCards(sites, entries: filteredEntries),
                if (filteredEntries.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  ..._buildEntryCards(filteredEntries),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _showSiteGuards(FieldOfficerAttendanceSite site, List<FieldOfficerAttendanceEntry> entries) {
    if (!mounted) return;
    final siteEntries = entries.where((e) => e.siteName == site.siteName).toList();
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (_, controller) => Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: tokens.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                  ),
                  Text(site.siteName.isEmpty ? 'Unnamed site' : site.siteName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (site.clientName.isNotEmpty || site.district.isNotEmpty)
                    Text(
                      [if (site.clientName.isNotEmpty) site.clientName, if (site.district.isNotEmpty) site.district].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.inkMuted),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.border),
            if (siteEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(
                  child: Text('No individual records available for this site.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: siteEntries.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: AppSpacing.lg, color: tokens.border),
                  itemBuilder: (_, int i) => _GuardRow(entry: siteEntries[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSiteCards(List<FieldOfficerAttendanceSite> sites, {List<FieldOfficerAttendanceEntry>? entries}) {
    final tokens = CissThemeTokens.of(context);
    return sites.map((site) {
      final p = site.checkedInToday <= 0 ? 0.0 : (site.onDutyNow / site.checkedInToday).clamp(0, 1).toDouble();
      final bool tappable = entries != null;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tappable ? () => _showSiteGuards(site, entries) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md - 1)),
                    gradient: LinearGradient(colors: <Color>[tokens.primaryStrong, tokens.primary]),
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
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: tokens.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                            child: Icon(Icons.apartment_rounded, color: tokens.primaryStrong, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(site.siteName.isEmpty ? 'Unnamed site' : site.siteName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                if (site.clientName.isNotEmpty || site.district.isNotEmpty)
                                  Text(
                                    [if (site.clientName.isNotEmpty) site.clientName, if (site.district.isNotEmpty) site.district].join(' · '),
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          StatusChip(
                            label: '${site.onDutyNow}/${site.checkedInToday}',
                            icon: Icons.people_outline_rounded,
                            tone: site.onDutyNow >= site.checkedInToday ? StatusChipTone.success : StatusChipTone.info,
                          ),
                          if (tappable) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(Icons.chevron_right_rounded, size: 18, color: tokens.inkMuted),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 5, value: p,
                          backgroundColor: tokens.primarySoft,
                          valueColor: AlwaysStoppedAnimation<Color>(tokens.primaryStrong),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildEntryCards(List<FieldOfficerAttendanceEntry> entries) {
    final grouped = <String, List<FieldOfficerAttendanceEntry>>{};
    for (final entry in entries) {
      final key = entry.siteName.isEmpty ? 'Unassigned' : entry.siteName;
      grouped.putIfAbsent(key, () => <FieldOfficerAttendanceEntry>[]).add(entry);
    }

    final tokens = CissThemeTokens.of(context);
    final widgets = <Widget>[];

    for (final site in grouped.keys) {
      final siteEntries = grouped[site]!;
      final present = siteEntries.where((e) => e.status == 'Present' || e.status == 'In').length;

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md - 1)),
                  gradient: LinearGradient(colors: <Color>[tokens.primaryStrong, tokens.primary]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(site, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                    Text('$present / ${siteEntries.length} present',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.inkMuted, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              ...siteEntries.map((entry) => _GuardRow(entry: entry)),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static String _initials(String name, String fallback) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final i = parts.map((p) => p[0]).take(2).join().toUpperCase();
    if (i.isNotEmpty) return i;
    return fallback.trim().isNotEmpty ? fallback.trim().substring(0, fallback.length.clamp(0, 2)).toUpperCase() : 'GU';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value, required this.tokens, this.valueColor});
  final IconData icon;
  final String label;
  final String value;
  final CissThemeTokens tokens;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: tokens.inkMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.inkMuted))),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: valueColor ?? tokens.ink, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GuardRow extends StatefulWidget {
  const _GuardRow({required this.entry});
  final FieldOfficerAttendanceEntry entry;

  @override
  State<_GuardRow> createState() => _GuardRowState();
}

class _GuardRowState extends State<_GuardRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final theme = Theme.of(context);
    final entry = widget.entry;
    final bool isPresent = entry.status == 'Present' || entry.status == 'In';
    final bool isAbsent = entry.status == 'Absent' || entry.status == 'Missed';
    final initials = _FieldOfficerGuardAttendanceScreenState._initials(entry.guardName, entry.employeeId);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isPresent ? tokens.successSoft : tokens.dangerSoft,
                  backgroundImage: entry.photoUrl != null && entry.photoUrl!.isNotEmpty ? NetworkImage(entry.photoUrl!) : null,
                  child: entry.photoUrl == null || entry.photoUrl!.isEmpty
                      ? Text(initials, style: theme.textTheme.labelSmall?.copyWith(color: isPresent ? tokens.success : tokens.danger, fontWeight: FontWeight.w800))
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(entry.guardName.isEmpty ? entry.employeeId : entry.guardName,
                        style: theme.textTheme.titleSmall?.copyWith(color: tokens.ink, height: 1.2),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [if (entry.dutyPointName.isNotEmpty) entry.dutyPointName, if (entry.shiftLabel.isNotEmpty) entry.shiftLabel].join(' · '),
                        style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (entry.checkIn != null) ...<Widget>[
                  Icon(Icons.login_rounded, size: 14, color: tokens.inkMuted),
                  const SizedBox(width: 3),
                  Text(entry.checkIn!, style: theme.textTheme.labelSmall?.copyWith(color: tokens.inkMuted)),
                ],
                const SizedBox(width: AppSpacing.sm),
                StatusChip(
                  label: isAbsent ? 'Absent' : isPresent ? 'Present' : entry.status.isEmpty ? 'N/A' : entry.status,
                  tone: isAbsent ? StatusChipTone.warning : isPresent ? StatusChipTone.success : StatusChipTone.neutral,
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, size: 18, color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: <Widget>[
                    if (entry.dateLabel.isNotEmpty)
                      _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: entry.dateLabel, tokens: tokens),
                    _DetailRow(icon: Icons.login_rounded, label: 'Check-in', value: entry.checkIn ?? '—', valueColor: entry.checkIn != null ? tokens.success : null, tokens: tokens),
                    const SizedBox(height: AppSpacing.xs),
                    _DetailRow(icon: Icons.logout_rounded, label: 'Check-out', value: entry.checkOut ?? '—', valueColor: entry.checkOut != null ? tokens.danger : null, tokens: tokens),
                    if (entry.dutyPointName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _DetailRow(icon: Icons.work_outline_rounded, label: 'Duty point', value: entry.dutyPointName, tokens: tokens),
                    ],
                    if (entry.shiftLabel.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _DetailRow(icon: Icons.schedule_rounded, label: 'Shift', value: entry.shiftLabel, tokens: tokens),
                    ],
                    if (entry.siteName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _DetailRow(icon: Icons.apartment_rounded, label: 'Site', value: entry.siteName, tokens: tokens),
                    ],
                    if (entry.clientName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _DetailRow(icon: Icons.business_rounded, label: 'Client', value: entry.clientName, tokens: tokens),
                    ],
                    if (entry.district.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _DetailRow(icon: Icons.place_outlined, label: 'District', value: entry.district, tokens: tokens),
                    ],
                    if (entry.employeeId.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _DetailRow(icon: Icons.badge_outlined, label: 'Employee ID', value: entry.employeeId, tokens: tokens),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
