import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../core/region/region_service.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/sync_status_badge.dart';
import 'client_visit_reports_screen.dart';
import 'client_training_reports_screen.dart';
import 'client_guard_detail_screen.dart';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchClientDashboard()
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _summary() =>
      (_dashboardData?['summary'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  List<Map<String, dynamic>> _list(String key) =>
      (_dashboardData?[key] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
      const <Map<String, dynamic>>[];

  int _num(Map<String, dynamic> source, String key) {
    final v = source[key];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final clientName =
        session?.clientName ?? session?.displayName ?? 'Client';

    final summary = _summary();
    final sites = _list('siteSnapshots');
    final liveAttendance = _list('liveAttendance');
    final guardHighlights = _list('guardHighlights');
    final upcomingWorkOrders = _list('upcomingWorkOrders');
    final recentVisitReports = _list('recentVisitReports');
    final recentTrainingReports = _list('recentTrainingReports');
    // ignore: unused_local_variable
    final recentPatrolActivities = _list('recentPatrolActivities');

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDashboard,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ModernHero(
                eyebrow: 'Welcome back',
                title: clientName,
                subtitle:
                    '${_num(summary, 'activeGuards')} active · ${_num(summary, 'sitesCovered')} sites',
                avatarText: initials(clientName, fallback: 'C'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SyncStatusBadge(),
                    IconButton(
                      onPressed: _fetchDashboard,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading || _error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 32),
                  child: StateBlock(
                    icon: _loading
                        ? Icons.sync_rounded
                        : Icons.cloud_off_rounded,
                    title: _loading
                        ? 'Loading dashboard'
                        : 'Could not load dashboard',
                    message: _loading
                        ? 'Fetching the latest client operations.'
                        : (_error ?? 'Unknown error'),
                    action: _error != null
                        ? FilledButton.tonal(
                            onPressed: _fetchDashboard,
                            child: const Text('Try again'),
                          )
                        : null,
                  ),
                ),
              if (!_loading && _error == null) ...[
                const SizedBox(height: 24),
                _metricGrid(summary, tokens),
                // Upcoming Work Orders
                if (upcomingWorkOrders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeader('UPCOMING WORK ORDERS'),
                  const SizedBox(height: 12),
                  ...upcomingWorkOrders.take(4).map((wo) {
                    final siteName = wo['siteName'] as String? ?? '';
                    final examName =
                        wo['examName'] as String? ?? 'Duty';
                    final date = wo['date'] as String? ?? '';
                    final total =
                        (wo['totalManpower'] as num?)?.toInt() ?? 0;
                    final assigned =
                        (wo['assignedCount'] as num?)?.toInt() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(
                          bottom: 12, left: 16, right: 16),
                      child: ModernCard(
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tokens.warningSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.assignment_rounded,
                                  color: tokens.warning, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(siteName.isNotEmpty
                                      ? siteName
                                      : examName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink)),
                                  if (date.isNotEmpty)
                                    Text(date,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: tokens.inkMuted)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tokens.primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('$assigned/$total',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.primary)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (upcomingWorkOrders.length > 4)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                        onPressed: () => Haptics.light(),
                        child: Text(
                            '+${upcomingWorkOrders.length - 4} more — View Orders'),
                      ),
                    ),
                ],
                // Top Sites
                if (sites.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeader('TOP SITES'),
                  const SizedBox(height: 12),
                  ...sites.take(5).map((s) {
                    final name =
                        s['siteName']?.toString() ?? 'Site';
                    final onDuty =
                        (s['onDutyNow'] as num?)?.toInt() ?? 0;
                    final checkedIn =
                        (s['checkedInToday'] as num?)?.toInt() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(
                          bottom: 12, left: 16, right: 16),
                      child: ModernCard(
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tokens.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.location_city_rounded,
                                  color: tokens.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.ink)),
                            ),
                            _Pill('$onDuty on duty', tokens.success),
                            const SizedBox(width: 6),
                            _Pill('$checkedIn in', tokens.primary),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                // Guard Highlights
                if (guardHighlights.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeader('GUARD HIGHLIGHTS'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: guardHighlights.take(8).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final g = guardHighlights[index];
                        final name = g['fullName']?.toString() ??
                            g['employeeName']?.toString() ?? 'Guard';
                        final status =
                            g['status']?.toString() ?? 'Active';
                        final site =
                            g['siteName']?.toString() ?? '';
                        final isActive = status.toLowerCase() == 'active';
                        final employeeId = g['employeeId'] as String? ??
                            g['id'] as String? ?? '';
                        return SizedBox(
                          width: 130,
                          child: ModernCard(
                            onTap: employeeId.isNotEmpty
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ClientGuardDetailScreen(
                                                employeeId: employeeId),
                                      ),
                                    )
                                : null,
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: isActive
                                      ? tokens.successSoft
                                      : tokens.surfaceMuted,
                                  child: Text(
                                    initials(name, fallback: ''),
                                    style: TextStyle(
                                      color: isActive
                                          ? tokens.success
                                          : tokens.inkMuted,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.ink)),
                                if (site.isNotEmpty)
                                  Text(site,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: tokens.inkMuted)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // Live Attendance
                if (liveAttendance.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeader('LIVE ATTENDANCE'),
                  const SizedBox(height: 12),
                  ...liveAttendance.take(5).map((a) {
                    final name = a['employeeName']?.toString() ??
                        a['guardName']?.toString() ?? 'Guard';
                    final site =
                        a['siteName']?.toString() ?? '';
                    final dutyPt =
                        a['dutyPointName']?.toString() ?? '';
                    final shift =
                        a['shiftLabel']?.toString() ?? '';
                    final status =
                        a['status']?.toString() ?? 'Out';
                    final isIn = status == 'In';
                    return Padding(
                      padding: const EdgeInsets.only(
                          bottom: 12, left: 16, right: 16),
                      child: ModernCard(
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isIn
                                  ? tokens.successSoft
                                  : tokens.surfaceMuted,
                              child: Text(
                                initials(name, fallback: ''),
                                style: TextStyle(
                                  color: isIn
                                      ? tokens.success
                                      : tokens.inkMuted,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink)),
                                  if (site.isNotEmpty)
                                    Text(
                                      '$site${dutyPt.isNotEmpty ? ' · $dutyPt' : ''}${shift.isNotEmpty ? ' · $shift' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.inkMuted),
                                    ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: status,
                              tone: isIn
                                  ? StatusChipTone.success
                                  : StatusChipTone.neutral,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (liveAttendance.length > 5)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                        onPressed: () => ref
                            .read(clientTabIndexProvider.notifier)
                            .state = 2,
                        child: Text(
                            '+${liveAttendance.length - 5} more — View all'),
                      ),
                    ),
                ],
                // Visit Reports section
                if (recentVisitReports.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeader('RECENT VISIT REPORTS'),
                  const SizedBox(height: 12),
                  ...recentVisitReports.take(3).map((r) {
                    final officerName =
                        r['fieldOfficerName'] as String? ??
                            r['officerName'] as String? ?? 'Officer';
                    final siteName =
                        r['siteName'] as String? ?? '';
                    final status =
                        r['status'] as String? ?? 'submitted';
                    final summary =
                        r['summary'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(
                          bottom: 12, left: 16, right: 16),
                      child: ModernCard(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(Icons.rate_review_rounded,
                                    size: 16,
                                    color: tokens.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(officerName,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink)),
                                ),
                                StatusChip(
                                  label: status.toUpperCase(),
                                  tone: status == 'reviewed'
                                      ? StatusChipTone.success
                                      : StatusChipTone.warning,
                                ),
                              ],
                            ),
                            if (siteName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(siteName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.inkMuted)),
                            ],
                            if (summary.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(summary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.ink)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ClientVisitReportsScreen(),
                        ),
                      ),
                      child: const Text('View all visit reports'),
                    ),
                  ),
                ],
                // Training Reports section
                if (recentTrainingReports.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeader('RECENT TRAINING REPORTS'),
                  const SizedBox(height: 12),
                  ...recentTrainingReports.take(3).map((r) {
                    final topic = r['topic'] as String? ??
                        r['subject'] as String? ??
                        'Training';
                    final officerName =
                        r['fieldOfficerName'] as String? ??
                            r['officerName'] as String? ?? 'Officer';
                    final siteName =
                        r['siteName'] as String? ?? '';
                    final attendees =
                        (r['attendeeCount'] as num?)?.toInt() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(
                          bottom: 12, left: 16, right: 16),
                      child: ModernCard(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(Icons.school_rounded,
                                    size: 16,
                                    color: tokens.success),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(topic,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink)),
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.successSoft,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text('$attendees attendees',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.success)),
                                ),
                              ],
                            ),
                            if (officerName.isNotEmpty ||
                                siteName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '$officerName${siteName.isNotEmpty ? ' · $siteName' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.inkMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ClientTrainingReportsScreen(),
                        ),
                      ),
                      child: const Text('View all training reports'),
                    ),
                  ),
                ],
                // Open Web Dashboard link
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ModernCard(
                    onTap: () {
                      Haptics.light();
                      final rawBase =
                          RegionService.instance.activeApiUrl;
                      final base = rawBase.endsWith('/')
                          ? rawBase.substring(0, rawBase.length - 1)
                          : rawBase;
                      launchUrl(Uri.parse('$base/dashboard'),
                          mode: LaunchMode.externalApplication);
                    },
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.open_in_browser_rounded,
                              color: tokens.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Open Web Dashboard',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.ink)),
                              Text(
                                  Uri.tryParse(RegionService
                                          .instance.activeApiUrl)
                                      ?.host ??
                                      'Active region',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.inkMuted)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: tokens.inkMuted),
                      ],
                    ),
                  ),
                ),
                // Sign out
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Haptics.heavy();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign out?'),
                            content: const Text(
                                'You will be signed out of your account.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    ref
                                        .read(authControllerProvider)
                                        .signOut();
                                  },
                                  child: const Text('Sign out')),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.danger,
                        side: BorderSide(
                            color:
                                tokens.danger.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tokens.inkMuted,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _metricGrid(
      Map<String, dynamic> summary, CissThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: MetricCard(
                  label: 'On Duty',
                  value: '${_num(summary, 'onDutyNow')}',
                  color: tokens.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Checked In',
                  value: '${_num(summary, 'checkedInToday')}',
                  color: tokens.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: MetricCard(
                  label: 'Night Checks',
                  value: '${_num(summary, 'hourlyNightChecksToday')}',
                  color: tokens.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Pending Reports',
                  value: '${_num(summary, 'pendingVisitReports')}',
                  color: tokens.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
