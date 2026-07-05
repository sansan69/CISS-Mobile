import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/info_line.dart';
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
  Map<String, dynamic>? _summary;
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
      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchClientDashboard()
          .timeout(const Duration(seconds: 12));
      final activities = data['recentPatrolActivities'] as List<dynamic>? ??
          const <dynamic>[];
      final summary = data['summary'] as Map<String, dynamic>?;

      if (!mounted) return;
      setState(() {
        _activities =
            activities.whereType<Map<String, dynamic>>().toList();
        _summary = summary;
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
      appBar: AppBar(
        title: const Text('Patrol Activity'),
        backgroundColor: tokens.canvas,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Error',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetch,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : _activities.isEmpty
                  ? const Center(
                      child: StateBlock(
                        icon: Icons.shield_rounded,
                        title: 'No patrol activity',
                        message:
                            'Patrol rounds and night checks will appear here.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          if (_summary != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SummaryBar(
                                summary: _summary!,
                                tokens: tokens,
                              ),
                            ),
                          ..._activities.map((a) {
                            final type =
                                a['type']?.toString() ?? 'patrol';
                            final guardName =
                                a['guardName']?.toString() ?? 'Guard';
                            final siteName =
                                a['siteName']?.toString() ?? '';
                            final dutyPoint =
                                a['dutyPointName']?.toString() ??
                                    a['patrolPointName']?.toString() ??
                                    '';
                            final shiftLabel =
                                a['shiftLabel']?.toString() ?? '';
                            final activityAt =
                                a['activityAt']?.toString() ?? '';
                            final district =
                                a['district']?.toString() ?? '';

                            final isHourlyPhoto = type == 'hourly_photo';

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12),
                              child: ModernCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isHourlyPhoto
                                                ? tokens.successSoft
                                                : tokens.accent
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            isHourlyPhoto
                                                ? Icons.photo_camera_rounded
                                                : Icons.route_rounded,
                                            size: 20,
                                            color: isHourlyPhoto
                                                ? tokens.success
                                                : tokens.accent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                guardName,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: tokens.ink,
                                                ),
                                              ),
                                              if (siteName.isNotEmpty)
                                                InfoLine(
                                                  Icons.location_on_rounded,
                                                  siteName,
                                                ),
                                              if (dutyPoint.isNotEmpty)
                                                InfoLine(
                                                  Icons.my_location_rounded,
                                                  dutyPoint,
                                                ),
                                              if (shiftLabel.isNotEmpty)
                                                InfoLine(
                                                  Icons.access_time_rounded,
                                                  shiftLabel,
                                                ),
                                              if (district.isNotEmpty)
                                                InfoLine(
                                                  Icons.place_rounded,
                                                  district,
                                                ),
                                              if (activityAt.isNotEmpty)
                                                InfoLine(
                                                  Icons.schedule_rounded,
                                                  _formatDate(activityAt),
                                                ),
                                            ],
                                          ),
                                        ),
                                        StatusChip(
                                          label: isHourlyPhoto
                                              ? 'Photo'
                                              : 'Patrol',
                                          tone: isHourlyPhoto
                                              ? StatusChipTone.success
                                              : StatusChipTone.info,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }

  String _formatDate(String value) {
    final p = DateTime.tryParse(value);
    if (p == null) return value;
    final local = p.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary, required this.tokens});

  final Map<String, dynamic> summary;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final total = (summary['patrolActivitiesToday'] as num?)?.toInt() ?? 0;
    final nightChecks =
        (summary['hourlyNightChecksToday'] as num?)?.toInt() ?? 0;

    return ModernCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Metric(
              value: '$total',
              label: 'Total Today',
              color: tokens.primary,
            ),
          ),
          Container(width: 1, height: 38, color: tokens.border),
          Expanded(
            child: _Metric(
              value: '$nightChecks',
              label: 'Night Checks',
              color: tokens.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.inkMuted,
          ),
        ),
      ],
    );
  }
}
