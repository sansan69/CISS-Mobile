import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../core/region/region_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../core/haptics.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStats());
  }

  Future<void> _fetchStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchAdminDashboard()
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _stats = data;
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

    return sessionAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => Scaffold(
            body: Center(
              child: StateBlock(
                icon: Icons.error_outline,
                title: 'Session error',
                message: error.toString(),
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(authSessionProvider),
                  child: const Text('Retry'),
                ),
              ),
            ),
          ),
      data: (session) {
        if (session == null) {
          return const Scaffold(body: Center(child: Text('Not signed in')));
        }

        final regionLabel = RegionService.instance.activeRegion?.name ?? '';

        return Scaffold(
          backgroundColor: tokens.canvas,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchStats,
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ModernHero(
                    eyebrow: session.displayName,
                    title: 'Admin Portal',
                    subtitle:
                        regionLabel.isNotEmpty ? regionLabel : null,
                    avatarText: _initialsFromName(session.displayName),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 20),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: StateBlock(
                              icon: Icons.cloud_off_rounded,
                              title: 'Could not load stats',
                              message: _error!,
                              action: FilledButton.tonal(
                                onPressed: _fetchStats,
                                child: const Text('Try again'),
                              ),
                            ),
                          ),
                        _buildMetricRow(tokens),
                        const SizedBox(height: 24),
                        _buildInfographics(tokens),
                        const SizedBox(height: 24),
                        _buildQuickActions(tokens),
                        const SizedBox(height: 24),
                        _buildActivityFeed(tokens),
                        const SizedBox(height: 8),
                        _buildSignOut(tokens),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricRow(CissThemeTokens tokens) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: <Widget>[
          MetricCard(
            label: 'Total Guards',
            value: _loading ? '...' : '${_stats?['totalGuards'] ?? '—'}',
            color: tokens.primary,
            width: 128,
          ),
          const SizedBox(width: 12),
          MetricCard(
            label: 'On Duty',
            value: _loading ? '...' : '${_stats?['activeGuards'] ?? '—'}',
            color: tokens.success,
            width: 128,
          ),
          const SizedBox(width: 12),
          MetricCard(
            label: 'Checked In',
            value: _loading ? '...' : '${_stats?['checkedInToday'] ?? '—'}',
            color: tokens.accent,
            width: 128,
          ),
          const SizedBox(width: 12),
          MetricCard(
            label: 'Pending Orders',
            value:
                _loading ? '...' : '${_stats?['pendingWorkOrders'] ?? '—'}',
            color: tokens.warning,
            width: 128,
          ),
          const SizedBox(width: 12),
          MetricCard(
            label: 'Total Clients',
            value: _loading ? '...' : '${_stats?['totalClients'] ?? '—'}',
            color: tokens.primary,
            width: 128,
          ),
          const SizedBox(width: 12),
          MetricCard(
            label: 'Total Sites',
            value: _loading ? '...' : '${_stats?['totalSites'] ?? '—'}',
            color: tokens.success,
            width: 128,
          ),
        ],
      ),
    );
  }

  Widget _buildInfographics(CissThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'INFOGRAPHICS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: tokens.inkMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        _buildDailyAttendance(tokens),
        const SizedBox(height: 12),
        _buildDistrictEnrollment(tokens),
        const SizedBox(height: 12),
        _buildTcsUpcomingDuties(tokens),
        const SizedBox(height: 12),
        _buildFieldOfficerReportStatus(tokens),
      ],
    );
  }

  Widget _buildDailyAttendance(CissThemeTokens tokens) {
    final list = _stats?['dailyAttendancePerClient'] as List<dynamic>?;
    final hasData = list != null && list.isNotEmpty;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.successSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fact_check_rounded,
                    size: 16, color: tokens.success),
              ),
              const SizedBox(width: 10),
              Text(
                'Daily Attendance per Client',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData && _loading)
            const Center(child: LinearProgressIndicator())
          else if (!hasData)
            _emptyInline(tokens, 'No attendance data available')
          else
            ...list.map((item) {
              final map = item as Map<String, dynamic>;
              final name = _text(map['clientName']).isNotEmpty
                  ? _text(map['clientName'])
                  : _text(map['name']);
              final checkedIn = _num(map['checkedIn']);
              final total = _num(map['totalGuards']);
              final pct = total > 0 ? (checkedIn / total).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name.isNotEmpty ? name : 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.ink,
                            ),
                          ),
                        ),
                        Text(
                          '$checkedIn / $total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: tokens.surfaceMuted,
                        color: pct >= 0.8 ? tokens.success : tokens.warning,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDistrictEnrollment(CissThemeTokens tokens) {
    final list = _stats?['districtEnrollment'] as List<dynamic>?;
    final hasData = list != null && list.isNotEmpty;
    int total = 0;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pin_drop_rounded,
                    size: 16, color: tokens.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'District-wise Enrollment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            _emptyInline(tokens, 'No district data available')
          else
            ...list.map((item) {
              final map = item as Map<String, dynamic>;
              final name = _text(map['district']).isNotEmpty
                  ? _text(map['district'])
                  : _text(map['name']);
              final count = _num(map['guardCount']);
              total += count;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        name.isNotEmpty ? name : 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (hasData) ...[
            Divider(height: 1, color: tokens.border),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                ),
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tokens.primaryStrong,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTcsUpcomingDuties(CissThemeTokens tokens) {
    final list = _stats?['tcsUpcomingDuties'] as List<dynamic>?;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.warningSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    size: 16, color: tokens.warning),
              ),
              const SizedBox(width: 10),
              Text(
                'TCS Upcoming Duties',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (list == null || list.isEmpty)
            _emptyInline(tokens, 'No upcoming TCS duties')
          else
            ...list.take(5).map((item) {
              final map = item as Map<String, dynamic>;
              final site = _text(map['siteName']).isNotEmpty
                  ? _text(map['siteName'])
                  : _text(map['site']);
              final date = _text(map['date']).isNotEmpty
                  ? _text(map['date'])
                  : _text(map['dateLabel']);
              final guardsReq = _num(map['guardsRequired']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            site.isNotEmpty ? site : 'Unknown Site',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.ink,
                            ),
                          ),
                          if (date.isNotEmpty)
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tokens.warningSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$guardsReq guards',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tokens.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFieldOfficerReportStatus(CissThemeTokens tokens) {
    final list = _stats?['fieldOfficerReportStatus'] as List<dynamic>?;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.engineering_rounded,
                    size: 16, color: tokens.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Field Officer Report Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (list == null || list.isEmpty)
            _emptyInline(tokens, 'No field officer data available')
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Officer',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF607080)),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Visit Reports',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF607080)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Training',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tokens.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.border),
            ...list.map((item) {
              final map = item as Map<String, dynamic>;
              final name = _text(map['officerName']).isNotEmpty
                  ? _text(map['officerName'])
                  : _text(map['name']);
              final visitReports = _num(map['visitReports']);
              final trainingReports = _num(map['trainingReports']);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: Text(
                        name.isNotEmpty ? name : 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$visitReports',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: visitReports > 0
                              ? tokens.primary
                              : tokens.inkMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$trainingReports',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: trainingReports > 0
                              ? tokens.success
                              : tokens.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions(CissThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: tokens.inkMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _QuickActionPill(
              icon: Icons.person_add_rounded,
              label: 'Enroll Guard',
              color: tokens.success,
              onTap: () {
                Haptics.light();
                // navigate to enrollment
              },
            ),
            _QuickActionPill(
              icon: Icons.payments_rounded,
              label: 'Run Payroll',
              color: tokens.accent,
              onTap: () {
                Haptics.light();
                // navigate to payroll
              },
            ),
            _QuickActionPill(
              icon: Icons.campaign_rounded,
              label: 'Send Alert',
              color: tokens.warning,
              onTap: () {
                Haptics.light();
                // navigate to notifications
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityFeed(CissThemeTokens tokens) {
    final list = _stats?['recentActivity'] as List<dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'LIVE ACTIVITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: tokens.inkMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ModernCard(
          child: list == null || list.isEmpty
              ? _emptyInline(tokens, 'No recent activity')
              : Column(
                  children: list.take(8).map((item) {
                    final map = item as Map<String, dynamic>;
                    final message = _text(map['message']).isNotEmpty
                        ? _text(map['message'])
                        : _text(map['description']);
                    final timestamp = _text(map['timestamp']).isNotEmpty
                        ? _text(map['timestamp'])
                        : _text(map['createdAt']);
                    final isLast = list.indexOf(item) ==
                        (list.length > 8 ? 7 : list.length - 1);
                    return Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tokens.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    message.isNotEmpty
                                        ? message
                                        : 'Activity',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.ink,
                                    ),
                                  ),
                                  if (timestamp.isNotEmpty)
                                    Text(
                                      timestamp,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.inkMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!isLast)
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 4, top: 8, bottom: 8),
                            child: Container(
                              width: 1,
                              height: 12,
                              color: tokens.border,
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSignOut(CissThemeTokens tokens) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          Haptics.heavy();
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'You will be signed out of your account.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(authControllerProvider).signOut();
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
          );
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(foregroundColor: tokens.danger),
      ),
    );
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  String _text(Object? value) => (value as String?)?.trim() ?? '';

  int _num(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_text(value)) ?? 0;
  }

  Widget _emptyInline(CissThemeTokens tokens, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: tokens.inkMuted),
        ),
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: tokens.ink,
      ),
      backgroundColor: tokens.surface,
      side: BorderSide(color: tokens.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
