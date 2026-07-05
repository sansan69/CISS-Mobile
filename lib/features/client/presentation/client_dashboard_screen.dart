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

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final sessionAsync = ref.watch(authSessionProvider);

    final session = sessionAsync.valueOrNull;
    final clientName = session?.clientName ?? session?.displayName ?? 'Client';
    final dashboardHost =
        Uri.tryParse(RegionService.instance.activeApiUrl)?.host ??
            'Active region';

    final summary =
        (_dashboardData?['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final liveAttendance =
        (_dashboardData?['liveAttendance'] as List?) ?? const <dynamic>[];
    final sites =
        (_dashboardData?['siteSnapshots'] as List?) ?? const <dynamic>[];
    final guardHighlights =
        (_dashboardData?['guardHighlights'] as List?) ?? const <dynamic>[];

    final activeGuards = _metric(summary, 'activeGuards');
    final sitesCovered = _metric(summary, 'sitesCovered');

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
                subtitle: '$activeGuards active guards · $sitesCovered sites',
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
                    message: _loadMsg,
                    action: _error != null
                        ? FilledButton.tonal(
                            onPressed: _fetchDashboard,
                            child: const Text('Try again'),
                          )
                        : null,
                  ),
                ),
              const SizedBox(height: 24),
              _metricGrid(summary, tokens),
              if (sites.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionHeader('TOP SITES'),
                const SizedBox(height: 12),
                ...sites.whereType<Map<String, dynamic>>().take(5).map((s) {
                  final name = s['siteName']?.toString() ?? 'Site';
                  final onDuty = (s['onDutyNow'] as num?)?.toInt() ?? 0;
                  final checkedIn =
                      (s['checkedInToday'] as num?)?.toInt() ?? 0;

                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                            alignment: Alignment.center,
                            child: Icon(Icons.location_city_rounded,
                                size: 20, color: tokens.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: tokens.ink,
                              ),
                            ),
                          ),
                          _MiniPill('$onDuty on duty', tokens.success),
                          const SizedBox(width: 6),
                          _MiniPill('$checkedIn in', tokens.primary),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (guardHighlights.isNotEmpty && !_loading) ...[
                const SizedBox(height: 24),
                _sectionHeader('GUARD HIGHLIGHTS'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: guardHighlights.take(8).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final g =
                          guardHighlights[index] as Map<String, dynamic>;
                      final name = g['fullName']?.toString() ?? 'Guard';
                      final status = g['status']?.toString() ?? 'Active';
                      final site = g['siteName']?.toString() ?? '';
                      final isActive = status.toLowerCase() == 'active';

                      return SizedBox(
                        width: 130,
                        child: ModernCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink,
                                ),
                              ),
                              if (site.isNotEmpty)
                                Text(
                                  site,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (liveAttendance.isNotEmpty && !_loading) ...[
                const SizedBox(height: 24),
                _sectionHeader('LIVE ATTENDANCE'),
                const SizedBox(height: 12),
                ...liveAttendance
                    .whereType<Map<String, dynamic>>()
                    .take(5)
                    .map((a) {
                  final name = a['employeeName']?.toString() ?? 'Guard';
                  final site = a['siteName']?.toString() ?? '';
                  final dutyPt = a['dutyPointName']?.toString() ?? '';
                  final shift = a['shiftLabel']?.toString() ?? '';
                  final status =
                      a['status']?.toString() ?? 'Out';
                  final isIn = status == 'In';

                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.ink,
                                  ),
                                ),
                                if (site.isNotEmpty)
                                  Text(
                                    '$site${dutyPt.isNotEmpty ? ' · $dutyPt' : ''}${shift.isNotEmpty ? ' · $shift' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.inkMuted,
                                    ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      onPressed: () {
                        ref
                            .read(clientTabIndexProvider.notifier)
                            .state = 2;
                      },
                      child: Text(
                          '+${liveAttendance.length - 5} more — View all'),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ModernCard(
                  onTap: () {
                    Haptics.medium();
                    final rawBase = RegionService.instance.activeApiUrl;
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Open Web Dashboard',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.ink)),
                            Text(dashboardHost,
                                style: TextStyle(
                                    fontSize: 13, color: tokens.inkMuted)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: tokens.inkMuted),
                    ],
                  ),
                ),
              ),
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
                                  ref.read(authControllerProvider).signOut();
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
                          color: tokens.danger.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String get _loadMsg {
    if (_loading) return 'Fetching the latest client operations.';
    return _error ?? 'Unknown error';
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
                  value: '${_metric(summary, 'onDutyNow')}',
                  color: tokens.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Checked In',
                  value: '${_metric(summary, 'checkedInToday')}',
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
                  value: '${_metric(summary, 'hourlyNightChecksToday')}',
                  color: tokens.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Pending Reports',
                  value: '${_metric(summary, 'pendingVisitReports')}',
                  color: tokens.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _metric(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.text, this.color);
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
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
