import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../core/location/live_location_service.dart';
import 'field_officer_guard_detail_screen.dart';
import 'field_officer_dashboard_screen.dart';

final StateProvider<String?> attendanceSelectedDateProvider =
    StateProvider<String?>((Ref ref) => null);

final FutureProvider<List<FieldOfficerAttendanceEntry>>
    fieldOfficerGuardAttendanceProvider =
    FutureProvider<List<FieldOfficerAttendanceEntry>>((Ref ref) {
  final date = ref.watch(attendanceSelectedDateProvider) ??
      DateFormat('yyyy-MM-dd').format(DateTime.now());
  final session = ref.watch(authSessionProvider).value;
  final district = session?.assignedDistricts.isNotEmpty == true
      ? session!.assignedDistricts.first
      : null;

  return ref
      .read(mobileRepositoryProvider)
      .fetchFieldOfficerGuardAttendance(date: date, district: district);
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

  @override
  void dispose() {
    _historySearchCtrl.dispose();
    super.dispose();
  }

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
    final tokens = CissThemeTokens.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: tokens.canvas,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 48),
          child: Column(
            children: [
              AppBar(
                backgroundColor: tokens.canvas,
                elevation: 0,
                title: Text(
                  'Attendance',
                  style: TextStyle(fontWeight: FontWeight.w800, color: tokens.ink),
                ),
                actions: [
                  const SyncStatusBadge(),
                  IconButton(
                    onPressed: _refresh,
                    icon: Icon(Icons.refresh_rounded, color: tokens.inkMuted, size: 20),
                  ),
                ],
                bottom: TabBar(
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(text: 'Live Feed'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLiveFeedTab(tokens),
            _buildHistoryTab(tokens),
          ],
        ),
      ),
    );
  }

  // ────────────────── LIVE FEED TAB ──────────────────
  Widget _buildLiveFeedTab(CissThemeTokens tokens) {
    final dashboardAsync = ref.watch(fieldOfficerDashboardProvider);
    final entriesAsync = ref.watch(fieldOfficerGuardAttendanceProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
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
                  style: IconButton.styleFrom(
                    backgroundColor: tokens.surface,
                  ),
                ),
              ],
            ],
          ),
        ),

        dashboardAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
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
                      itemBuilder: (_, i) => _SiteFilterChip(
                        site: sites[i],
                        isSelected: _selectedSiteId == sites[i].siteId,
                        onTap: () => setState(() {
                          _selectedSiteId = _selectedSiteId == sites[i].siteId
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
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: StateBlock(
                      icon: Icons.error_outline_rounded,
                      title: 'Sync issue',
                      message: CissError.parse(err),
                    ),
                  ),
                  data: (entries) {
                    final filtered = _selectedSiteId == null
                        ? entries
                        : entries
                            .where((e) {
                              final selectedSite = sites.cast<FieldOfficerAttendanceSite?>()
                                  .firstWhere((s) => s?.siteId == _selectedSiteId, orElse: () => null);
                              if (selectedSite == null) return false;
                              return e.siteName.trim().toLowerCase() ==
                                  selectedSite.siteName.trim().toLowerCase();
                            })
                            .toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: StateBlock(
                          icon: Icons.person_off_rounded,
                          title: 'No records found',
                          message: 'No guard attendance recorded for this filter.',
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StreamBuilder<List<GuardLocationData>>(
                        stream: LiveLocationService().streamActiveLocations(),
                        builder: (context, locSnap) {
                          final locations = locSnap.data ?? const <GuardLocationData>[];
                          return Column(
                            children: filtered.map((e) {
                              final loc = locations.cast<GuardLocationData?>().firstWhere(
                                (l) => l?.employeeId == e.employeeId,
                                orElse: () => null,
                              );
                              return _LiveGuardRow(
                                e,
                                location: loc,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FieldOfficerGuardDetailScreen(
                                        employeeId: e.employeeId,
                                        guardName: e.guardName,
                                        siteName: e.siteName,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
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
    final entriesAsync = ref.watch(fieldOfficerGuardAttendanceProvider);

    // Initialize default history dates: this month
    if (_historyStartDate == null && _historyEndDate == null) {
      final now = DateTime.now();
      _historyStartDate = DateTime(now.year, now.month, 1);
      _historyEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 16, AppSpacing.md, AppSpacing.xxl),
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
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Padding(
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
                  ...filtered.map((e) => _buildHistoryCard(e, tokens)),
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
        children: filters.entries.map((f) {
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
                  color: isSelected ? Colors.white : tokens.ink,
                ),
              ),
              onSelected: (v) {
                setState(() {
                  _historyQuickFilter = v ? f.key : null;
                  _applyQuickFilter(f.key);
                });
              },
              selectedColor: tokens.accent,
              checkmarkColor: Colors.white,
              side: BorderSide.none,
              backgroundColor: tokens.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        _historyStartDate = DateTime(now.year, now.month, now.day - weekday + 1);
        _historyEndDate = DateTime(now.year, now.month, now.day + (7 - weekday), 23, 59, 59);
        break;
      case 'month':
        _historyStartDate = DateTime(now.year, now.month, 1);
        _historyEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }
  }

  Widget _buildHistoryDateRange(CissThemeTokens tokens) {
    final startLabel = _historyStartDate != null ? _displayFmt.format(_historyStartDate!) : 'Start';
    final endLabel = _historyEndDate != null ? _displayFmt.format(_historyEndDate!) : 'End';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickHistoryDate(true),
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(startLabel, style: const TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('to', style: TextStyle(fontSize: 12, color: tokens.inkMuted)),
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickHistoryDate(false),
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(endLabel, style: const TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickHistoryDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _historyStartDate ?? DateTime.now() : _historyEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _historyQuickFilter = null;
        if (isStart) {
          _historyStartDate = DateTime(picked.year, picked.month, picked.day);
        } else {
          _historyEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  Widget _buildHistorySearch(CissThemeTokens tokens) {
    return TextField(
      controller: _historySearchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        hintText: 'Search by guard name...',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _buildHistorySummary(
    List<FieldOfficerAttendanceEntry> entries,
    CissThemeTokens tokens,
  ) {
    final present = entries.where((e) => e.status == 'Present' || e.status == 'In').length;
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
              Container(width: 1, height: 36, color: tokens.border.withValues(alpha: 0.3)),
              _buildHistoryStat('Present', '$present', tokens.success, tokens),
              Container(width: 1, height: 36, color: tokens.border.withValues(alpha: 0.3)),
              _buildHistoryStat('Absent', '$absent', tokens.danger, tokens),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(String label, String value, Color color, CissThemeTokens tokens) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, height: 1.1)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: tokens.inkMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(FieldOfficerAttendanceEntry entry, CissThemeTokens tokens) {
    final isPresent = entry.status == 'Present' || entry.status == 'In';
    final glow = isPresent ? tokens.success : tokens.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FieldOfficerGuardDetailScreen(
                  employeeId: entry.employeeId,
                  guardName: entry.guardName,
                  siteName: entry.siteName,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            accentColor: glow,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: glow.withValues(alpha: 0.1),
                  backgroundImage: (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                      ? NetworkImage(entry.photoUrl!)
                      : null,
                  child: (entry.photoUrl == null || entry.photoUrl!.isEmpty)
                      ? Text(
                          entry.guardName.isNotEmpty
                              ? entry.guardName.substring(0, 1).toUpperCase()
                              : 'G',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: glow),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.ink),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.primary),
                    ),
                    Text(
                      entry.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
    final accent = isSelected ? tokens.primary : tokens.border;

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
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: accent, width: isSelected ? 2 : 1),
            boxShadow: isSelected
                ? [BoxShadow(color: tokens.primary.withValues(alpha: 0.1), blurRadius: 10)]
                : null,
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
                  Icon(Icons.people_alt_rounded, size: 12, color: tokens.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${site.onDutyNow}/${site.checkedInToday}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? tokens.primaryStrong : tokens.inkMuted,
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
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            accentColor: glow,
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: glow.withValues(alpha: 0.1),
                      backgroundImage: (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                          ? NetworkImage(entry.photoUrl!)
                          : null,
                      child: (entry.photoUrl == null || entry.photoUrl!.isEmpty)
                          ? Text(
                              entry.guardName.isNotEmpty
                                  ? entry.guardName.substring(0, 1).toUpperCase()
                                  : 'G',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: glow),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.ink),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tokens.primary),
                    ),
                    Text(
                      entry.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
        hasLive && DateTime.now().difference(location!.updatedAt).inMinutes > 10;

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
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: hasLive && !isStale
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
