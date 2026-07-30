import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';

class AdminAssignedGuardsExportScreen extends ConsumerStatefulWidget {
  const AdminAssignedGuardsExportScreen({super.key});

  @override
  ConsumerState<AdminAssignedGuardsExportScreen> createState() =>
      _AdminAssignedGuardsExportScreenState();
}

class _AdminAssignedGuardsExportScreenState
    extends ConsumerState<AdminAssignedGuardsExportScreen> {
  List<Map<String, dynamic>> _assignments = const [];
  bool _loading = true;
  String? _error;
  String? _selectedSiteId;

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
      final repo = ref.read(mobileRepositoryProvider);
      final workOrders = await repo.fetchAdminWorkOrders();
      final assignments = <Map<String, dynamic>>[];
      for (final wo in workOrders) {
        final assigned = wo['assignedGuards'] as List<dynamic>? ?? const <dynamic>[];
        for (final g in assigned) {
          if (g is Map<String, dynamic>) {
            assignments.add({
              'siteName': wo['siteName'] as String? ?? '',
              'district': wo['district'] as String? ?? '',
              'siteId': wo['siteId'] as String? ?? '',
              'employeeId': g['employeeId'] as String? ?? g['id'] as String? ?? '',
              'employeeName': g['employeeName'] as String? ?? g['name'] as String? ?? '',
              'shiftLabel': wo['shiftLabel'] as String? ?? wo['examName'] as String? ?? '',
              'dutyPointName': g['dutyPointName'] as String? ?? '',
            });
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
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

  Future<void> _exportCsv() async {
    Haptics.light();
    try {
      final buffer = StringBuffer();
      buffer.writeln('Site Name,District,Employee ID,Employee Name,Shift,Duty Point');

      final filtered = _selectedSiteId == null
          ? _assignments
          : _assignments
              .where((a) => (a['siteName'] as String? ?? '') == _selectedSiteId)
              .toList();

      for (final a in filtered) {
        final siteName = a['siteName'] as String? ?? '';
        final district = a['district'] as String? ?? '';
        final employeeId = a['employeeId'] as String? ?? a['id'] as String? ?? '';
        final employeeName = a['employeeName'] as String? ?? a['name'] as String? ?? '';
        final shift = a['shiftLabel'] as String? ?? '';
        final dutyPoint = a['dutyPointName'] as String? ?? '';
        buffer.writeln('"$siteName","$district","$employeeId","$employeeName","$shift","$dutyPoint"');
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV copied to clipboard'),
            backgroundColor: Color(0xFF17805D),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Set<String> get _distinctSites =>
      _assignments
          .map((a) => a['siteName'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final sites = _distinctSites.toList()..sort();

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: StateBlock(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load assignments',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _fetch,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: <Widget>[
                      ModernHero(
                        eyebrow: 'Export',
                        title: 'Assigned Guards',
                        subtitle: '${_assignments.length} assignments',
                      ),
                      const SizedBox(height: 16),
                      if (sites.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ModernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('FILTER BY SITE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.inkMuted,
                                      letterSpacing: 2,
                                    )),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: <Widget>[
                                    FilterChip(
                                      label: const Text('All'),
                                      selected: _selectedSiteId == null,
                                      onSelected: (_) =>
                                          setState(() => _selectedSiteId = null),
                                      selectedColor: tokens.primarySoft,
                                      checkmarkColor: tokens.primary,
                                    ),
                                    ...sites.map((site) => FilterChip(
                                          label: Text(site, maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          selected: site == _selectedSiteId,
                                          onSelected: (_) => setState(
                                              () => _selectedSiteId = site),
                                          selectedColor: tokens.primarySoft,
                                          checkmarkColor: tokens.primary,
                                        )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _exportCsv,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('EXPORT AS CSV'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_assignments.isEmpty)
                        StateBlock(
                          icon: Icons.assignment_outlined,
                          title: 'No assignments',
                          message:
                              'No guard assignments available for export.',
                        )
                      else
                        ..._assignments
                            .where((a) => _selectedSiteId == null ||
                                (a['siteName'] as String? ?? '') == _selectedSiteId)
                            .map((a) {
                          final siteName = a['siteName'] as String? ?? '';
                          final employeeName = a['employeeName'] as String? ?? a['name'] as String? ?? '';
                          final employeeId = a['employeeId'] as String? ?? a['id'] as String? ?? '';
                          final shift = a['shiftLabel'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                            child: ModernCard(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(employeeName,
                                            style: TextStyle(fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.ink)),
                                        Text(employeeId,
                                            style: TextStyle(fontSize: 11,
                                                color: tokens.inkMuted)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Text(siteName,
                                          style: TextStyle(fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.primary)),
                                      if (shift.isNotEmpty)
                                        Text(shift,
                                            style: TextStyle(fontSize: 11,
                                                color: tokens.inkMuted)),
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
}
