import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/location/live_location_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

/// Client attendance screen — shows today's guard attendance with live location.
class ClientAttendanceScreen extends ConsumerStatefulWidget {
  const ClientAttendanceScreen({super.key});

  @override
  ConsumerState<ClientAttendanceScreen> createState() =>
      _ClientAttendanceScreenState();
}

class _ClientAttendanceScreenState
    extends ConsumerState<ClientAttendanceScreen> {
  List<Map<String, dynamic>>? _records;
  bool _loading = true;
  String? _error;

  late final LiveLocationService _liveLocationService;

  @override
  void initState() {
    super.initState();
    _liveLocationService = LiveLocationService();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = ref.read(authSessionProvider).value;
      final clientId = session?.clientId ?? '';

      final records = await ref
          .read(mobileRepositoryProvider)
          .fetchClientAttendance(clientId);

      if (!mounted) return;

      setState(() {
        _records = records;
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

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              title: 'Could not load attendance',
              message: _error!,
              action: FilledButton.tonal(
                onPressed: _fetchAttendance,
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      );
    }

    final records = _records ?? const <Map<String, dynamic>>[];

    return ScreenScaffold(
      title: 'Live Attendance',
      subtitle: 'Today\'s on-duty guards',
      onRefresh: _fetchAttendance,
      children: <Widget>[
        // Live location stream
        StreamBuilder<List<GuardLocationData>>(
          stream: _liveLocationService.streamActiveLocations(),
          builder: (context, locSnap) {
            final locations = locSnap.data ?? const <GuardLocationData>[];
            final liveCount = locations.length;

            // Live dot indicator
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Live indicator pill
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: tokens.success,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: tokens.success.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$liveCount guard${liveCount == 1 ? '' : 's'} on duty now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.success,
                        ),
                      ),
                    ],
                  ),
                ),

                if (records.isEmpty)
                  const StateBlock(
                    icon: Icons.fact_check_rounded,
                    title: 'No attendance records',
                    message:
                        'Attendance data for today will appear here as guards check in.',
                  )
                else
                  ...records.map((record) {
                    final guardName =
                        (record['guardName'] as String?) ??
                            (record['fullName'] as String?) ??
                            'Guard';
                    final siteName =
                        (record['siteName'] as String?) ?? '';
                    final checkIn =
                        (record['checkIn'] as String?) ??
                            (record['checkInTime'] as String?) ??
                            '';
                    final status =
                        (record['status'] as String?) ?? 'Out';
                    final employeeId =
                        (record['employeeId'] as String?) ?? '';
                    final isIn = status == 'In';

                    // Look up live location for this guard
                    final loc = locations.cast<GuardLocationData?>().firstWhere(
                      (l) => l?.employeeId == employeeId,
                      orElse: () => null,
                    );

                    return GlassCard(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: <Widget>[
                            // Avatar
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isIn
                                  ? tokens.successSoft
                                  : tokens.surfaceMuted,
                              child: Text(
                                _initials(guardName),
                                style: TextStyle(
                                  color: isIn
                                      ? tokens.success
                                      : tokens.inkMuted,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(
                                width: AppSpacing.md),
                            // Name, site, check-in time
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
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                  if (siteName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      siteName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: tokens.inkMuted,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (checkIn.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Check-in: $checkIn',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(
                                width: AppSpacing.sm),
                            // Status + live dot
                            Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: <Widget>[
                                StatusChip(
                                  label: isIn ? 'In' : 'Out',
                                  tone: isIn
                                      ? StatusChipTone.success
                                      : StatusChipTone.neutral,
                                ),
                                if (loc != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '● LIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.success,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.map((p) => p[0]).take(2).join().toUpperCase();
    if (initials.isNotEmpty) return initials;
    return 'G';
  }
}
