import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminPayrollCycleDetailScreen extends ConsumerStatefulWidget {
  const AdminPayrollCycleDetailScreen({
    super.key,
    required this.cycle,
  });

  final PayrollCycleModel cycle;

  @override
  ConsumerState<AdminPayrollCycleDetailScreen> createState() =>
      _AdminPayrollCycleDetailScreenState();
}

class _AdminPayrollCycleDetailScreenState
    extends ConsumerState<AdminPayrollCycleDetailScreen> {
  List<PayrollEntryModel> _entries = const [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  bool get _isFinalized => widget.cycle.status.toLowerCase() == 'finalized';

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchPayrollCycleDetail(widget.cycle.id);
      if (!mounted) return;
      final raw = data['entries'] as List<dynamic>? ?? const <dynamic>[];
      final entries = raw
          .whereType<Map<String, dynamic>>()
          .map(PayrollEntryModel.fromJson)
          .toList();
      setState(() {
        _entries = entries;
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

  Future<void> _finalizeCycle() async {
    Haptics.heavy();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize Cycle?'),
        content: const Text(
          'This will lock the payroll cycle. No further changes can be made.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref
            .read(mobileRepositoryProvider)
            .finalizePayrollCycle(widget.cycle.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payroll cycle finalized')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<PayrollEntryModel> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries.where((e) {
      return e.employeeName.toLowerCase().contains(q) ||
          e.employeeId.toLowerCase().contains(q);
    }).toList();
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
                      title: 'Could not load cycle details',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _fetchDetail,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: <Widget>[
                      ModernHero(
                        eyebrow: 'Payroll',
                        title: widget.cycle.period,
                        subtitle:
                            '${_entries.length} employees · ${widget.cycle.statusLabel}',
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _SummaryCard(
                          cycle: widget.cycle,
                          tokens: tokens,
                          entryCount: _entries.length,
                        ),
                      ),
                      if (!_isFinalized) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _finalizeCycle,
                              icon: const Icon(Icons.lock_rounded, size: 18),
                              label: const Text('FINALIZE CYCLE'),
                              style: FilledButton.styleFrom(
                                backgroundColor: tokens.success,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search employees...',
                            prefixIcon: Icon(Icons.search_rounded,
                                color: tokens.inkMuted, size: 20),
                            filled: true,
                            fillColor: tokens.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: tokens.border),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_filteredEntries.isEmpty)
                        StateBlock(
                          icon: Icons.payments_outlined,
                          title: 'No entries',
                          message: 'No payroll entries match your search.',
                        )
                      else
                        ..._filteredEntries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ModernCard(
                              padding: const EdgeInsets.all(14),
                              child: InkWell(
                                onTap: () {
                                  Haptics.light();
                                  _showEntryDetail(entry);
                                },
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            entry.employeeName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: tokens.ink,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₹${entry.netPay.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: tokens.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          entry.employeeId,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${entry.daysWorked}d · ${entry.overtimeHours}h OT',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }

  void _showEntryDetail(PayrollEntryModel entry) {
    final tokens = CissThemeTokens.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              entry.employeeName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.employeeId} · ${widget.cycle.period}',
              style: TextStyle(fontSize: 13, color: tokens.inkMuted),
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: tokens.border),
            const SizedBox(height: 16),
            _entryRow(tokens, 'Gross Pay', '₹${entry.grossPay.toStringAsFixed(2)}',
                color: tokens.ink),
            const SizedBox(height: 8),
            _entryRow(tokens, 'EPF', '- ₹${entry.epf.toStringAsFixed(2)}',
                color: tokens.danger),
            const SizedBox(height: 8),
            _entryRow(tokens, 'ESIC', '- ₹${entry.esic.toStringAsFixed(2)}',
                color: tokens.danger),
            const SizedBox(height: 8),
            Divider(height: 1, color: tokens.border),
            const SizedBox(height: 8),
            _entryRow(tokens, 'Net Pay', '₹${entry.netPay.toStringAsFixed(2)}',
                color: tokens.success, bold: true, large: true),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                _pill(tokens, '${entry.daysWorked} days worked',
                    tokens.primarySoft, tokens.primary),
                const SizedBox(width: 8),
                _pill(tokens, '${entry.overtimeHours}h overtime',
                    tokens.warningSoft, tokens.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryRow(CissThemeTokens tokens, String label, String value,
      {Color? color, bool bold = false, bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label,
            style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
        Text(value,
            style: TextStyle(
              fontSize: large ? 18 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? tokens.ink,
            )),
      ],
    );
  }

  Widget _pill(
      CissThemeTokens tokens, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.cycle,
    required this.tokens,
    required this.entryCount,
  });

  final PayrollCycleModel cycle;
  final CissThemeTokens tokens;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.payments_rounded, color: tokens.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Cycle Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sumRow('Employees', '$entryCount'),
          const SizedBox(height: 8),
          _sumRow('Gross Total', '₹${cycle.totalGross.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _sumRow('Net Total', '₹${cycle.totalNetPay.toStringAsFixed(0)}',
              color: tokens.success),
          const SizedBox(height: 8),
          _sumRow('EPF/ESIC Total',
              '₹${cycle.totalEpfEsic.toStringAsFixed(0)}',
              color: tokens.danger),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              StatusChip(
                label: cycle.statusLabel.toUpperCase(),
                tone: cycle.status == 'finalized'
                    ? StatusChipTone.success
                    : cycle.status == 'processing'
                        ? StatusChipTone.warning
                        : StatusChipTone.neutral,
              ),
              const Spacer(),
              if (cycle.createdAt != null && cycle.createdAt!.isNotEmpty)
                Text(
                  cycle.createdAt!.split('T').first,
                  style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 13, color: tokens.inkMuted)),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color ?? tokens.ink,
            )),
      ],
    );
  }
}
