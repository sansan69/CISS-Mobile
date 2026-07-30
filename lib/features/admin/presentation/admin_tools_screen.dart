import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import 'admin_bulk_import_screen.dart';
import 'admin_qr_management_screen.dart';
import 'admin_data_export_screen.dart';
import 'admin_notifications_screen.dart';

class AdminToolsScreen extends StatelessWidget {
  const AdminToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            ModernHero(
              eyebrow: 'Administration',
              title: 'Admin Tools',
              subtitle: 'Bulk operations, QR, exports & alerts',
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  _ToolCard(
                    icon: Icons.upload_file_rounded,
                    title: 'Bulk Employee Import',
                    subtitle: 'Upload employee spreadsheets',
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminBulkImportScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolCard(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'QR Management',
                    subtitle: 'Regenerate guard QR codes',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminQRManagementScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolCard(
                    icon: Icons.download_rounded,
                    title: 'Data Export',
                    subtitle: 'Export attendance, guards, payroll',
                    color: tokens.accent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminDataExportScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolCard(
                    icon: Icons.campaign_rounded,
                    title: 'Send Notifications',
                    subtitle: 'Push system-wide alerts',
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminNotificationsScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ToolCard(
                    icon: Icons.cloud_upload_rounded,
                    title: 'Deploy CORS Config',
                    subtitle: 'Update Firebase Storage CORS',
                    color: Colors.blueGrey,
                    onTap: () => _confirmDeployCors(context),
                  ),
                  const SizedBox(height: 8),
                  _ToolCard(
                    icon: Icons.verified_user_rounded,
                    title: 'Fix Email Verified',
                    subtitle: 'Bulk mark Auth users verified',
                    color: Colors.purple,
                    onTap: () => _confirmFixEmailVerified(context),
                  ),
                  const SizedBox(height: 8),
                  _ToolCard(
                    icon: Icons.build_rounded,
                    title: 'Repair Claims',
                    subtitle: 'Fix inconsistent Auth claims',
                    color: Colors.deepOrange,
                    onTap: () => _confirmRepairClaims(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeployCors(BuildContext context) {
    Haptics.heavy();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deploy CORS?'),
        content: const Text(
          'This will update Firebase Storage CORS configuration. '
          'This operation typically runs on the server side.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performServerAction(context, 'Deploying CORS...',
                  '/api/admin/deploy-cors');
            },
            child: const Text('Deploy'),
          ),
        ],
      ),
    );
  }

  void _confirmFixEmailVerified(BuildContext context) {
    Haptics.heavy();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fix Email Verified?'),
        content: const Text(
          'This will bulk-mark all Auth users as email verified. '
          'Intended for legacy accounts that were created before email verification was enforced.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performServerAction(context, 'Fixing email verified status...',
                  '/api/admin/fix-email-verified');
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _confirmRepairClaims(BuildContext context) {
    Haptics.heavy();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Repair Claims?'),
        content: const Text(
          'This will scan all Auth users and repair inconsistent '
          'custom claims (missing roles, malformed claims).',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performServerAction(context, 'Repairing claims...',
                  '/api/admin/claims/repair');
            },
            child: const Text('Repair'),
          ),
        ],
      ),
    );
  }

  Future<void> _performServerAction(
      BuildContext context, String msg, String path) async {
    Haptics.heavy();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: tokens.inkMuted, size: 20),
        ],
      ),
    );
  }
}
