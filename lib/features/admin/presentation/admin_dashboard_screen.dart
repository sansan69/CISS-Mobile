import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../core/region/region_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../core/haptics.dart';

/// Admin mobile dashboard — real-time stats and operational shortcuts.
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
    try {
      final data =
          await ref.read(mobileRepositoryProvider).fetchAdminDashboard();
      if (!mounted) return;
      setState(() {
        _stats = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final sessionAsync = ref.watch(authSessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
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
          return const Scaffold(
            body: Center(child: Text('Not signed in')),
          );
        }

        return Scaffold(
          backgroundColor: tokens.canvas,
          body: SafeArea(
            child:
                _loading ? _buildLoading(tokens) : _buildContent(tokens, session),
          ),
        );
      },
    );
  }

  Widget _buildLoading(CissThemeTokens tokens) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildContent(CissThemeTokens tokens, dynamic session) {
    final totalGuards = _stats?['totalGuards'] ?? '—';
    final activeGuards = _stats?['activeGuards'] ?? '—';
    final checkedInToday = _stats?['checkedInToday'] ?? '—';
    final pendingOrders = _stats?['pendingWorkOrders'] ?? '—';

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.admin_panel_settings_rounded,
                    color: tokens.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.displayName,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink)),
                    Text(session.role.label,
                        style: TextStyle(
                            fontSize: 13, color: tokens.inkMuted)),
                  ],
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            StateBlock(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load stats',
              message: 'Showing cached view. Pull to retry.',
            ),
          ],

          const SizedBox(height: 24),

          // ── Key Metrics ──
          Text('KEY METRICS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tokens.inkMuted,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _MetricCard(
                      icon: Icons.groups_rounded,
                      label: 'Total Guards',
                      value: '$totalGuards',
                      color: tokens.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _MetricCard(
                      icon: Icons.verified_user_rounded,
                      label: 'Active',
                      value: '$activeGuards',
                      color: tokens.success)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _MetricCard(
                      icon: Icons.login_rounded,
                      label: 'Checked In Today',
                      value: '$checkedInToday',
                      color: tokens.accent)),
              const SizedBox(width: 12),
              Expanded(
                  child: _MetricCard(
                      icon: Icons.assignment_rounded,
                      label: 'Pending Orders',
                      value: '$pendingOrders',
                      color: tokens.warning)),
            ],
          ),

          const SizedBox(height: 28),

          // ── Quick Actions ──
          Text('QUICK LINKS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tokens.inkMuted,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                _LinkTile(
                  icon: Icons.open_in_browser_rounded,
                  title: 'Open Web Dashboard',
                  subtitle: 'Open the active region admin panel',
                  color: tokens.primary,
                  onTap: () {
                    Haptics.light();
                    _openDashboard();
                  },
                ),
                Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
                _LinkTile(
                  icon: Icons.people_rounded,
                  title: 'Employees Directory',
                  subtitle: 'Manage guard profiles and assignments',
                  color: tokens.success,
                  onTap: () {
                    Haptics.light();
                    ref.read(adminTabIndexProvider.notifier).state = 1;
                  },
                ),
                Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
                _LinkTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'Attendance Logs',
                  subtitle: 'View all check-in/out records',
                  color: tokens.accent,
                  onTap: () {
                    Haptics.light();
                    ref.read(adminTabIndexProvider.notifier).state = 2;
                  },
                ),
                Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
                _LinkTile(
                  icon: Icons.assignment_turned_in_rounded,
                  title: 'Work Orders',
                  subtitle: 'Deployment and staffing management',
                  color: tokens.warning,
                  onTap: () {
                    Haptics.light();
                    ref.read(adminTabIndexProvider.notifier).state = 3;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Sign Out ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Haptics.heavy();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('You will be signed out of your account.'),
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
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDashboard() async {
    final rawBase = RegionService.instance.activeApiUrl;
    final base = rawBase.endsWith('/') ? rawBase.substring(0, rawBase.length - 1) : rawBase;
    final uri = Uri.parse('$base/dashboard');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    return GlassCard(
      padding: const EdgeInsets.all(16),
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: CissThemeTokens.of(context).inkMuted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
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
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
      onTap: onTap,
    );
  }
}
