import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/modern_input.dart';

class AdminPayrollRunScreen extends ConsumerStatefulWidget {
  const AdminPayrollRunScreen({super.key});

  @override
  ConsumerState<AdminPayrollRunScreen> createState() =>
      _AdminPayrollRunScreenState();
}

class _AdminPayrollRunScreenState
    extends ConsumerState<AdminPayrollRunScreen> {
  final _periodCtrl = TextEditingController();
  bool _running = false;
  bool _done = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current month
    final now = DateTime.now();
    _periodCtrl.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _periodCtrl.dispose();
    super.dispose();
  }

  Future<void> _runPayroll() async {
    final period = _periodCtrl.text.trim();
    if (period.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a period')),
      );
      return;
    }

    Haptics.heavy();
    setState(() {
      _running = true;
      _done = false;
      _resultMessage = null;
    });

    try {
      final result = await ref
          .read(mobileRepositoryProvider)
          .createPayrollCycle(<String, dynamic>{'period': period});
      if (!mounted) return;
      setState(() {
        _running = false;
        _done = true;
        _resultMessage =
            'Payroll cycle for $period created successfully!\n'
            '${result['employeeCount'] ?? 0} employees included.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _done = true;
        _resultMessage =
            'Error: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            ModernHero(
              eyebrow: 'Payroll',
              title: 'Run Payroll',
              subtitle: 'Create a new payroll cycle',
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PERIOD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tokens.inkMuted,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ModernInput(
                      controller: _periodCtrl,
                      labelText: 'Period (YYYY-MM)',
                      hintText: 'e.g. 2026-07',
                      prefixIcon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The payroll system will calculate wages, deductions, '
                      'EPF, ESIC, and generate payslips for all Active guards.',
                      style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (_done && _resultMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ModernCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            _resultMessage!.startsWith('Error')
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_rounded,
                            color: _resultMessage!.startsWith('Error')
                                ? tokens.danger
                                : tokens.success,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _resultMessage!.startsWith('Error')
                                  ? 'Failed'
                                  : 'Success',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _resultMessage!.startsWith('Error')
                                    ? tokens.danger
                                    : tokens.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _resultMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.ink,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _running ? null : _runPayroll,
                  icon: _running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_running ? 'Running...' : 'RUN PAYROLL'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.success,
                  ),
                ),
              ),
            ),
            if (_done && !_resultMessage!.startsWith('Error')) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Payroll'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
