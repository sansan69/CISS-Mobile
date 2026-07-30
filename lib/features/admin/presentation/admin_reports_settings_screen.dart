import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/data_table_card.dart';

class AdminReportsSettingsScreen extends ConsumerStatefulWidget {
  const AdminReportsSettingsScreen({super.key});

  @override
  ConsumerState<AdminReportsSettingsScreen> createState() =>
      _AdminReportsSettingsScreenState();
}

class _AdminReportsSettingsScreenState
    extends ConsumerState<AdminReportsSettingsScreen> {
  List<Map<String, dynamic>> _reportData = const [];
  bool _loading = true;
  String? _error;
  final String _reportType = 'attendance';
  String? _selectedDistrict;
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'type': _reportType,
      };
      if (_selectedDistrict != null) params['district'] = _selectedDistrict;
      if (_selectedClientId != null) params['clientId'] = _selectedClientId;

      final repo = ref.read(mobileRepositoryProvider);
      final data = await repo.getJson('/api/admin/reports/attendance',
              queryParameters: params);
      if (!mounted) return;
      final rows = (data['rows'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[];
      setState(() {
        _reportData = rows;
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: StateBlock(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load report',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _fetchReport,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: <Widget>[
                      ModernHero(
                        eyebrow: 'Reports',
                        title: 'Attendance Reports',
                        subtitle:
                            '${_reportData.length} records · $_reportType',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ModernCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'REPORT SUMMARY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.inkMuted,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_reportData.length} employee records',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _reportType == 'attendance'
                                    ? 'Present/Absent breakdown'
                                    : 'Monthly working days summary',
                                style: TextStyle(
                                    fontSize: 13, color: tokens.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_reportData.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DataTableCard(
                            columns: [
                              DataTableColumn(
                                  label: 'Employee', flex: 3),
                              DataTableColumn(
                                  label: 'Client', flex: 2),
                              DataTableColumn(
                                  label: 'Present', flex: 1),
                              DataTableColumn(
                                  label: 'Absent', flex: 1),
                            ],
                            rows: _reportData.map((r) {
                              return DataTableRow(cells: [
                                DataTableCell(
                                    text: r['employeeName'] as String? ??
                                        r['employeeId'] as String? ??
                                        '—',
                                    isBold: true),
                                DataTableCell(
                                    text: r['clientName'] as String? ?? '—'),
                                DataTableCell(
                                    text:
                                        '${r['presentDays'] ?? r['present'] ?? 0}',
                                    color: tokens.success),
                                DataTableCell(
                                    text:
                                        '${r['absentDays'] ?? r['absent'] ?? 0}',
                                    color: tokens.danger),
                              ]);
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
