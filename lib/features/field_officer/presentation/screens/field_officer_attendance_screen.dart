import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../core/location/live_location_service.dart';
import 'field_officer_guard_detail_screen.dart';
import 'field_officer_dashboard_screen.dart';

final StateProvider<String?> attendanceSelectedDateProvider =
    StateProvider<String?>((Ref ref) => null);

final StateProvider<DateTime> attendanceHistoryStartDateProvider =
    StateProvider<DateTime>((Ref ref) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    });

final StateProvider<DateTime> attendanceHistoryEndDateProvider =
    StateProvider<DateTime>((Ref ref) {
      final now = DateTime.now();
      return DateTime(now.year, now.month + 1, 0);
    });

final FutureProvider<List<FieldOfficerAttendanceEntry>>
fieldOfficerGuardAttendanceProvider =
    FutureProvider<List<FieldOfficerAttendanceEntry>>((Ref ref) {
      final date =
          ref.watch(attendanceSelectedDateProvider) ??
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      return ref
          .read(mobileRepositoryProvider)
          .fetchFieldOfficerGuardAttendance(date: date);
    });

final FutureProvider<List<FieldOfficerAttendanceEntry>>
fieldOfficerGuardAttendanceHistoryProvider =
    FutureProvider<List<FieldOfficerAttendanceEntry>>((Ref ref) {
      final start = ref.watch(attendanceHistoryStartDateProvider);
      final end = ref.watch(attendanceHistoryEndDateProvider);
      return ref
          .read(mobileRepositoryProvider)
          .fetchFieldOfficerGuardAttendanceRange(start: start, end: end);
    });

final FutureProvider<List<FieldOfficerSiteOption>>
fieldOfficerAttendanceSitesProvider =
    FutureProvider<List<FieldOfficerSiteOption>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchFieldOfficerSites();
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
  String? _selectedSiteId;
  static final DateFormat _displayFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  // History tab state
  String? _historyQuickFilter;
  DateTime? _historyStartDate;
  DateTime? _historyEndDate;
  final TextEditingController _historySearchCtrl = TextEditingController();

  late final LiveLocationService _liveLocationService;

  @override
  void initState() {
    super.initState();
    _liveLocationService = LiveLocationService();
    // Initialize default history dates: this month
    final now = DateTime.now();
    _historyStartDate = DateTime(now.year, now.month, 1);
    _historyEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  @override
  void dispose() {
    _historySearchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(fieldOfficerDashboardProvider)
      ..invalidate(fieldOfficerGuardAttendanceProvider)
      ..invalidate(fieldOfficerGuardAttendanceHistoryProvider);
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
      ref.read(attendanceSelectedDateProvider.notifier).state = _apiFmt.format(
        picked,
      );
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    ref.read(attendanceSelectedDateProvider.notifier).state = null;
  }

  Future<void> _shareMusterRoll() async {
    final entries =
        ref.read(fieldOfficerGuardAttendanceProvider).valueOrNull ?? [];
    final dashboard = ref.read(fieldOfficerDashboardProvider).valueOrNull;
    final dateStr =
        _selectedDate != null
            ? _displayFmt.format(_selectedDate!)
            : _displayFmt.format(DateTime.now());

    final Map<String, int> siteOnDuty = {};
    int totalIn = 0;
    int totalOut = 0;

    for (final e in entries) {
      if (e.status.toLowerCase() == 'in') {
        totalIn++;
        final site =
            e.siteName.trim().isEmpty ? 'General / Unassigned' : e.siteName.trim();
        siteOnDuty[site] = (siteOnDuty[site] ?? 0) + 1;
      } else {
        totalOut++;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 *CISS Muster Roll Summary*');
    buffer.writeln('📅 Date: $dateStr');
    if (dashboard != null) {
      buffer.writeln('👥 Total Guard Force: ${dashboard.totalGuards}');
    }
    buffer.writeln('🟢 Currently On Duty: $totalIn');
    buffer.writeln('🔴 Checked Out: $totalOut');
    buffer.writeln('');
    buffer.writeln('🏢 *Site Deployment:*');
    if (siteOnDuty.isEmpty) {
      buffer.writeln('• No active check-ins recorded for this date.');
    } else {
      final sortedSites = siteOnDuty.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final item in sortedSites) {
        buffer.writeln('• ${item.key}: ${item.value} guard(s) on duty');
      }
    }
    buffer.writeln('');
    buffer.writeln('— Generated via CISS Mobile Field Operations');

    await Share.share(
      buffer.toString(),
      subject: 'CISS Muster Roll Summary - $dateStr',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: tokens.canvas,
        appBar: CissAppBar(
          title: 'Attendance',
          showBackButton: false,
          actions: <Widget>[
            const SyncStatusBadge(),
            IconButton(
              tooltip: 'Share Muster Roll',
              onPressed: _shareMusterRoll,
              icon: Icon(
                Icons.share_rounded,
                color: tokens.inkMuted,
                size: 20,
              ),
            ),
            IconButton(
              onPressed: _refresh,
              icon: Icon(
                Icons.refresh_rounded,
                color: tokens.inkMuted,
                size: 20,
              ),
            ),
          ],
          bottom: TabBar(
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [Tab(text: 'Live Feed'), Tab(text: 'History')],
          ),
        ),
        body: TabBarView(
          children: [_buildLiveFeedTab(tokens), _buildHistoryTab(tokens)],
        ),
      ),
    );
  }

  // ────────────────── LIVE FEED TAB ──────────────────
  Widget _buildLiveFeedTab(CissThemeTokens tokens) {
    final dashboardAsync = ref.watch(fieldOfficerDashboardProvider);
    final entriesAsync = ref.watch(fieldOfficerGuardAttendanceProvider);
    final sitesAsync = ref.watch(fieldOfficerAttendanceSitesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        100,
      ),
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _selectedDate != null
                        ? _displayFmt.format(_selectedDate!)
                        : 'Select Date',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearDate,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(backgroundColor: tokens.surface),
                ),
              ],
            ],
          ),
        ),

        dashboardAsync.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (err, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: StateBlock(
                  icon: Icons.error_outline_rounded,
                  title: 'Data error',
                  message: CissError.parse(err),
                ),
              ),
          data: (dashboard) {
            final sites = dashboard.attendanceSites;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sites.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: PortalSectionHeading(title: 'Site Summaries'),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sites.length,
                      itemBuilder:
                          (_, i) => _SiteFilterChip(
                            site: sites[i],
                            isSelected: _selectedSiteId == sites[i].siteId,
                            onTap:
                                () => setState(() {
                                  _selectedSiteId =
                                      _selectedSiteId == sites[i].siteId
                                          ? null
                                          : sites[i].siteId;
                                }),
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: PortalSectionHeading(title: 'Individual Records'),
                ),

                entriesAsync.when(
                  loading:
                      () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  error:
                      (err, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: StateBlock(
                          icon: Icons.error_outline_rounded,
                          title: 'Sync issue',
                          message: CissError.parse(err),
                        ),
                      ),
                  data: (entries) {
                    final filtered =
                        _selectedSiteId == null
                            ? entries
                            : entries.where((e) {
                              final selectedSite = sites
                                  .cast<FieldOfficerAttendanceSite?>()
                                  .firstWhere(
                                    (s) => s?.siteId == _selectedSiteId,
                                    orElse: () => null,
                                  );
                              if (selectedSite == null) return false;
                              return e.siteName.trim().toLowerCase() ==
                                  selectedSite.siteName.trim().toLowerCase();
                            }).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: StateBlock(
                          icon: Icons.person_off_rounded,
                          title: 'No records found',
                          message:
                              'No guard attendance recorded for this filter.',
                        ),
                      );
                    }

                    final siteOptions = sitesAsync.maybeWhen(
                      data: (items) => items,
                      orElse: () => const <FieldOfficerSiteOption>[],
                    );

                    return Column(
                      children: [
                        _AttendanceMapCard(
                          entries: filtered,
                          sites: siteOptions,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: StreamBuilder<List<GuardLocationData>>(
                            stream:
                                _liveLocationService.streamActiveLocations(),
                            builder: (context, locSnap) {
                              final locations =
                                  locSnap.data ?? const <GuardLocationData>[];
                              return Column(
                                children:
                                    filtered.map((e) {
                                      final loc = locations
                                          .cast<GuardLocationData?>()
                                          .firstWhere(
                                            (l) =>
                                                l?.employeeId == e.employeeId,
                                            orElse: () => null,
                                          );
                                      final site = _findSite(e, siteOptions);
                                      return _LiveGuardRow(
                                        e,
                                        location: loc,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (_) =>
                                                      FieldOfficerGuardDetailScreen(
                                                        employeeId:
                                                            e.employeeId,
                                                        employeeDocId:
                                                            e.guardId,
                                                        guardName: e.guardName,
                                                        siteName: e.siteName,
                                                        attendanceEntry: e,
                                                        siteLatitude:
                                                            site?.latitude,
                                                        siteLongitude:
                                                            site?.longitude,
                                                      ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ────────────────── HISTORY TAB ──────────────────
  Widget _buildHistoryTab(CissThemeTokens tokens) {
    final entriesAsync = ref.watch(fieldOfficerGuardAttendanceHistoryProvider);
    final sitesAsync = ref.watch(fieldOfficerAttendanceSitesProvider);
    final siteOptions = sitesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <FieldOfficerSiteOption>[],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        16,
        AppSpacing.md,
        100,
      ),
      children: [
        // Quick filter chips
        _buildHistoryQuickFilters(tokens),
        const SizedBox(height: 12),
        // Date range display + custom picker
        _buildHistoryDateRange(tokens),
        const SizedBox(height: 16),
        // Guard search
        _buildHistorySearch(tokens),
        const SizedBox(height: 16),

        // Summary + filtered entries
        entriesAsync.when(
          loading:
              () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
          error:
              (err, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: StateBlock(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load history',
                  message: CissError.parse(err),
                  action: FilledButton.tonal(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ),
              ),
          data: (entries) {
            final filtered = _filterHistoryEntries(entries);
            return Column(
              children: [
                _buildHistorySummary(filtered, tokens),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: StateBlock(
                      icon: Icons.search_off_rounded,
                      title: 'No matching records',
                      message: 'Try adjusting your date range or search.',
                    ),
                  )
                else
                  ...filtered.map(
                    (e) => _buildHistoryCard(e, tokens, siteOptions),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryQuickFilters(CissThemeTokens tokens) {
    final filters = {
      'today': 'Today',
      'week': 'This Week',
      'month': 'This Month',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            filters.entries.map((f) {
              final isSelected = _historyQuickFilter == f.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(
                    f.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? tokens.surface : tokens.ink,
                    ),
                  ),
                  onSelected: (v) {
                    setState(() {
                      _historyQuickFilter = v ? f.key : null;
                      _applyQuickFilter(f.key);
                    });
                  },
                  selectedColor: tokens.accent,
                  checkmarkColor: tokens.surface,
                  side: BorderSide.none,
                  backgroundColor: tokens.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
      ),
    );
  }

  void _applyQuickFilter(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'today':
        _historyStartDate = DateTime(now.year, now.month, now.day);
        _historyEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        final weekday = now.weekday;
        _historyStartDate = DateTime(
          now.year,
          now.month,
          now.day - weekday + 1,
        );
        _historyEndDate = DateTime(
          now.year,
          now.month,
          now.day + (7 - weekday),
          23,
          59,
          59,
        );
        break;
      case 'month':
        _historyStartDate = DateTime(now.year, now.month, 1);
        _historyEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }
    ref.read(attendanceHistoryStartDateProvider.notifier).state =
        _historyStartDate!;
    ref.read(attendanceHistoryEndDateProvider.notifier).state =
        _historyEndDate!;
  }

  Widget _buildHistoryDateRange(CissThemeTokens tokens) {
    final startLabel =
        _historyStartDate != null
            ? _displayFmt.format(_historyStartDate!)
            : 'Start';
    final endLabel =
        _historyEndDate != null ? _displayFmt.format(_historyEndDate!) : 'End';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickHistoryDate(true),
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(startLabel, style: const TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'to',
            style: TextStyle(fontSize: 12, color: tokens.inkMuted),
          ),
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickHistoryDate(false),
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(endLabel, style: const TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickHistoryDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart
              ? _historyStartDate ?? DateTime.now()
              : _historyEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        _historyQuickFilter = null;
        if (isStart) {
          _historyStartDate = DateTime(picked.year, picked.month, picked.day);
        } else {
          _historyEndDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
          );
        }
      });
      ref.read(attendanceHistoryStartDateProvider.notifier).state =
          _historyStartDate!;
      ref.read(attendanceHistoryEndDateProvider.notifier).state =
          _historyEndDate!;
    }
  }

  Widget _buildHistorySearch(CissThemeTokens tokens) {
    return TextField(
      controller: _historySearchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        hintText: 'Search by guard name...',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.3)),
        ),
        filled: true,
        fillColor: tokens.surface,
      ),
    );
  }

  List<FieldOfficerAttendanceEntry> _filterHistoryEntries(
    List<FieldOfficerAttendanceEntry> entries,
  ) {
    final search = _historySearchCtrl.text.trim().toLowerCase();
    return entries.where((e) {
      if (search.isNotEmpty && !e.guardName.toLowerCase().contains(search)) {
        return false;
      }
      return true;
    }).toList();
  }

  FieldOfficerSiteOption? _findSite(
    FieldOfficerAttendanceEntry entry,
    List<FieldOfficerSiteOption> sites,
  ) {
    final target = _normalizeLabel(entry.siteName);
    if (target.isEmpty) return null;
    for (final site in sites) {
      if (_normalizeLabel(site.siteName) == target) return site;
    }
    return null;
  }

  Widget _buildHistorySummary(
    List<FieldOfficerAttendanceEntry> entries,
    CissThemeTokens tokens,
  ) {
    final present =
        entries.where((e) => e.status == 'Present' || e.status == 'In').length;
    final absent = entries.where((e) => e.status == 'Absent').length;
    final total = entries.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: tokens.accent),
              const SizedBox(width: 8),
              Text(
                'HISTORY SUMMARY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tokens.accent,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHistoryStat('Total', '$total', tokens.accent, tokens),
              Container(
                width: 1,
                height: 36,
                color: tokens.border.withValues(alpha: 0.3),
              ),
              _buildHistoryStat('Present', '$present', tokens.success, tokens),
              Container(
                width: 1,
                height: 36,
                color: tokens.border.withValues(alpha: 0.3),
              ),
              _buildHistoryStat('Absent', '$absent', tokens.danger, tokens),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(
    String label,
    String value,
    Color color,
    CissThemeTokens tokens,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: tokens.inkMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    FieldOfficerAttendanceEntry entry,
    CissThemeTokens tokens,
    List<FieldOfficerSiteOption> sites,
  ) {
    final isPresent = entry.status == 'Present' || entry.status == 'In';
    final glow = isPresent ? tokens.success : tokens.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final site = _findSite(entry, sites);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => FieldOfficerGuardDetailScreen(
                      employeeId: entry.employeeId,
                      employeeDocId: entry.guardId,
                      guardName: entry.guardName,
                      siteName: entry.siteName,
                      attendanceEntry: entry,
                      siteLatitude: site?.latitude,
                      siteLongitude: site?.longitude,
                    ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ModernCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: glow.withValues(alpha: 0.1),
                  backgroundImage:
                      (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                          ? NetworkImage(entry.photoUrl!)
                          : null,
                  child:
                      (entry.photoUrl == null || entry.photoUrl!.isEmpty)
                          ? Text(
                            entry.guardName.isNotEmpty
                                ? entry.guardName.substring(0, 1).toUpperCase()
                                : 'G',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: glow,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.guardName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        '${entry.siteName} · ${entry.dutyPointName}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.checkIn ?? '--:--',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tokens.primary,
                      ),
                    ),
                    Text(
                      entry.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: glow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceMapCard extends StatefulWidget {
  const _AttendanceMapCard({required this.entries, required this.sites});

  final List<FieldOfficerAttendanceEntry> entries;
  final List<FieldOfficerSiteOption> sites;

  @override
  State<_AttendanceMapCard> createState() => _AttendanceMapCardState();
}

class _AttendanceMapCardState extends State<_AttendanceMapCard> {
  final MapController _mapController = MapController();
  bool _tilesFailed = false;
  String _lastFitKey = '';

  List<LatLng> get _points {
    final points = <LatLng>[];
    for (final entry in widget.entries) {
      final lat = entry.attendanceLatitude;
      final lng = entry.attendanceLongitude;
      if (_validCoordinates(lat, lng)) {
        points.add(LatLng(lat!, lng!));
      }

      final site = _siteForEntry(entry, widget.sites);
      if (site != null && _validCoordinates(site.latitude, site.longitude)) {
        points.add(LatLng(site.latitude!, site.longitude!));
      }
    }
    return points;
  }

  List<FieldOfficerSiteOption> get _visibleSites {
    final seen = <String>{};
    return widget.entries
        .map((entry) => _siteForEntry(entry, widget.sites))
        .whereType<FieldOfficerSiteOption>()
        .where((site) {
          if (!_validCoordinates(site.latitude, site.longitude)) return false;
          final key = '${site.latitude}:${site.longitude}';
          return seen.add(key);
        })
        .toList();
  }

  List<FieldOfficerAttendanceEntry> get _locatedEntries {
    return widget.entries
        .where(
          (entry) => _validCoordinates(
            entry.attendanceLatitude,
            entry.attendanceLongitude,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToPoints());
  }

  @override
  void didUpdateWidget(_AttendanceMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToPoints());
  }

  void _fitToPoints({bool force = false}) {
    if (!mounted) return;
    final points = _points;
    if (points.isEmpty) return;
    final fitKey = points
        .map((point) => '${point.latitude}:${point.longitude}')
        .join('|');
    if (!force && fitKey == _lastFitKey) return;
    _lastFitKey = fitKey;
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 16);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(56),
            maxZoom: 16,
          ),
        );
      }
    } catch (_) {
      // The map controller is not ready during the first frame on some
      // Android devices. The next data update will retry the fit.
      _lastFitKey = '';
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final points = _points;
    final initialCenter =
        points.isNotEmpty ? points.first : const LatLng(10.0, 76.0);
    final locatedEntries = _locatedEntries;
    final visibleSites = _visibleSites;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ModernCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.map_outlined, size: 20, color: tokens.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Attendance map',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${locatedEntries.length} recorded position${locatedEntries.length == 1 ? '' : 's'} · ${visibleSites.length} working site${visibleSites.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _fitToPoints(force: true),
                    icon: Icon(Icons.fit_screen_rounded, color: tokens.primary),
                    tooltip: 'Show all attendance points',
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.md),
                ),
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: points.length > 1 ? 12 : 16,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'co.in.ciss.ciss_mobile',
                          errorTileCallback: (tile, error, stackTrace) {
                            if (!_tilesFailed && mounted) {
                              setState(() => _tilesFailed = true);
                            }
                          },
                        ),
                        if (visibleSites.isNotEmpty)
                          MarkerLayer(
                            markers:
                                visibleSites.map((site) {
                                  return Marker(
                                    point: LatLng(
                                      site.latitude!,
                                      site.longitude!,
                                    ),
                                    width: 52,
                                    height: 52,
                                    child: _SiteMapMarker(),
                                  );
                                }).toList(),
                          ),
                        if (locatedEntries.isNotEmpty)
                          MarkerLayer(
                            markers:
                                locatedEntries.map((entry) {
                                  return Marker(
                                    point: LatLng(
                                      entry.attendanceLatitude!,
                                      entry.attendanceLongitude!,
                                    ),
                                    width: 68,
                                    height: 68,
                                    child: GestureDetector(
                                      onTap: () => _showEntry(context, entry),
                                      child: _AttendanceMapMarker(
                                        isCheckedOut: entry.checkOut != null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                      ],
                    ),
                    if (points.isEmpty)
                      ColoredBox(
                        color: tokens.surface.withValues(alpha: 0.94),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No GPS coordinates were recorded for these attendance entries, and no site coordinates are available.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.inkMuted),
                            ),
                          ),
                        ),
                      ),
                    if (_tilesFailed)
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.warningSoft,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Map tiles are unavailable. GPS points are still available when recorded.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.warning),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: <Widget>[
                  _MapLegendItem(
                    color: tokens.primary,
                    label: 'Working site',
                    icon: Icons.business_rounded,
                  ),
                  _MapLegendItem(
                    color: tokens.success,
                    label: 'Recorded check-in',
                    icon: Icons.person_pin_circle_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEntry(BuildContext context, FieldOfficerAttendanceEntry entry) {
    final tokens = CissThemeTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.guardName,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.siteName} · ${entry.dutyPointName}',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Check-in ${entry.checkIn ?? '--:--'} · Check-out ${entry.checkOut ?? '--:--'}',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                if (entry.distanceMeters != null)
                  Text('Distance ${entry.distanceMeters!.round()} m'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapLegendItem extends StatelessWidget {
  const _MapLegendItem({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SiteMapMarker extends StatelessWidget {
  const _SiteMapMarker();

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: tokens.primary,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.surface, width: 2.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.primary.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.business_rounded, color: tokens.surface, size: 16),
    );
  }
}

class _AttendanceMapMarker extends StatelessWidget {
  const _AttendanceMapMarker({required this.isCheckedOut});

  final bool isCheckedOut;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = isCheckedOut ? tokens.accent : tokens.success;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: tokens.surface, width: 2.5),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(Icons.person, color: tokens.surface, size: 16),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 18),
      ],
    );
  }
}

FieldOfficerSiteOption? _siteForEntry(
  FieldOfficerAttendanceEntry entry,
  List<FieldOfficerSiteOption> sites,
) {
  final target = _normalizeLabel(entry.siteName);
  if (target.isEmpty) return null;
  for (final site in sites) {
    if (_normalizeLabel(site.siteName) == target) return site;
  }
  return null;
}

String _normalizeLabel(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

bool _validCoordinates(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);
}

class _SiteFilterChip extends StatelessWidget {
  const _SiteFilterChip({
    required this.site,
    required this.isSelected,
    required this.onTap,
  });

  final FieldOfficerAttendanceSite site;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? tokens.primarySoft : tokens.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isSelected ? tokens.primary : tokens.specularBorder,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow:
                isSelected
                    ? AppShadows.glow(tokens.primary)
                    : AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                site.siteName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? tokens.primaryStrong : tokens.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    size: 12,
                    color: tokens.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${site.onDutyNow}/${site.checkedInToday}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? tokens.primaryStrong : tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveGuardRow extends StatelessWidget {
  const _LiveGuardRow(this.entry, {this.location, this.onTap});
  final FieldOfficerAttendanceEntry entry;
  final GuardLocationData? location;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final bool isPresent = entry.status == 'Present' || entry.status == 'In';
    final glow = isPresent ? tokens.success : tokens.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ModernCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: glow.withValues(alpha: 0.1),
                      backgroundImage:
                          (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                              ? NetworkImage(entry.photoUrl!)
                              : null,
                      child:
                          (entry.photoUrl == null || entry.photoUrl!.isEmpty)
                              ? Text(
                                entry.guardName.isNotEmpty
                                    ? entry.guardName
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : 'G',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: glow,
                                ),
                              )
                              : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _LiveDot(location: location, fallbackColor: glow),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.guardName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        '${entry.siteName} · ${entry.dutyPointName}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.checkIn ?? '--:--',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tokens.primary,
                      ),
                    ),
                    Text(
                      entry.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: glow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({this.location, required this.fallbackColor});

  final GuardLocationData? location;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final hasLive = location != null && location!.status == 'In';
    final isStale =
        hasLive &&
        DateTime.now().difference(location!.updatedAt).inMinutes > 10;

    final Color color;
    if (!hasLive) {
      color = fallbackColor;
    } else if (isStale) {
      color = tokens.warning;
    } else {
      color = location!.isOutOfZone ? tokens.danger : tokens.success;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.surface, width: 2),
        boxShadow:
            hasLive && !isStale
                ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
                : null,
      ),
    );
  }
}
