import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';

/// Admin dashboard — lightweight mobile command center.
/// Shows logged-in identity with sign-out.
/// Further admin features (reports, work orders, etc.) to be added incrementally.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

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
                          color: tokens.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: tokens.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.displayName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: tokens.ink,
                              ),
                            ),
                            Text(
                              session.role.label,
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

                  // Quick stats card
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Dashboard',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink)),
                          const SizedBox(height: 6),
                          Text(
                            'Full admin features are available on the web dashboard.',
                            style: TextStyle(
                                fontSize: 13, color: tokens.inkMuted),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _StatChip(
                                  icon: Icons.email_outlined,
                                  label: session.email ?? '—',
                                  color: tokens.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick link to web
                  GlassCard(
                    child: ListTile(
                      leading: Icon(Icons.open_in_browser_rounded,
                          color: tokens.primary),
                      title: Text('Open Web Dashboard',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tokens.ink)),
                      subtitle: Text('cisskerala.site',
                          style: TextStyle(
                              fontSize: 12, color: tokens.inkMuted)),
                      trailing:
                          Icon(Icons.arrow_forward_ios, size: 14, color: tokens.inkMuted),
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
