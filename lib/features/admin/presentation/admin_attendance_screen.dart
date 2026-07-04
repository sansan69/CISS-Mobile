import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/location/live_location_service.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  late final LiveLocationService _liveLocationService;
  List<Map<String, dynamic>> _records = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

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
      final records =
          await ref.read(mobileRepositoryProvider).fetchAdminAttendance();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StateBlock(
              icon: Icons.cloud_off_rounded,
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

    return ScreenScaffold(
      title: 'Attendance',
      subtitle: 'Recent check-ins and live duty status',
      onRefresh: _fetchAttendance,
      children: <Widget>[
        StreamBuilder<List<GuardLocationData>>(
          stream: _liveLocationService.streamActiveLocations(),
          builder: (context, snapshot) {
            final locations = snapshot.data ?? const <GuardLocationData>[];
            final liveEmployeeIds = locations.map((location) => location.employeeId).toSet();
            final checkedIn = _records
                .where((record) => _text(record['status']).toLowerCase() == 'in')
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                GlassCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _Metric(
                          value: '${locations.length}',
                          label: 'Live now',
                          color: tokens.success,
                        ),
                      ),
                      Container(width: 1, height: 38, color: tokens.border),
                      Expanded(
                        child: _Metric(
                          value: '$checkedIn',
                          label: 'Recent in',
                          color: tokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_records.isEmpty)
                  const StateBlock(
                    icon: Icons.fact_check_rounded,
                    title: 'No attendance records',
                    message: 'Guard check-ins and check-outs will appear here.',
                  )
                else
                  ..._records.map((record) {
                    final employeeId = _text(record['employeeId']);
                    final guardName = _text(record['guardName']).isNotEmpty
                        ? _text(record['guardName'])
                        : _text(record['fullName']).isNotEmpty
                            ? _text(record['fullName'])
                            : 'Guard';
                    final siteName = _text(record['siteName']);
                    final clientName = _text(record['clientName']);
                    final district = _text(record['district']);
                    final reportedAt = _formatDateTime(_text(record['checkIn']).isNotEmpty
                        ? _text(record['checkIn'])
                        : _text(record['reportedAt']));
                    final status = _text(record['status']).isNotEmpty ? _text(record['status']) : 'In';
                    final isIn = status.toLowerCase() == 'in';
                    final isLive = employeeId.isNotEmpty && liveEmployeeIds.contains(employeeId);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isIn ? tokens.successSoft : tokens.surfaceMuted,
                              child: Text(
                                _initials(guardName),
                                style: TextStyle(
                                  color: isIn ? tokens.success : tokens.inkMuted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    guardName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (siteName.isNotEmpty) _MetaLine(Icons.location_on_rounded, siteName),
                                  if (clientName.isNotEmpty) _MetaLine(Icons.business_rounded, clientName),
                                  if (district.isNotEmpty) _MetaLine(Icons.map_rounded, district),
                                  if (reportedAt.isNotEmpty) _MetaLine(Icons.schedule_rounded, reportedAt),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                StatusChip(
                                  label: isIn ? 'In' : 'Out',
                                  tone: isIn ? StatusChipTone.success : StatusChipTone.neutral,
                                ),
                                if (isLive) ...<Widget>[
                                  const SizedBox(height: 6),
                                  StatusChip(
                                    label: 'Live',
                                    icon: Icons.near_me_rounded,
                                    tone: StatusChipTone.info,
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

  String _text(Object? value) => (value as String?)?.trim() ?? '';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts.map((part) => part[0]).take(2).join().toUpperCase();
    return initials.isEmpty ? 'G' : initials;
  }

  String _formatDateTime(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} $hour:$minute';
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
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.inkMuted)),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 13, color: tokens.inkMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
