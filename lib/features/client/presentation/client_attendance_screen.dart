import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/location/live_location_service.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

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
  String _selectedDateFilter = 'Today';

  static const _dateFilters = ['Today', 'Yesterday', 'This Week'];

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

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: StreamBuilder<List<GuardLocationData>>(
          stream: _liveLocationService.streamActiveLocations(),
          builder: (context, locSnap) {
            final locations = locSnap.data ?? const <GuardLocationData>[];
            final liveCount = locations.length;

            return RefreshIndicator(
              onRefresh: _fetchAttendance,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  Row(
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
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _dateFilters.map((filter) {
                        final isSelected = filter == _selectedDateFilter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedDateFilter = filter);
                            },
                            selectedColor: tokens.primarySoft,
                            checkmarkColor: tokens.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? tokens.primary : tokens.inkMuted,
                            ),
                            side: BorderSide(
                              color:
                                  isSelected ? tokens.primary : tokens.border,
                            ),
                            backgroundColor: tokens.surface,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
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

                      final loc = locations
                          .cast<GuardLocationData?>()
                          .firstWhere(
                            (l) => l?.employeeId == employeeId,
                            orElse: () => null,
                          );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ModernCard(
                          child: Row(
                            children: <Widget>[
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isIn
                                    ? tokens.successSoft
                                    : tokens.surfaceMuted,
                                child: Text(
                                  initials(guardName, fallback: 'G'),
                                  style: TextStyle(
                                    color: isIn
                                        ? tokens.success
                                        : tokens.inkMuted,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                        overflow: TextOverflow.ellipsis,
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
                              const SizedBox(width: 8),
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
              ),
            );
          },
        ),
      ),
    );
  }
}
