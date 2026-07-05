import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminPayrollScreen extends ConsumerStatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  ConsumerState<AdminPayrollScreen> createState() =>
      _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends ConsumerState<AdminPayrollScreen> {
  List<PayrollCycleModel> _cycles = const [];
  Map<String, List<PayrollEntryModel>> _entryCache =
      const <String, List<PayrollEntryModel>>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCycles();
  }

  Future<void> _fetchCycles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cycles =
          await ref.read(mobileRepositoryProvider).fetchPayrollCycles();
      if (!mounted) return;
      setState(() {
        _cycles = cycles;
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

  Future<void> _fetchCycleDetail(String cycleId) async {
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchPayrollCycleDetail(cycleId);
      final entries = data['entries'] as List<dynamic>? ?? const <dynamic>[];
      final list = entries
          .whereType<Map<String, dynamic>>()
          .map(PayrollEntryModel.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _entryCache = {..._entryCache, cycleId: list};
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load details: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
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
        title: const Text('Payroll'),
        backgroundColor: tokens.canvas,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Error',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetchCycles,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : _cycles.isEmpty
                  ? const Center(
                      child: StateBlock(
                        icon: Icons.payments_rounded,
                        title: 'No payroll cycles',
                        message: 'Payroll cycles will appear here.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchCycles,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cycles.length,
                        itemBuilder: (context, index) {
                          final cycle = _cycles[index];
                          final entries = _entryCache[cycle.id];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cycle.period,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${cycle.employeeCount} employees',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: tokens.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusChip(
                                        label: cycle.statusLabel,
                                        tone: cycle.status == 'finalized' ||
                                                cycle.status == 'paid'
                                            ? StatusChipTone.success
                                            : cycle.status == 'processing'
                                                ? StatusChipTone.warning
                                                : StatusChipTone.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _AmountPill(
                                          label: 'Gross',
                                          value: cycle.totalGross,
                                          color: tokens.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _AmountPill(
                                          label: 'Net Pay',
                                          value: cycle.totalNetPay,
                                          color: tokens.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (entries != null) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    ...entries.take(5).map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                entry.employeeName,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: tokens.ink,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '\u20B9${entry.netPay.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: tokens.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (entries.length > 5)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '+${entries.length - 5} more',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                      ),
                                  ] else ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 32,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _fetchCycleDetail(cycle.id),
                                        icon: const Icon(Icons.expand_more,
                                            size: 18),
                                        label: const Text('View entries'),
                                      ),
                                    ),
                                  ],
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

class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '\u20B9${value.toStringAsFixed(0)}',
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
