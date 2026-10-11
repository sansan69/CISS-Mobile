import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/screen_scaffold.dart';
import '../../../../shared/widgets/modern_card.dart';
import '../../../../shared/widgets/sync_status_badge.dart';
import '../../../../shared/widgets/state_block.dart';
import '../../../../core/sync/refresh_controller.dart';
import '../../../../core/sync/providers.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/models/incident_models.dart';
import '../../../../core/models/mobile_dashboard_models.dart';
import '../../../../core/region/region_service.dart';

final FutureProvider<List<IncidentModel>> fieldOfficerIncidentsProvider =
    FutureProvider<List<IncidentModel>>(
      (ref) => ref.read(mobileRepositoryProvider).fetchFieldOfficerIncidents(),
    );

final FutureProvider<List<FieldOfficerSiteOption>> fieldOfficerSitesProvider =
    FutureProvider<List<FieldOfficerSiteOption>>(
      (ref) => ref.read(mobileRepositoryProvider).fetchFieldOfficerSites(),
    );

/// FO incidents overview — lists recent guard-reported incidents.
class FieldOfficerIncidentsScreen extends ConsumerWidget {
  const FieldOfficerIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final incidents = ref.watch(fieldOfficerIncidentsProvider);

    return ScreenScaffold(
      title: 'Incidents',
      subtitle: 'Recent guard-reported incidents',
      onRefresh: () async => ref.invalidate(fieldOfficerIncidentsProvider),
      children: incidents.when(
        loading: () => const [Center(child: CircularProgressIndicator())],
        error:
            (error, _) => [
              StateBlock(
                icon: Icons.warning_amber_rounded,
                title: 'Could not load incidents',
                message: '$error',
                action: FilledButton.tonal(
                  onPressed:
                      () => ref.invalidate(fieldOfficerIncidentsProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
        data:
            (items) =>
                items.isEmpty
                    ? [
                      const StateBlock(
                        icon: Icons.warning_amber_rounded,
                        title: 'No recent incidents',
                        message:
                            'Guard-reported incidents in your districts will appear here.',
                      ),
                    ]
                    : items
                        .map(
                          (incident) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ModernCard(
                              child: ListTile(
                                onTap: () => _showIncidentDetail(context, incident),
                                leading: Icon(
                                  Icons.warning_amber_rounded,
                                  color:
                                      incident.severity.toLowerCase() == 'high'
                                          ? tokens.danger
                                          : tokens.warning,
                                ),
                                title: Text(
                                  incident.siteName.isEmpty
                                      ? incident.category
                                      : incident.siteName,
                                ),
                                subtitle: Text(
                                  '${incident.severity} · ${incident.status}\n${incident.summary}',
                                ),
                                isThreeLine: true,
                                trailing: Text(
                                  incident.reportedAtLabel.isEmpty
                                      ? ''
                                      : incident.reportedAtLabel
                                          .split('T')
                                          .first,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
      ),
    );
  }
}

/// FO sites list — shows sites in the field officer's district.
class FieldOfficerSitesScreen extends ConsumerWidget {
  const FieldOfficerSitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(fieldOfficerSitesProvider);

    return ScreenScaffold(
      title: 'Sites',
      subtitle: 'Assigned sites in your district',
      onRefresh: () async => ref.invalidate(fieldOfficerSitesProvider),
      children: sites.when(
        loading: () => const [Center(child: CircularProgressIndicator())],
        error:
            (error, _) => [
              StateBlock(
                icon: Icons.place_rounded,
                title: 'Could not load sites',
                message: '$error',
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(fieldOfficerSitesProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
        data:
            (items) =>
                items.isEmpty
                    ? [
                      const StateBlock(
                        icon: Icons.place_rounded,
                        title: 'No sites in scope',
                        message: 'Assigned sites will appear here.',
                      ),
                    ]
                    : items
                        .map(
                          (site) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ModernCard(
                              child: ListTile(
                                onTap: () => _showSiteDetail(context, site),
                                leading: const Icon(Icons.place_rounded),
                                title: Text(site.siteName),
                                subtitle: Text(
                                  '${site.clientName}\n${site.district}',
                                ),
                                isThreeLine: true,
                              ),
                            ),
                          ),
                        )
                        .toList(),
      ),
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
    final queue = ref.watch(offlineQueueProvider);

    return ScreenScaffold(
      title: 'Sync & Connectivity',
      subtitle: 'Data sync status and diagnostics',
      children: [
        ModernCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SyncStatusBadge(),
                    const SizedBox(width: 10),
                    Text(
                      'Connection Status',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  label: 'Auto-refresh',
                  value: refreshState.isActive ? 'Active' : 'Paused',
                ),
                _InfoRow(label: 'Refresh interval', value: '30 seconds'),
                _InfoRow(label: 'Queued actions', value: '${queue.queueSize}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ModernCard(
          child: ListTile(
            leading: Icon(Icons.refresh_rounded, color: tokens.primary),
            title: Text(
              'Force Sync Now',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Manually refresh all data'),
            onTap: () async {
              await ref.read(syncServiceProvider).processQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      queue.queueSize == 0
                          ? 'Sync complete'
                          : '${queue.queueSize} action(s) still pending',
                    ),
                    backgroundColor: tokens.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
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
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink,
            ),
          ),
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
        ModernCard(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.phone_rounded, color: tokens.success),
                title: Text(
                  'Call Supervisor',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Contact operations helpline directly'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  final uri = Uri(scheme: 'tel', path: '+914842345678');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      showDialog<void>(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: const Text('Direct Helpline'),
                              content: const Text(
                                'Please dial CISS Operations directly at +91 484 234 5678.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                      );
                    }
                  }
                },
              ),
              Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
              ListTile(
                leading: Icon(Icons.mail_outline, color: tokens.primary),
                title: Text(
                  'Email Support',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Send a message to the admin team'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  final email =
                      RegionService.instance.activeRegion?.code == 'KL'
                          ? 'support@cisskerala.site'
                          : 'support@cissworkforce.com';
                  launchUrl(
                    Uri(scheme: 'mailto', path: email),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              Divider(height: 1, color: tokens.border.withValues(alpha: 0.3)),
              ListTile(
                leading: Icon(Icons.menu_book_rounded, color: tokens.accent),
                title: Text(
                  'User Guide',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Comprehensive field officer manual'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _showGuideSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _showIncidentDetail(BuildContext context, IncidentModel incident) {
  final tokens = CissThemeTokens.of(context);
  final isHigh = incident.severity.toLowerCase() == 'high';
  final isMed = incident.severity.toLowerCase() == 'medium';
  final toneColor =
      isHigh ? tokens.danger : (isMed ? tokens.warning : tokens.accent);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder:
        (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder:
              (ctx, scrollController) => ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: toneColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: toneColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              incident.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: toneColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              incident.siteName.isEmpty
                                  ? 'Incident Report'
                                  : incident.siteName,
                              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: tokens.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text('Severity: ${incident.severity}'),
                        backgroundColor: toneColor.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: toneColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text('Status: ${incident.status}'),
                        backgroundColor: tokens.surfaceMuted,
                        labelStyle: TextStyle(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (incident.district != null &&
                          incident.district!.isNotEmpty)
                        Chip(
                          label: Text(incident.district!),
                          backgroundColor: tokens.surfaceMuted,
                          labelStyle: TextStyle(
                            color: tokens.inkMuted,
                            fontSize: 12,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    incident.summary.isEmpty
                        ? 'No description provided.'
                        : incident.summary,
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.ink,
                      height: 1.4,
                    ),
                  ),
                  if (incident.locationText != null &&
                      incident.locationText!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Location Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      incident.locationText!,
                      style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                    ),
                  ],
                  if (incident.photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Incident Photos (${incident.photoUrls.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: incident.photoUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder:
                            (ctx, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.sm,
                              ),
                              child: Image.network(
                                incident.photoUrls[i],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Container(
                                      width: 120,
                                      height: 120,
                                      color: tokens.surfaceMuted,
                                      child: const Icon(
                                        Icons.broken_image_rounded,
                                      ),
                                    ),
                              ),
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Reported: ${incident.reportedAtLabel}',
                    style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
        ),
  );
}

void _showSiteDetail(BuildContext context, FieldOfficerSiteOption site) {
  final tokens = CissThemeTokens.of(context);
  final hasCoords = site.latitude != null && site.longitude != null;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder:
        (ctx) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      color: tokens.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.clientName.isEmpty
                              ? 'Site Details'
                              : site.clientName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.inkMuted,
                          ),
                        ),
                        Text(
                          site.siteName,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _DetailRow(label: 'District', value: site.district),
              _DetailRow(
                label: 'Client',
                value: site.clientName.isEmpty ? 'N/A' : site.clientName,
              ),
              _DetailRow(
                label: 'Coordinates',
                value:
                    hasCoords
                        ? '${site.latitude!.toStringAsFixed(5)}, ${site.longitude!.toStringAsFixed(5)}'
                        : 'Not configured',
              ),
              const SizedBox(height: 20),
              if (hasCoords) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final mapUrl = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${site.latitude},${site.longitude}',
                      );
                      launchUrl(mapUrl, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Open in Google Maps'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

void _showGuideSheet(BuildContext context) {
  final tokens = CissThemeTokens.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder:
        (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder:
              (ctx, scrollController) => ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Field Officer Guide',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Essential workflows and operations',
                    style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _GuideItem(
                    icon: Icons.assignment_turned_in_rounded,
                    color: tokens.primary,
                    title: 'Duties & Attendance',
                    description:
                        'Monitor live guard check-ins and check-outs across all posts in your district. Switch between Live Feed and History, filter by site, and view real-time GPS locations on the live map.',
                  ),
                  _GuideItem(
                    icon: Icons.rate_review_rounded,
                    color: tokens.accent,
                    title: 'Daily & Visit Reports',
                    description:
                        'File site inspection reports, guard turnout evaluations, and safety checks directly from the Reports tab with photographic evidence. Photos automatically upload to the secure cloud bucket.',
                  ),
                  _GuideItem(
                    icon: Icons.warning_amber_rounded,
                    color: tokens.warning,
                    title: 'Incident Oversight',
                    description:
                        'View security incidents and emergency alerts submitted by guards at your sites. Tap any incident to see its severity, photos, and location details.',
                  ),
                  _GuideItem(
                    icon: Icons.school_rounded,
                    color: tokens.success,
                    title: 'Training & Skill Modules',
                    description:
                        'Assign safety, fire drill, and protocol training modules to guards under your supervision. Review completion progress and assign required due dates.',
                  ),
                  _GuideItem(
                    icon: Icons.wifi_off_rounded,
                    color: tokens.inkMuted,
                    title: 'Offline Syncing',
                    description:
                        'If connectivity is lost while visiting remote client sites, your reports and submissions are securely stored locally on the device and will sync automatically once online.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got It'),
                    ),
                  ),
                ],
              ),
        ),
  );
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.inkMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
