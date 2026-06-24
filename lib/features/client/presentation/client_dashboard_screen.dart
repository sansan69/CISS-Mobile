import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/sync_status_badge.dart';

/// Client dashboard — mobile view for client portal users.
/// Shows client identity, key metrics from backend, and feature tiles
/// that navigate to the relevant tabs in ClientShell.
class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
}

class _ClientDashboardScreenState
    extends ConsumerState<ClientDashboardScreen> {
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
          .fetchClientDashboard();

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

    if (_loading) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              title: 'Could not load dashboard',
              message: _error!,
              action: FilledButton.tonal(
                onPressed: _fetchDashboard,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final totalGuards =
        (_dashboardData?['totalGuards'] as num?)?.toInt() ?? 0;
    final onDutyToday =
        (_dashboardData?['onDutyToday'] as num?)?.toInt() ?? 0;
    final activeWorkOrders =
        (_dashboardData?['activeWorkOrders'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.sm,
              0,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              // Top bar: refresh
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    const SyncStatusBadge(),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _fetchDashboard,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: tokens.inkMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Welcome,',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: tokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clientName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(
                      label: 'CLIENT PORTAL',
                      icon: Icons.verified_user_rounded,
                      tone: StatusChipTone.info,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Metric pills
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricPill(
                        icon: Icons.groups_rounded,
                        label: 'Total Guards',
                        value: '$totalGuards',
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MetricPill(
                        icon: Icons.check_circle_outline,
                        label: 'On Duty Today',
                        value: '$onDutyToday',
                        color: tokens.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MetricPill(
                        icon: Icons.assignment_rounded,
                        label: 'Active Orders',
                        value: '$activeWorkOrders',
                        color: tokens.accent,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Feature tiles
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      _FeatureTile(
                        icon: Icons.calendar_today_rounded,
                        title: 'Live Attendance',
                        subtitle: 'See who\'s on duty right now',
                        color: tokens.success,
                        onTap: () {
                          Haptics.light();
                          ref
                              .read(clientTabIndexProvider.notifier)
                              .state = 2;
                        },
                      ),
                      Divider(
                        height: 1,
                        color: tokens.border.withValues(alpha: 0.3),
                      ),
                      _FeatureTile(
                        icon: Icons.groups_rounded,
                        title: 'Guards Directory',
                        subtitle: 'View your security personnel',
                        color: tokens.primary,
                        onTap: () {
                          Haptics.light();
                          ref
                              .read(clientTabIndexProvider.notifier)
                              .state = 1;
                        },
                      ),
                      Divider(
                        height: 1,
                        color: tokens.border.withValues(alpha: 0.3),
                      ),
                      _FeatureTile(
                        icon: Icons.assignment_turned_in_rounded,
                        title: 'Work Orders',
                        subtitle: 'View staffing and deployments',
                        color: tokens.accent,
                        onTap: () {
                          Haptics.light();
                          ref
                              .read(clientTabIndexProvider.notifier)
                              .state = 3;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Open Web Dashboard link
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: GlassCard(
                  child: InkWell(
                    onTap: () {
                      Haptics.medium();
                      launchUrl(
                        Uri.parse('https://cisskerala.site/dashboard'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: tokens.primarySoft,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              Icons.open_in_browser_rounded,
                              color: tokens.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Open Web Dashboard',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.ink,
                                  ),
                                ),
                                Text(
                                  'cisskerala.site',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: tokens.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Sign out
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Haptics.heavy();
                      ref.read(authControllerProvider).signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.danger,
                      side: BorderSide(
                        color: tokens.danger.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: tokens.inkMuted),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: tokens.inkMuted,
      ),
      onTap: onTap,
    );
  }
}
