import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';

class AdminDataExportScreen extends ConsumerStatefulWidget {
  const AdminDataExportScreen({super.key});

  @override
  ConsumerState<AdminDataExportScreen> createState() =>
      _AdminDataExportScreenState();
}

class _AdminDataExportScreenState extends ConsumerState<AdminDataExportScreen> {
  String _exportType = 'attendance';
  String _format = 'xlsx';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedClientId;
  List<ClientModel> _clients = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final clients = await repo.fetchAdminClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _doExport() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.exportData(
        type: _exportType,
        format: _format,
        startDate: _startDate?.toIso8601String().substring(0, 10),
        endDate: _endDate?.toIso8601String().substring(0, 10),
        clientId: _selectedClientId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export started. Check downloads.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: CissThemeTokens.of(context).danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now.subtract(const Duration(days: 30)))
          : (_endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Data Export'),
        backgroundColor: tokens.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('EXPORT TYPE', tokens),
          const SizedBox(height: 12),
          ModernCard(
            child: Column(
              children: [
                _radioTile(
                  'Attendance',
                  'attendance',
                  Icons.fact_check_rounded,
                  tokens,
                ),
                _divider(tokens),
                _radioTile(
                  'Guards',
                  'guards',
                  Icons.groups_rounded,
                  tokens,
                ),
                _divider(tokens),
                _radioTile(
                  'Payroll',
                  'payroll',
                  Icons.payments_rounded,
                  tokens,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('DATE RANGE', tokens),
          const SizedBox(height: 12),
          ModernCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today_rounded,
                      color: tokens.primary),
                  title: Text(
                    _startDate != null
                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                        : 'Start Date',
                    style: TextStyle(
                      color: _startDate != null ? tokens.ink : tokens.inkMuted,
                    ),
                  ),
                  trailing: Icon(Icons.edit_rounded, color: tokens.inkMuted),
                  onTap: () => _pickDate(true),
                ),
                _divider(tokens),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today_rounded,
                      color: tokens.primary),
                  title: Text(
                    _endDate != null
                        ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                        : 'End Date',
                    style: TextStyle(
                      color: _endDate != null ? tokens.ink : tokens.inkMuted,
                    ),
                  ),
                  trailing: Icon(Icons.edit_rounded, color: tokens.inkMuted),
                  onTap: () => _pickDate(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('FORMAT', tokens),
          const SizedBox(height: 12),
          ModernCard(
            child: Column(
              children: [
                _radioTile('Excel (XLSX)', 'xlsx',
                    Icons.table_chart_rounded, tokens),
                _divider(tokens),
                _radioTile('PDF', 'pdf', Icons.picture_as_pdf_rounded, tokens),
              ],
            ),
          ),
          if (_exportType == 'attendance' || _exportType == 'guards') ...[
            const SizedBox(height: 24),
            _sectionHeader('CLIENT (optional)', tokens),
            const SizedBox(height: 12),
            ModernCard(
              child: DropdownButtonFormField<String>(
                value: _selectedClientId,
                decoration: const InputDecoration(
                  labelText: 'Filter by Client',
                  border: InputBorder.none,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Clients'),
                  ),
                  ..._clients.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.name),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedClientId = v),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _doExport,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_loading ? 'Exporting...' : 'Export Data'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, CissThemeTokens tokens) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: tokens.inkMuted,
        letterSpacing: 2,
      ),
    );
  }

  Widget _radioTile(
      String label, String value, IconData icon, CissThemeTokens tokens) {
    final isSelected = (_exportType == value) || (_format == value);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: isSelected ? tokens.primary : tokens.inkMuted, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Radio<String>(
        value: value,
        groupValue: _exportType == value ? _exportType : _format,
        onChanged: (v) {
          if (v == 'attendance' || v == 'guards' || v == 'payroll') {
            setState(() => _exportType = v!);
          } else {
            setState(() => _format = v!);
          }
        },
      ),
      onTap: () {
        if (value == 'attendance' || value == 'guards' || value == 'payroll') {
          setState(() => _exportType = value);
        } else {
          setState(() => _format = value);
        }
      },
    );
  }

  Widget _divider(CissThemeTokens tokens) {
    return Divider(height: 1, color: tokens.border.withValues(alpha: 0.3));
  }
}
