import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../shared/notification_inbox_screen.dart';
import 'admin_training_screen.dart';
import 'admin_evaluations_screen.dart';
import 'admin_payroll_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_field_officers_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_enroll_guard_screen.dart';
import 'admin_clients_sites_screen.dart';
import 'admin_bulk_import_screen.dart';
import 'admin_qr_management_screen.dart';
import 'admin_data_export_screen.dart';
import 'admin_wage_config_screen.dart';
import 'admin_enrollment_config_screen.dart';

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'MANAGEMENT TOOLS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tokens.inkMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _MoreTile(
                    icon: Icons.school_rounded,
                    title: 'Training',
                    subtitle: 'Modules, question banks & assignments',
                    color: tokens.primary,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminTrainingScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.leaderboard_rounded,
                    title: 'Evaluations & Leaderboard',
                    subtitle: 'Performance scores & rankings',
                    color: tokens.success,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminEvaluationsScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.payments_rounded,
                    title: 'Payroll',
                    subtitle: 'Cycles, payslips & wage config',
                    color: tokens.accent,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminPayrollScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'Clients, sites & system config',
                    color: tokens.warning,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminSettingsScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.engineering_rounded,
                    title: 'Field Officers',
                    subtitle: 'Manage field officer accounts',
                    color: Colors.purple,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminFieldOfficersScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.campaign_rounded,
                    title: 'Send Notifications',
                    subtitle: 'Push alerts to guards & officers',
                    color: Colors.orange,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminNotificationsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ADMINISTRATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tokens.inkMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _MoreTile(
                    icon: Icons.person_add_rounded,
                    title: 'Enroll Guard',
                    subtitle: 'Register a new guard',
                    color: tokens.success,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminEnrollGuardScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.business_rounded,
                    title: 'Clients & Sites',
                    subtitle: 'Manage clients and their sites',
                    color: tokens.primary,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminClientsSitesScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.upload_file_rounded,
                    title: 'Bulk Import',
                    subtitle: 'Import employees from spreadsheet',
                    color: Colors.teal,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminBulkImportScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'QR Management',
                    subtitle: 'Regenerate guard QR codes',
                    color: Colors.indigo,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminQRManagementScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.download_rounded,
                    title: 'Data Export',
                    subtitle: 'Export attendance, guards, payroll',
                    color: tokens.accent,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminDataExportScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.monetization_on_rounded,
                    title: 'Wage Config',
                    subtitle: 'Configure wage components per client',
                    color: Colors.green,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminWageConfigScreen()),
                      );
                    },
                  ),
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.list_alt_rounded,
                    title: 'Enrollment Config',
                    subtitle: 'Customize enrollment form fields',
                    color: Colors.blueGrey,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                        context,
                        _adminRoute(const AdminEnrollmentConfigScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'YOUR ACCOUNT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tokens.inkMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _MoreTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notification Inbox',
                    subtitle: 'View your notifications',
                    color: tokens.primary,
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
                  _divider(tokens),
                  _MoreTile(
                    icon: Icons.open_in_browser_rounded,
                    title: 'Open Web Dashboard',
                    subtitle: 'Full admin panel in browser',
                    color: Colors.teal,
                    onTap: () {
                      Haptics.light();
                      final rawBase = ref
                          .read(mobileRepositoryProvider)
                          .apiClient
                          .dio
                          .options
                          .baseUrl;
                      final base = rawBase.endsWith('/')
                          ? rawBase.substring(0, rawBase.length - 1)
                          : rawBase;
                      launchUrl(
                        Uri.parse('$base/dashboard'),
                        mode: LaunchMode.externalApplication,
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

  Route _adminRoute(Widget screen) {
    return MaterialPageRoute(builder: (_) => screen);
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
