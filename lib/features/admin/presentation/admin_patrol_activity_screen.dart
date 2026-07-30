import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

final FutureProvider<List<Map<String, dynamic>>> adminPatrolActivitiesProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.read(mobileRepositoryProvider).fetchAdminPatrolActivities();
});

class AdminPatrolActivityScreen extends ConsumerWidget {
  const AdminPatrolActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final activitiesAsync = ref.watch(adminPatrolActivitiesProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminPatrolActivitiesProvider),
          child: activitiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: StateBlock(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load patrol activities',
                message: error.toString().replaceFirst('Exception: ', ''),
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(adminPatrolActivitiesProvider),
                  child: const Text('Try again'),
                ),
              ),
            ),
            data: (activities) => CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: ModernHero(
                    eyebrow: 'Operations',
                    title: 'Patrol Activity',
                    subtitle: 'Night checks, hourly rounds & guard patrols',
                  ),
                ),
                if (activities.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateBlock(
                      icon: Icons.route_outlined,
                      title: 'No patrol activity',
                      message: 'Guard patrol activities will appear here.',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final activity = activities[index];
                        final guardName = _text(activity['guardName']);
                        final siteName = _text(activity['siteName']);
                        final type = _text(activity['type']);
                        final activityAt = _text(activity['activityAt'])
                            .isNotEmpty
                            ? _text(activity['activityAt'])
                            : _text(activity['createdAt']);
                        final shiftLabel = _text(activity['shiftLabel']);
                        final notes = _text(activity['notes']);

                        final isPatrol = type == 'patrol' || type == 'night-check';
                        final isCheckIn = type == 'check-in';
                        final isCheckOut = type == 'check-out';

                        IconData activityIcon;
                        Color activityColor;
                        if (isCheckIn) {
                          activityIcon = Icons.login_rounded;
                          activityColor = tokens.success;
                        } else if (isCheckOut) {
                          activityIcon = Icons.logout_rounded;
                          activityColor = tokens.warning;
                        } else if (isPatrol) {
                          activityIcon = Icons.route_rounded;
                          activityColor = tokens.primary;
                        } else {
                          activityIcon = Icons.circle_outlined;
                          activityColor = tokens.inkMuted;
                        }

                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            16, index == 0 ? 12 : 0, 16,
                            index == activities.length - 1 ? 24 : 8,
                          ),
                          child: ModernCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: activityColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(activityIcon,
                                      color: activityColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        guardName.isNotEmpty ? guardName : 'Unknown Guard',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (siteName.isNotEmpty)
                                        Text(
                                          siteName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: <Widget>[
                                          StatusChip(
                                            label: type.toUpperCase(),
                                            tone: isCheckIn
                                                ? StatusChipTone.success
                                                : isCheckOut
                                                    ? StatusChipTone.warning
                                                    : isPatrol
                                                        ? StatusChipTone.info
                                                        : StatusChipTone.neutral,
                                          ),
                                          const SizedBox(width: 6),
                                          if (shiftLabel.isNotEmpty)
                                            Text(
                                              shiftLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: tokens.inkMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (notes.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.ink,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        activityAt.isNotEmpty
                                            ? activityAt
                                            : 'No timestamp',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: activities.length,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _text(Object? value) => (value as String?)?.trim() ?? '';
}
