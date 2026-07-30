import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class ClientPatrolActivityScreen extends ConsumerStatefulWidget {
  const ClientPatrolActivityScreen({super.key});

  @override
  ConsumerState<ClientPatrolActivityScreen> createState() =>
      _ClientPatrolActivityScreenState();
}

class _ClientPatrolActivityScreenState
    extends ConsumerState<ClientPatrolActivityScreen> {
  List<Map<String, dynamic>> _activities = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = ref.read(authSessionProvider).value;
      final clientId = session?.clientId ?? '';

      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchClientPatrolActivityList(clientId);
      if (!mounted) return;
      setState(() {
        _activities = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: StateBlock(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load patrol activity',
                        message: _error!,
                        action: FilledButton.tonal(
                          onPressed: _fetch,
                          child: const Text('Try again'),
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: ModernHero(
                            eyebrow: 'Operations',
                            title: 'Patrol Activity',
                            subtitle: '${_activities.length} activities',
                          ),
                        ),
                        if (_activities.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: StateBlock(
                              icon: Icons.route_outlined,
                              title: 'No patrol activity',
                              message:
                                  'Night checks and patrol rounds will appear here.',
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final a = _activities[index];
                                return Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16, index == 0 ? 12 : 0, 16,
                                    index == _activities.length - 1 ? 24 : 8,
                                  ),
                                  child: _ActivityCard(activity: a),
                                );
                              },
                              childCount: _activities.length,
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final Map<String, dynamic> activity;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final guardName = _text(activity['guardName']);
    final siteName = _text(activity['siteName']);
    final type = _text(activity['type']);
    final shiftLabel = _text(activity['shiftLabel']);
    final activityAt = _text(activity['activityAt']).isNotEmpty
        ? _text(activity['activityAt'])
        : _text(activity['createdAt']);

    final isCheckIn = type == 'check-in';
    final isCheckOut = type == 'check-out';
    final isPatrol = type == 'patrol' || type == 'hourly_photo';

    IconData icon;
    Color color;
    if (isCheckIn) {
      icon = Icons.login_rounded;
      color = tokens.success;
    } else if (isCheckOut) {
      icon = Icons.logout_rounded;
      color = tokens.warning;
    } else if (isPatrol) {
      icon = Icons.route_rounded;
      color = tokens.primary;
    } else {
      icon = Icons.circle_outlined;
      color = tokens.inkMuted;
    }

    return ModernCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  guardName.isNotEmpty ? guardName : 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                if (siteName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    siteName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    StatusChip(
                      label: type.toUpperCase(),
                      tone: isCheckIn
                          ? StatusChipTone.success
                          : isCheckOut
                              ? StatusChipTone.warning
                              : StatusChipTone.info,
                    ),
                    if (shiftLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        shiftLabel,
                        style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                      ),
                    ],
                  ],
                ),
                if (activityAt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    activityAt,
                    style: TextStyle(fontSize: 10, color: tokens.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _text(Object? value) => (value as String?)?.trim() ?? '';
}
