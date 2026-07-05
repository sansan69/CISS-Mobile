import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/screen_scaffold.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/sync_status_badge.dart';
import '../../../../core/sync/refresh_controller.dart';

/// FO incidents overview — lists recent guard-reported incidents.
class FieldOfficerIncidentsScreen extends ConsumerWidget {
  const FieldOfficerIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return ScreenScaffold(
      title: 'Incidents',
      subtitle: 'Recent guard-reported incidents',
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: tokens.warning, size: 32),
              const SizedBox(height: 12),
              Text('No recent incidents',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink)),
              const SizedBox(height: 4),
              Text(
                'Incidents reported by guards in your districts will appear here.',
                style: TextStyle(fontSize: 13, color: tokens.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// FO sites list — shows sites in the field officer's district.
class FieldOfficerSitesScreen extends ConsumerWidget {
  const FieldOfficerSitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return ScreenScaffold(
      title: 'Sites',
      subtitle: 'Assigned sites in your district',
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_rounded, color: tokens.primary, size: 32),
              const SizedBox(height: 12),
              Text('Site directory',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink)),
              const SizedBox(height: 4),
              Text(
                'Site locations and deployment details will be available here.',
                style: TextStyle(fontSize: 13, color: tokens.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// FO sync logs — shows sync status and refresh info.
class FieldOfficerSyncLogsScreen extends ConsumerWidget {
  const FieldOfficerSyncLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final refreshState = ref.watch(refreshControllerProvider);

    return ScreenScaffold(
      title: 'Sync & Connectivity',
      subtitle: 'Data sync status and diagnostics',
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SyncStatusBadge(),
                    const SizedBox(width: 10),
                    Text('Connection Status',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink)),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Auto-refresh', value: refreshState.isActive ? 'Active' : 'Paused'),
                _InfoRow(label: 'Refresh interval', value: '30 seconds'),
                _InfoRow(label: 'Last sync', value: '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: ListTile(
            leading: Icon(Icons.refresh_rounded, color: tokens.primary),
            title: Text('Force Sync Now',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Manually refresh all data'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Sync initiated'),
                  backgroundColor: tokens.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink)),
        ],
      ),
    );
  }
}

/// FO support screen — help and contact info.
class FieldOfficerSupportScreen extends ConsumerWidget {
  const FieldOfficerSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);

    return ScreenScaffold(
      title: 'Support',
      subtitle: 'Help resources and contact',
      children: [
        GlassCard(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.phone_rounded, color: tokens.success),
                title: Text('Call Supervisor',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Contact your field supervisor directly'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              ),
              Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
              ListTile(
                leading: Icon(Icons.mail_outline, color: tokens.primary),
                title: Text('Email Support',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Send a message to the admin team'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              ),
              Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
              ListTile(
                leading: Icon(Icons.menu_book_rounded, color: tokens.accent),
                title: Text('User Guide',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('How to use the field officer app'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
