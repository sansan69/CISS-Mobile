import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/patrol_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';

/// Field-officer view of guard patrol activity: patrol rounds and hourly
/// night-photo checks reported from the guard app. Mirrors the webapp's
/// `/patrol-activity` panel.
final FutureProvider<Map<String, dynamic>>
    fieldOfficerPatrolActivityProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchFieldOfficerPatrolActivities();
    });

String _formatIsoLabel(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
      '$hour:$minute $suffix';
}

class FieldOfficerPatrolActivityScreen extends ConsumerWidget {
  const FieldOfficerPatrolActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final async = ref.watch(fieldOfficerPatrolActivityProvider);

    return ScreenScaffold(
      title: 'Patrol Activity',
      subtitle: 'Patrol rounds and hourly night checks',
      onRefresh: () async {
        ref.invalidate(fieldOfficerPatrolActivityProvider);
      },
      children: <Widget>[
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace _) => StateBlock(
            icon: Icons.error_outline_rounded,
            title: 'Could not load patrol activity',
            message: 'Check your connection and try again.',
            action: FilledButton.tonal(
              onPressed: () =>
                  ref.invalidate(fieldOfficerPatrolActivityProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (Map<String, dynamic> data) {
            final summary =
                data['summary'] as Map<String, dynamic>? ?? const {};
            final rows = data['activities'] as List<dynamic>? ?? const [];
            final activities = rows
                .whereType<Map<String, dynamic>>()
                .map(GuardPatrolActivityModel.fromJson)
                .toList();

            if (activities.isEmpty) {
              return const StateBlock(
                icon: Icons.route_outlined,
                title: 'No patrol activity yet',
                message:
                    'Hourly night-photo submissions and patrol rounds will appear here once guards start logging them.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SummaryStrip(summary: summary),
                const SizedBox(height: 16),
                Text(
                  'Latest activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                ...activities.map(
                  (activity) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActivityCard(activity: activity),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final entries = <(String, String)>[
      ('Rounds', '${summary['patrolRounds'] ?? 0}'),
      ('Night photos', '${summary['hourlyPhotos'] ?? 0}'),
      ('Sites', '${summary['activeSites'] ?? 0}'),
      ('Guards', '${summary['uniqueGuards'] ?? 0}'),
    ];

    return Row(
      children: entries
          .map(
            (entry) => Expanded(
              child: ModernCard(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: <Widget>[
                    Text(
                      entry.$2,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final GuardPatrolActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isHourlyPhoto = activity.type == 'hourly_photo';

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  activity.guardName.isEmpty
                      ? 'Guard'
                      : activity.guardName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
              ),
              StatusChip(
                label: isHourlyPhoto ? 'Hourly photo' : 'Patrol round',
                tone: isHourlyPhoto
                    ? StatusChipTone.warning
                    : StatusChipTone.success,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activity.siteName,
            style: TextStyle(fontSize: 13, color: tokens.inkMuted),
          ),
          if (activity.patrolPointName != null) ...[
            const SizedBox(height: 2),
            Text(
              'Patrol point: ${activity.patrolPointName}',
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ],
          if (activity.notes != null && activity.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              activity.notes!,
              style: TextStyle(fontSize: 13, color: tokens.ink),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: tokens.inkMuted.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                _formatIsoLabel(activity.activityAt),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.inkMuted,
                ),
              ),
              const Spacer(),
              if (activity.photoUrl != null && activity.photoUrl!.isNotEmpty)
                GestureDetector(
                  onTap: () => _openPhoto(context, activity.photoUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      activity.photoUrl!,
                      width: 72,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 56,
                        color: tokens.surfaceMuted,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 20,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'Could not load photo',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
