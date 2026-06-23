import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';

/// Client dashboard — mobile view for client portal users.
/// Shows client identity, key metrics, and sign-out.
class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(authSessionProvider);
    final tokens = CissThemeTokens.of(context);

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

        final clientName = session.clientName ?? session.displayName;

        return Scaffold(
          backgroundColor: tokens.canvas,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.business_rounded,
                          color: tokens.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: tokens.ink,
                              ),
                            ),
                            Text(
                              'Client Portal',
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Dashboard metrics
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Client Dashboard',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink)),
                          const SizedBox(height: 6),
                          Text(
                            'View guard attendance, work orders, and reports for your sites.',
                            style: TextStyle(
                                fontSize: 13, color: tokens.inkMuted),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetricPill(
                                icon: Icons.groups_rounded,
                                label: 'Guards',
                                value: '—',
                                color: tokens.primary,
                              ),
                              _MetricPill(
                                icon: Icons.check_circle_outline,
                                label: 'On Duty',
                                value: '—',
                                color: tokens.success,
                              ),
                              _MetricPill(
                                icon: Icons.assignment_rounded,
                                label: 'Orders',
                                value: '—',
                                color: tokens.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feature cards
                  GlassCard(
                    child: Column(
                      children: [
                        _FeatureTile(
                          icon: Icons.calendar_today_rounded,
                          title: 'Live Attendance',
                          subtitle: 'See who\'s on duty right now',
                          color: tokens.success,
                        ),
                        Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
                        _FeatureTile(
                          icon: Icons.assignment_turned_in_rounded,
                          title: 'Work Orders',
                          subtitle: 'View staffing and deployment',
                          color: tokens.primary,
                        ),
                        Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
                        _FeatureTile(
                          icon: Icons.fact_check_rounded,
                          title: 'Visit Reports',
                          subtitle: 'Field officer site visit summaries',
                          color: tokens.warning,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Sign out
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(authControllerProvider).signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
    );
  }
}
