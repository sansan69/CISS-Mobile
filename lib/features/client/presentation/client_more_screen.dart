import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../shared/notification_inbox_screen.dart';
import 'client_visit_reports_screen.dart';
import 'client_training_reports_screen.dart';
import 'client_patrol_activity_screen.dart';
import 'client_orders_screen.dart';

class ClientMoreScreen extends ConsumerWidget {
  const ClientMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: <Widget>[
            Text(
              'REPORTS & TOOLS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tokens.inkMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            ModernCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _MoreTile(
                    icon: Icons.rate_review_rounded,
                    title: 'Visit Reports',
                    subtitle: 'Field officer site visit reports',
                    color: tokens.primary,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClientVisitReportsScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.school_rounded,
                    title: 'Training Reports',
                    subtitle: 'Training sessions & attendance',
                    color: tokens.success,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ClientTrainingReportsScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.shield_rounded,
                    title: 'Patrol Activity',
                    subtitle: 'Night checks & patrol rounds',
                    color: tokens.accent,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ClientPatrolActivityScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Work Orders',
                    subtitle: 'Staffing and deployments',
                    color: tokens.warning,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClientOrdersScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle: 'Your notification inbox',
                    color: tokens.danger,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationInboxScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(CissThemeTokens tokens) {
    return Divider(height: 1, color: tokens.border.withValues(alpha: 0.3));
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
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
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
      onTap: onTap,
    );
  }
}
