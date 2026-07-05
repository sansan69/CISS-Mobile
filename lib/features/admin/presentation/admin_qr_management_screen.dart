import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminQRManagementScreen extends ConsumerStatefulWidget {
  const AdminQRManagementScreen({super.key});

  @override
  ConsumerState<AdminQRManagementScreen> createState() =>
      _AdminQRManagementScreenState();
}

class _AdminQRManagementScreenState
    extends ConsumerState<AdminQRManagementScreen> {
  List<EmployeeModel> _guards = const [];
  Set<String> _generatingIds = const {};
  bool _loading = true;
  bool _bulkGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGuards();
  }

  Future<void> _fetchGuards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      final guards = await repo.fetchAdminEmployees();
      if (!mounted) return;
      setState(() {
        _guards = guards;
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

  Future<void> _generateForGuard(String employeeId) async {
    setState(() {
      _generatingIds = {..._generatingIds, employeeId};
    });
    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.generateQR(employeeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code regenerated')),
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
      if (mounted) {
        setState(() {
          _generatingIds = _generatingIds.where((id) => id != employeeId).toSet();
        });
      }
    }
  }

  Future<void> _bulkGenerate() async {
    setState(() => _bulkGenerating = true);
    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.bulkGenerateQR();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulk QR generation completed')),
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
      if (mounted) setState(() => _bulkGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('QR Management'),
        backgroundColor: tokens.canvas,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _bulkGenerating ? null : _bulkGenerate,
              icon: _bulkGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner_rounded),
              label: Text(_bulkGenerating ? 'Generating...' : 'Regenerate All'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load guards',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetchGuards,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchGuards,
                  child: _guards.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            StateBlock(
                              icon: Icons.qr_code_rounded,
                              title: 'No guards found',
                              message: 'Guards will appear here.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _guards.length,
                          itemBuilder: (context, index) {
                            final guard = _guards[index];
                            final isGenerating =
                                _generatingIds.contains(guard.id) ||
                                    _generatingIds
                                        .contains(guard.employeeId);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ModernCard(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: tokens.primarySoft,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.qr_code_rounded,
                                        color: tokens.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            guard.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.ink,
                                            ),
                                          ),
                                          Text(
                                            guard.employeeId,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: tokens.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    isGenerating
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: tokens.primary,
                                            ),
                                          )
                                        : IconButton(
                                            icon: Icon(
                                              Icons.refresh_rounded,
                                              color: tokens.primary,
                                            ),
                                            tooltip: 'Regenerate QR',
                                            onPressed: () =>
                                                _generateForGuard(
                                                    guard.employeeId.isNotEmpty
                                                        ? guard.employeeId
                                                        : guard.id),
                                          ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
