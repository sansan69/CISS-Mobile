import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/location/live_location_service.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/modern_card.dart';
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
  String _selectedDate = '';

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
      _sortRecords(records);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _sortRecords(List<Map<String, dynamic>> records) {
    records.sort((a, b) {
      final aDate = _text(a['checkIn']).isNotEmpty
          ? _text(a['checkIn'])
          : _text(a['reportedAt']);
      final bDate = _text(b['checkIn']).isNotEmpty
          ? _text(b['checkIn'])
          : _text(b['reportedAt']);
      return bDate.compareTo(aDate);
    });

    setState(() {
      _records = records;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_selectedDate.isEmpty) return _records;
    return _records.where((r) {
      final dateStr = _text(r['checkIn']).isNotEmpty
          ? _text(r['checkIn'])
          : _text(r['reportedAt']);
      return dateStr.startsWith(_selectedDate);
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Attendance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recent check-ins and live duty status',
                    style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<GuardLocationData>>(
                    stream: _liveLocationService.streamActiveLocations(),
                    builder: (context, snapshot) {
                      final locations =
                          snapshot.data ?? const <GuardLocationData>[];
                      final checkedIn = _records
                          .where((r) =>
                              _text(r['status']).toLowerCase() == 'in')
                          .length;

                      return Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: MetricCard(
                                  label: 'Live now',
                                  value: '${locations.length}',
                                  color: tokens.success,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: MetricCard(
                                  label: 'Checked in',
                                  value: '$checkedIn',
                                  color: tokens.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: MetricCard(
                                  label: 'Total',
                                  value: '${_records.length}',
                                  color: tokens.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: ActionChip(
                                  onPressed: _pickDate,
                                  avatar: Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: _selectedDate.isNotEmpty
                                        ? tokens.primary
                                        : tokens.inkMuted,
                                  ),
                                  label: Text(
                                    _selectedDate.isEmpty
                                        ? 'Filter by date'
                                        : _formatDisplayDate(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedDate.isNotEmpty
                                          ? tokens.primary
                                          : tokens.inkMuted,
                                    ),
                                  ),
                                  backgroundColor: tokens.surface,
                                  side: BorderSide(
                                    color: _selectedDate.isNotEmpty
                                        ? tokens.primary
                                        : tokens.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.pill),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                ),
                              ),
                              if (_selectedDate.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ActionChip(
                                    onPressed: () =>
                                        setState(() => _selectedDate = ''),
                                    avatar: Icon(Icons.close_rounded,
                                        size: 14, color: tokens.danger),
                                    label: Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.danger,
                                      ),
                                    ),
                                    backgroundColor: tokens.surface,
                                    side: BorderSide(color: tokens.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.pill),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchAttendance,
                child: StreamBuilder<List<GuardLocationData>>(
                  stream: _liveLocationService.streamActiveLocations(),
                  builder: (context, snapshot) {
                    final locations =
                        snapshot.data ?? const <GuardLocationData>[];
                    final liveEmployeeIds = locations
                        .map((loc) => loc.employeeId)
                        .toSet();
                    final filtered = _filteredRecords;

                    if (filtered.isEmpty) {
                      return ListView(
                        children: <Widget>[
                          const SizedBox(height: 60),
                          StateBlock(
                            icon: Icons.fact_check_rounded,
                            title: 'No attendance records',
                            message: _selectedDate.isNotEmpty
                                ? 'No records for this date.'
                                : 'Guard check-ins and check-outs will appear here.',
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final record = filtered[index];
                        final employeeId = _text(record['employeeId']);
                        final guardName =
                            _text(record['guardName']).isNotEmpty
                                ? _text(record['guardName'])
                                : _text(record['fullName']).isNotEmpty
                                    ? _text(record['fullName'])
                                    : 'Guard';
                        final siteName = _text(record['siteName']);
                        final clientName = _text(record['clientName']);
                        final district = _text(record['district']);
                        final reportedAt = _formatDateTime(
                            _text(record['checkIn']).isNotEmpty
                                ? _text(record['checkIn'])
                                : _text(record['reportedAt']));
                        final status = _text(record['status']).isNotEmpty
                            ? _text(record['status'])
                            : 'In';
                        final isIn = status.toLowerCase() == 'in';
                        final isLive = employeeId.isNotEmpty &&
                            liveEmployeeIds.contains(employeeId);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ModernCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: tokens.ink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (siteName.isNotEmpty)
                                        _metaLine(tokens,
                                            Icons.location_on_rounded, siteName),
                                      if (clientName.isNotEmpty)
                                        _metaLine(tokens,
                                            Icons.business_rounded, clientName),
                                      if (district.isNotEmpty)
                                        _metaLine(tokens, Icons.map_rounded,
                                            district),
                                      if (reportedAt.isNotEmpty)
                                        _metaLine(tokens, Icons.schedule_rounded,
                                            reportedAt),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    StatusChip(
                                      label: isIn ? 'In' : 'Out',
                                      tone: isIn
                                          ? StatusChipTone.success
                                          : StatusChipTone.neutral,
                                    ),
                                    if (isLive) ...[
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
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaLine(CissThemeTokens tokens, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: tokens.inkMuted),
          const SizedBox(width: 4),
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

  String _text(Object? value) => (value as String?)?.trim() ?? '';

  String _formatDateTime(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} $hour:$minute';
  }

  String _formatDisplayDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}
