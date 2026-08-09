import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/status_chip.dart';

/// Attendance history for one guard — the mobile counterpart of the web
/// attendance-logs surface. Fetches the field-officer attendance feed over a
/// date range and filters it to this guard.
class GuardAttendanceLogsScreen extends ConsumerStatefulWidget {
  const GuardAttendanceLogsScreen({
    super.key,
    required this.employeeId,
    required this.guardName,
    this.guardId,
  });

  final String employeeId;
  final String guardName;
  final String? guardId;

  @override
  ConsumerState<GuardAttendanceLogsScreen> createState() =>
      _GuardAttendanceLogsScreenState();
}

class _GuardAttendanceLogsScreenState
    extends ConsumerState<GuardAttendanceLogsScreen> {
  static const List<int> _rangeDays = <int>[7, 30];
  int _selectedRangeDays = 30;
  List<FieldOfficerAttendanceEntry>? _entries;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isForGuard(FieldOfficerAttendanceEntry entry) {
    return entry.employeeId == widget.employeeId ||
        entry.guardId == widget.guardId ||
        entry.guardId == widget.employeeId;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: _selectedRangeDays - 1));
      final entries = await ref
          .read(mobileRepositoryProvider)
          .fetchFieldOfficerGuardAttendanceRange(
            start: start,
            end: now,
          );
      if (!mounted) return;
      setState(() {
        _entries = entries.where(_isForGuard).toList()
          ..sort((a, b) => b.dateLabel.compareTo(a.dateLabel));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load attendance. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final entries = _entries ?? const <FieldOfficerAttendanceEntry>[];

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: Text(
          widget.guardName,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: tokens.ink,
          ),
        ),
        backgroundColor: tokens.canvas,
      ),
      body: Column(
        children: [
          // Range selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: _rangeDays
                        .map(
                          (days) => ButtonSegment<int>(
                            value: days,
                            label: Text('$days days'),
                          ),
                        )
                        .toList(),
                    selected: <int>{_selectedRangeDays},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedRangeDays = selection.first);
                      _load();
                    },
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _load,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: tokens.inkMuted,
                  ),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: StateBlock(
                icon: Icons.error_outline_rounded,
                title: 'Could not load attendance',
                message: _error!,
                action: FilledButton.tonal(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ),
            )
          else if (entries.isEmpty)
            Expanded(
              child: StateBlock(
                icon: Icons.event_busy_rounded,
                title: 'No attendance records',
                message:
                    'No check-in or check-out records for ${widget.guardName} '
                    'in the selected period.',
              ),
            )
          else
            Expanded(
              child: _AttendanceList(entries: entries),
            ),
        ],
      ),
    );
  }
}

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.entries});

  final List<FieldOfficerAttendanceEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final presentCount =
        entries.where((e) => e.checkIn != null).length;
    final flaggedCount =
        entries
            .where(
              (e) => e.isMockLocationSuspected || e.requiresAdminReview,
            )
            .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Summary strip
        ModernCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _SummaryStat(
                label: 'SHIFTS',
                value: '${entries.length}',
                color: tokens.ink,
              ),
              _SummaryStat(
                label: 'PRESENT',
                value: '$presentCount',
                color: tokens.success,
              ),
              _SummaryStat(
                label: 'FLAGGED',
                value: '$flaggedCount',
                color: flaggedCount > 0 ? tokens.danger : tokens.inkMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...entries.map((entry) => _EntryCard(entry: entry)),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final FieldOfficerAttendanceEntry entry;

  String _time(String? value) {
    if (value == null || value.isEmpty) return '—';
    // API returns HH:MM (24h) or an ISO string; keep it short either way.
    if (value.length <= 5 && value.contains(':')) return value;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final h = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final am = parsed.hour < 12 ? 'AM' : 'PM';
    return '$h:${parsed.minute.toString().padLeft(2, '0')} $am';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final flagged =
        entry.isMockLocationSuspected || entry.requiresAdminReview;

    final statusTone = switch (entry.status.toLowerCase()) {
      'in' || 'present' || 'complete' => StatusChipTone.success,
      'out' || 'absent' => StatusChipTone.danger,
      _ => StatusChipTone.neutral,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModernCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.dateLabel.isEmpty
                            ? 'Unknown date'
                            : entry.dateLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                        ),
                      ),
                      if (entry.siteName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          entry.siteName,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tokens.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (flagged)
                  StatusChip(
                    label: 'FLAGGED',
                    tone: StatusChipTone.danger,
                  )
                else
                  StatusChip(
                    label: entry.status.toUpperCase(),
                    tone: statusTone,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _TimeCell(
                  tokens: tokens,
                  icon: Icons.login_rounded,
                  label: 'IN',
                  value: _time(entry.checkIn),
                ),
                Container(
                  width: 1,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: tokens.border,
                ),
                _TimeCell(
                  tokens: tokens,
                  icon: Icons.logout_rounded,
                  label: 'OUT',
                  value: _time(entry.checkOut),
                ),
                const Spacer(),
                if (entry.distanceMeters != null)
                  Text(
                    entry.distanceMeters! >= 1000
                        ? '${(entry.distanceMeters! / 1000).toStringAsFixed(1)} km'
                        : '${entry.distanceMeters!.round()} m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.inkMuted,
                    ),
                  ),
              ],
            ),
            if (entry.shiftLabel.isNotEmpty ||
                entry.dutyPointName.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (entry.shiftLabel.isNotEmpty)
                    StatusChip(
                      label: entry.shiftLabel,
                      tone: StatusChipTone.info,
                    ),
                  if (entry.dutyPointName.isNotEmpty)
                    StatusChip(
                      label: entry.dutyPointName,
                      icon: Icons.flag_rounded,
                    ),
                ],
              ),
            ],
            if (entry.mockLocationReason != null &&
                entry.mockLocationReason!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: tokens.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.mockLocationReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.value,
  });

  final CissThemeTokens tokens;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: tokens.inkMuted),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: tokens.inkMuted,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: value == '—' ? tokens.inkMuted : tokens.ink,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
