import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminBulkImportScreen extends ConsumerStatefulWidget {
  const AdminBulkImportScreen({super.key});

  @override
  ConsumerState<AdminBulkImportScreen> createState() =>
      _AdminBulkImportScreenState();
}

class _AdminBulkImportScreenState extends ConsumerState<AdminBulkImportScreen> {
  String? _fileName;
  List<Map<String, dynamic>> _previewRows = const [];
  int _validCount = 0;
  int _warnCount = 0;
  bool _uploading = false;
  bool _importing = false;
  String? _error;

  Future<void> _uploadFile() async {
    setState(() {
      _uploading = true;
      _error = null;
    });

    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Import Employees'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'File Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. guards_import.xlsx',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Paste Excel/CSV content',
                  border: OutlineInputBorder(),
                  hintText:
                      'name, phone, client, district, site\nJohn Doe, 9876543210, Client A, District X, Site 1',
                ),
                maxLines: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Preview'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final repo = ref.read(mobileRepositoryProvider);
        final response = await repo.bulkImportEmployees({
          'fileName': nameCtrl.text.trim(),
          'content': contentCtrl.text,
        });
        if (!mounted) return;
        final rows = (response['rows'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        final valid = rows.where((r) => r['status'] == 'valid').length;
        final warn = rows.length - valid;
        setState(() {
          _fileName = nameCtrl.text.trim();
          _previewRows = rows;
          _validCount = valid;
          _warnCount = warn;
          _uploading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _uploading = false;
        });
      }
    } else {
      setState(() => _uploading = false);
    }
    nameCtrl.dispose();
    contentCtrl.dispose();
  }

  Future<void> _commitImport() async {
    setState(() => _importing = true);
    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.bulkImportEmployees({
        'fileName': _fileName,
        'rows': _previewRows,
        'mode': 'commit',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employees imported successfully')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: CissThemeTokens.of(context).danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Bulk Import'),
        backgroundColor: tokens.canvas,
      ),
      body: _uploading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _previewRows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: StateBlock(
                      icon: Icons.cloud_off_rounded,
                      title: 'Import failed',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _uploadFile,
                        child: const Text('Try again'),
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionHeader('UPLOAD', tokens),
                    const SizedBox(height: 12),
                    ModernCard(
                      onTap: _uploadFile,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: tokens.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.upload_file_rounded,
                                color: tokens.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fileName ?? 'Tap to upload employee file',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _fileName != null
                                        ? tokens.ink
                                        : tokens.inkMuted,
                                  ),
                                ),
                                Text(
                                  'Bulk employee import (.xlsx, .csv)',
                                  style: TextStyle(
                                      fontSize: 12, color: tokens.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: tokens.inkMuted),
                        ],
                      ),
                    ),
                    if (_previewRows.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionHeader('PREVIEW', tokens),
                      const SizedBox(height: 12),
                      ModernCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _summaryChip('$_validCount Valid',
                                    tokens.success, tokens),
                                const SizedBox(width: 8),
                                _summaryChip('$_warnCount Warnings',
                                    tokens.warning, tokens),
                                const SizedBox(width: 8),
                                _summaryChip(
                                    '${_previewRows.length} Total',
                                    tokens.inkMuted,
                                    tokens),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            ..._previewRows.take(20).map((row) {
                              final name = row['name']?.toString() ??
                                  row['fullName']?.toString() ??
                                  '';
                              final phone =
                                  row['phone']?.toString() ?? '';
                              final status =
                                  row['status']?.toString() ?? '';
                              final isWarn = status != 'valid';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.ink,
                                            ),
                                          ),
                                          if (phone.isNotEmpty)
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: tokens.inkMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isWarn
                                            ? tokens.warningSoft
                                            : tokens.successSoft,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isWarn ? 'Warn' : 'Valid',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isWarn
                                              ? tokens.warning
                                              : tokens.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (_previewRows.length > 20)
                              Text(
                                '+ ${_previewRows.length - 20} more rows',
                                style: TextStyle(
                                    fontSize: 12, color: tokens.inkMuted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _previewRows = const [];
                                  _fileName = null;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _importing ? null : _commitImport,
                              child: _importing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Import'),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Widget _summaryChip(String label, Color color, CissThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
