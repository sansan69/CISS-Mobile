import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/attendance/attendance_pairing.dart';
import '../../../../../core/attendance/shift_window.dart';
import '../../../../../core/time/clock.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/network/ciss_error.dart';
import '../../../../../core/i18n/app_strings.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/portal_primitives.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../core/location/live_location_service.dart';
import '../../../auth/application/auth_controller.dart';
import 'field_officer_guard_detail_screen.dart';
import 'field_officer_dashboard_screen.dart';
import '../pdf/muster_roll_pdf.dart';

/// How the field officer wants the muster roll delivered.
enum _MusterShareAction { summary, pdf }

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
      final selected = ref.watch(attendanceSelectedDateProvider);
      // The live feed is read as a *business date*: an overnight shift's
      // check-out lands on the next calendar date, so the query reaches one
      // day back and the pairs are grouped by the date the shift started.
      final businessDate =
          (selected == null ? null : DateTime.tryParse(selected)) ??
          ref.read(clockProvider)();
      return ref
          .read(mobileRepositoryProvider)
          .fetchGuardAttendanceForBusinessDate(businessDate: businessDate)
          .then((entries) => entries.where((e) => e.hasRecordedPunch).toList());
    });

final FutureProvider<List<FieldOfficerAttendanceEntry>>
fieldOfficerGuardAttendanceHistoryProvider =
    FutureProvider<List<FieldOfficerAttendanceEntry>>((Ref ref) {
      final start = ref.watch(attendanceHistoryStartDateProvider);
      final end = ref.watch(attendanceHistoryEndDateProvider);
      return ref
          .read(mobileRepositoryProvider)
          // One day earlier than the visible window so a shift that began on
          // the previous evening still pairs with its check-out.
          .fetchFieldOfficerGuardAttendanceRange(
            start: start.subtract(const Duration(days: 1)),
            end: end,
          )
          .then((entries) => entries.where((e) => e.hasRecordedPunch).toList());
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
  static final DateFormat _pdfTimestampFmt = DateFormat('dd MMM yyyy, HH:mm');

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

  /// The shift day the live feed is looking at. A night duty belongs to the
  /// date it started, which is not always the calendar date the officer is
  /// standing on.
  DateTime get _businessDate =>
      startOfDay(_selectedDate ?? ref.read(clockProvider)());

  DateTime get _now => ref.read(clockProvider)();

  /// The districts this officer may read live positions for — the same list
  /// the Firestore rule evaluates, so the query and the rule agree.
  List<String> get _assignedDistricts =>
      ref.watch(authSessionProvider).valueOrNull?.assignedDistricts ??
      const <String>[];

  /// Pairs every punch for the feed, so a check-out that landed after midnight
  /// still closes the shift it belongs to.
  List<PunchPair> _pairs(List<FieldOfficerAttendanceEntry> entries) =>
      pairPunches(
        entries,
        now: _now,
        fallbackDate: _businessDate,
      );

  /// The shifts this feed is responsible for: the viewed business date plus any
  /// overnight shift that is still open, plus one that ended without a
  /// check-out within the last day.
  List<PunchPair> _livePairs(List<FieldOfficerAttendanceEntry> entries) {
    final viewed = _businessDate;
    return _pairs(entries)
        .where(
          (pair) =>
              pair.isOnDuty ||
              pair.needsReviewWithin(_now) ||
              _isSameDay(pair.businessDate, viewed),
        )
        .toList();
  }

  /// Site shown on the muster roll; an empty site is never rendered as blank.
  String _siteLabel(FieldOfficerAttendanceEntry entry) =>
      entry.siteName.trim().isEmpty
      ? 'General / Unassigned'
      : entry.siteName.trim();

  /// Guards whose shift never closed: they are neither on duty nor checked out.
  void _showCheckOutReview(
    List<PunchPair> pairs,
    List<FieldOfficerSiteOption> sites,
  ) {
    final strings = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: <Widget>[
                Text(
                  strings.fill(strings.attendanceReviewNotice, <String, Object>{
                    'count': pairs.length,
                  }),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final pair in pairs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      pair.entry.guardName.trim().isEmpty
                          ? pair.entry.employeeId
                          : pair.entry.guardName,
                    ),
                    subtitle: Text(
                      <String>[
                        pair.entry.siteName,
                        pair.entry.dutyPointName,
                        if (pair.checkIn != null) _clockLabel(pair.checkIn!),
                      ].where((value) => value.trim().isNotEmpty).join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openGuardDetail(pair.entry, sites);
                    },
                  ),
              ],
            ),
          ),
    );
  }

  void _openGuardDetail(
    FieldOfficerAttendanceEntry entry,
    List<FieldOfficerSiteOption> sites,
  ) {
    final site = _findSite(entry, sites);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
            : _displayFmt.format(ref.read(clockProvider)());

    final Map<String, int> siteOnDuty = <String, int>{};
    var totalIn = 0;
    var totalOut = 0;

    // Counted from paired shifts so a night duty that crosses midnight is one
    // guard on duty, and a shift that never closed is not counted as either.
    for (final pair in _livePairs(entries)) {
      if (pair.isOnDuty) {
        totalIn++;
        siteOnDuty[_siteLabel(pair.entry)] =
            (siteOnDuty[_siteLabel(pair.entry)] ?? 0) + 1;
      }
      if (pair.status == PunchPairStatus.closed) totalOut++;
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
      final sortedSites =
          siteOnDuty.entries.toList()
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

  /// Same aggregation as the text summary, rendered as a printable PDF for the
  /// client hand-over. Generated on-device so it works offline.
  Future<void> _shareMusterRollPdf() async {
    final entries =
        ref.read(fieldOfficerGuardAttendanceProvider).valueOrNull ?? [];
    final dashboard = ref.read(fieldOfficerDashboardProvider).valueOrNull;
    final dateStr =
        _selectedDate != null
            ? _displayFmt.format(_selectedDate!)
            : _displayFmt.format(ref.read(clockProvider)());

    final Map<String, int> siteOnDuty = <String, int>{};
    var totalIn = 0;
    var totalOut = 0;
    final rows = <MusterRollRow>[];
    final carriedOver = <MusterRollRow>[];
    final strings = AppStrings.of(context);
    final viewed = _businessDate;

    for (final pair in _livePairs(entries)) {
      final e = pair.entry;
      final site = _siteLabel(e);
      if (pair.isOnDuty) {
        totalIn++;
        siteOnDuty[site] = (siteOnDuty[site] ?? 0) + 1;
      }
      if (pair.status == PunchPairStatus.closed) totalOut++;
      final row = MusterRollRow(
        name: e.guardName.trim().isEmpty ? e.employeeId : e.guardName.trim(),
        employeeId: e.employeeId,
        site: site,
        checkIn: _punchText(pair.checkIn, e.checkIn, '—'),
        checkOut: _punchText(pair.checkOut, e.checkOut, '—'),
        status: _pairStatusLabel(pair, strings),
      );
      // Anything filed under an earlier business date — a tour still running
      // past midnight, or one that never closed — belongs in the carry-over
      // section instead of the day's own rows, so a guard is never listed
      // twice and no row appears under a date it does not belong to.
      if (!_isSameDay(pair.businessDate, viewed)) {
        carriedOver.add(row);
      } else {
        rows.add(row);
      }
    }

    final bytes = await buildMusterRollPdf(
      MusterRollData(
        dateLabel: dateStr,
        totalForce: dashboard?.totalGuards ?? entries.length,
        onDuty: totalIn,
        checkedOut: totalOut,
        siteOnDuty: siteOnDuty,
        rows: rows,
        carriedOver: carriedOver,
        generatedAt: _pdfTimestampFmt.format(ref.read(clockProvider)()),
      ),
    );

    final directory = await getTemporaryDirectory();
    final safeDate = dateStr.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '-');
    final file = File('${directory.path}/ciss-muster-roll-$safeDate.pdf');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(<XFile>[
      XFile(file.path, mimeType: 'application/pdf'),
    ], subject: 'CISS Muster Roll - $dateStr');
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
            PopupMenuButton<_MusterShareAction>(
              tooltip: 'Share Muster Roll',
              icon: Icon(
                Icons.share_rounded,
                color: tokens.inkMuted,
                size: 20,
              ),
              onSelected: (_MusterShareAction action) {
                if (action == _MusterShareAction.pdf) {
                  _shareMusterRollPdf();
                } else {
                  _shareMusterRoll();
                }
              },
              itemBuilder:
                  (BuildContext context) =>
                      const <PopupMenuEntry<_MusterShareAction>>[
                        PopupMenuItem<_MusterShareAction>(
                          value: _MusterShareAction.summary,
                          child: Text('Share summary'),
                        ),
                        PopupMenuItem<_MusterShareAction>(
                          value: _MusterShareAction.pdf,
                          child: Text('Share as PDF'),
                        ),
                      ],
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        // Clears the floating navigation bar plus the system gesture inset so
        // the last muster row is never hidden behind it.
        100 + MediaQuery.paddingOf(context).bottom,
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
                    final viewed = _businessDate;
                    final now = _now;
                    // A night shift that started yesterday and is still open
                    // belongs on today's feed, and so does one that ended
                    // without a check-out — that guard is the reason this
                    // screen exists. A shift that closed stays with the day it
                    // belongs to.
                    final relevant =
                        _pairs(entries)
                            .where(
                              (pair) =>
                                  pair.isOnDuty ||
                                  pair.needsReviewWithin(now) ||
                                  _isSameDay(pair.businessDate, viewed),
                            )
                            .toList();
                    final selectedSite =
                        _selectedSiteId == null
                            ? null
                            : sites
                                  .cast<FieldOfficerAttendanceSite?>()
                                  .firstWhere(
                                    (s) => s?.siteId == _selectedSiteId,
                                    orElse: () => null,
                                  );
                    final filtered =
                        selectedSite == null
                            ? relevant
                            : relevant
                                  .where(
                                    (pair) =>
                                        pair.entry.siteName.trim().toLowerCase() ==
                                        selectedSite.siteName
                                            .trim()
                                            .toLowerCase(),
                                  )
                                  .toList();

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
                    final review =
                        filtered
                            .where((pair) => pair.needsReviewWithin(now))
                            .toList();

                    return Column(
                      children: [
                        _AttendanceMapCard(
                          entries:
                              filtered.map((pair) => pair.entry).toList(),
                          sites: siteOptions,
                        ),
                        if (review.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _CheckOutReviewNotice(
                              count: review.length,
                              onTap: () => _showCheckOutReview(review, siteOptions),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: StreamBuilder<List<GuardLocationData>>(
                            stream:
                                _liveLocationService.streamActiveLocations(
                                  districts: _assignedDistricts,
                                ),
                            builder: (context, locSnap) {
                              final locations =
                                  locSnap.data ?? const <GuardLocationData>[];
                              return Column(
                                children:
                                    filtered.map((pair) {
                                      final e = pair.entry;
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
                                        pair: pair,
                                        viewedDate: viewed,
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        16,
        AppSpacing.md,
        100 + MediaQuery.paddingOf(context).bottom,
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
            final grouped = _filterHistoryPairs(entries);
            final ordered = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHistorySummary(
                  grouped.values.expand((day) => day).toList(),
                  tokens,
                ),
                const SizedBox(height: 16),
                if (grouped.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: StateBlock(
                      icon: Icons.search_off_rounded,
                      title: 'No matching records',
                      message: 'Try adjusting your date range or search.',
                    ),
                  )
                else
                  for (final date in ordered) ...<Widget>[
                    _buildHistoryDateHeader(date, tokens),
                    ...grouped[date]!.map(
                      (pair) => _buildHistoryCard(pair, tokens, siteOptions),
                    ),
                  ],
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

  /// History is grouped by the day each shift belongs to, so a 05:40 check-out
  /// appears under the previous day instead of as an orphan on its own date.
  /// The fetch reaches one day earlier than the visible window, so pairs are
  /// also filtered to the window the officer asked for.
  Map<DateTime, List<PunchPair>> _filterHistoryPairs(
    List<FieldOfficerAttendanceEntry> entries,
  ) {
    final search = _historySearchCtrl.text.trim().toLowerCase();
    final now = ref.read(clockProvider)();
    final start = startOfDay(_historyStartDate ?? now);
    final end = _historyEndDate ?? now;
    final pairs = _pairs(entries).where((pair) {
      final date = pair.businessDate;
      if (date.isBefore(start) || date.isAfter(end)) return false;
      if (search.isEmpty) return true;
      return pair.entry.guardName.toLowerCase().contains(search);
    });
    return groupByBusinessDate(pairs.toList());
  }

  Widget _buildHistoryDateHeader(DateTime date, CissThemeTokens tokens) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(
      children: <Widget>[
        Text(
          DateFormat('dd/MM/yyyy').format(date),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: tokens.inkMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: tokens.border.withValues(alpha: 0.4))),
      ],
    ),
  );

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
    List<PunchPair> pairs,
    CissThemeTokens tokens,
  ) {
    // Counted over shifts, not rows: a night duty that spans midnight is one
    // shift with one check-in and one check-out.
    final checkIns = pairs.where((pair) => pair.checkIn != null).length;
    final checkOuts = pairs.where((pair) => pair.checkOut != null).length;
    final total = pairs.length;
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              if (compact) {
                return Column(
                  children: [
                    _buildHistoryCompactStat(
                      'Total',
                      '$total',
                      tokens.accent,
                      tokens,
                    ),
                    _buildHistoryCompactStat(
                      'Check-ins',
                      '$checkIns',
                      tokens.success,
                      tokens,
                    ),
                    _buildHistoryCompactStat(
                      'Check-outs',
                      '$checkOuts',
                      tokens.accent,
                      tokens,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  _buildHistoryStat('Total', '$total', tokens.accent, tokens),
                  Container(
                    width: 1,
                    height: 36,
                    color: tokens.border.withValues(alpha: 0.3),
                  ),
                  _buildHistoryStat(
                    'Check-ins',
                    '$checkIns',
                    tokens.success,
                    tokens,
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: tokens.border.withValues(alpha: 0.3),
                  ),
                  _buildHistoryStat(
                    'Check-outs',
                    '$checkOuts',
                    tokens.accent,
                    tokens,
                  ),
                ],
              );
            },
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

  Widget _buildHistoryCompactStat(
    String label,
    String value,
    Color color,
    CissThemeTokens tokens,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: tokens.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _buildHistoryCard(
    PunchPair pair,
    CissThemeTokens tokens,
    List<FieldOfficerSiteOption> sites,
  ) {
    final entry = pair.entry;
    final strings = AppStrings.of(context);
    final glow = _pairGlow(pair, tokens);
    final statusLabel = _pairStatusLabel(pair, strings);
    final checkInLabel = _punchText(
      pair.checkIn,
      entry.checkIn,
      strings.attendanceNotRecorded,
    );
    final checkOutLabel = _punchText(
      pair.checkOut,
      entry.checkOut,
      strings.attendanceNotRecorded,
    );
    final multiDay =
        pair.checkIn != null &&
        pair.checkOut != null &&
        !_isSameDay(pair.checkIn!, pair.checkOut!);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: glow.withValues(alpha: 0.1),
                      backgroundImage:
                          (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(entry.photoUrl!)
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.guardName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: glow,
                        ),
                      ),
                    ),
                  ],
                ),
                if (multiDay) ...<Widget>[
                  const SizedBox(height: 6),
                  StatusChip(
                    label: strings.attendanceCarriedOver,
                    tone: StatusChipTone.info,
                    icon: Icons.nightlight_round,
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.siteName} · ${entry.dutyPointName}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${strings.attendanceCheckInLabel}: $checkInLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${strings.attendanceCheckOutLabel}: $checkOutLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
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
        // Flexible so a long label wraps inside the legend item instead of
        // overflowing the row at 1.8 text scale on a narrow phone.
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            softWrap: true,
          ),
        ),
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
                isSelected ? AppShadows.glow(tokens.primary) : AppShadows.card,
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
  const _LiveGuardRow(
    this.entry, {
    this.pair,
    this.viewedDate,
    this.location,
    this.onTap,
  });

  final FieldOfficerAttendanceEntry entry;

  /// The paired shift, so an overnight check-out still reads as on duty until
  /// it happens instead of the row flipping at midnight.
  final PunchPair? pair;

  /// The shift day on screen, used to tell "since 20:05" from "since 20:05
  /// (yesterday)".
  final DateTime? viewedDate;
  final GuardLocationData? location;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final strings = AppStrings.of(context);
    final onDuty = pair?.isOnDuty ?? entry.status == 'In';
    final glow =
        pair == null
            ? (entry.status == 'Present' || entry.status == 'In'
                ? tokens.success
                : tokens.warning)
            : _pairGlow(pair!, tokens);
    final statusLabel =
        pair == null ? entry.status : _pairStatusLabel(pair!, strings);
    final checkIn = pair?.checkIn;
    final since = checkIn == null
        ? null
        : strings.fill(
            onDuty &&
                    viewedDate != null &&
                    !_isSameDay(checkIn, viewedDate!)
                ? strings.attendanceSinceYesterday
                : strings.attendanceSince,
            <String, Object>{'time': _clockLabel(checkIn)},
          );

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
                              ? CachedNetworkImageProvider(entry.photoUrl!)
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
                      if (since != null)
                        Text(
                          since,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: glow,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bounded: the status label can be a sentence ("Check-out
                // missing"), and an unbounded column would overflow the row at
                // 1.8 text scale on a narrow phone.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _punchText(checkIn, entry.checkIn, '--:--'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tokens.primary,
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: glow,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line prompt for guards whose check-out never arrived (T2.5). It opens
/// the affected rows instead of asking the officer to hunt through the feed.
class _CheckOutReviewNotice extends StatelessWidget {
  const _CheckOutReviewNotice({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final strings = AppStrings.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.danger.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, size: 20, color: tokens.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.fill(strings.attendanceReviewNotice, <
                        String,
                        Object
                      >{'count': count}),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      strings.attendanceReviewNoticeHint,
                      style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tokens.danger),
            ],
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

/// True when both moments fall on the same calendar date.
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `HH:mm` for a parsed punch. Pairs carry real timestamps while the raw rows
/// carry whatever the server sent, so both paths render the same way.
String _clockLabel(DateTime moment) =>
    '${moment.hour.toString().padLeft(2, '0')}:'
    '${moment.minute.toString().padLeft(2, '0')}';

/// True when only the check-in is missing: the punch out exists, so this is a
/// completed shift seen without its start (usually because the check-in fell
/// outside the fetched window).
bool _orphanCheckOut(PunchPair pair) =>
    pair.status == PunchPairStatus.missedCheckOut && pair.checkIn == null;

String _pairStatusLabel(PunchPair pair, AppStrings strings) {
  if (_orphanCheckOut(pair)) return strings.attendanceCheckedOut;
  return switch (pair.status) {
    PunchPairStatus.open => strings.attendanceOnDuty,
    PunchPairStatus.missedCheckOut => strings.attendanceCheckOutMissing,
    PunchPairStatus.duplicateCheckIn => strings.attendanceDuplicateCheckIn,
    PunchPairStatus.closed => strings.attendanceCheckedOut,
  };
}

Color _pairGlow(PunchPair pair, CissThemeTokens tokens) {
  if (_orphanCheckOut(pair)) return tokens.inkMuted;
  return switch (pair.status) {
    PunchPairStatus.open => tokens.success,
    PunchPairStatus.missedCheckOut || PunchPairStatus.duplicateCheckIn =>
      tokens.danger,
    PunchPairStatus.closed => tokens.inkMuted,
  };
}

/// The time shown for one punch. The server's own string wins so the guard
/// keeps seeing the format the backend uses; the parsed clock is only needed
/// when the punch came from the paired row.
String _punchText(DateTime? parsed, String? raw, String fallback) {
  final text = raw?.trim() ?? '';
  if (text.isNotEmpty) return text;
  if (parsed != null) return _clockLabel(parsed);
  return fallback;
}
