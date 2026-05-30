import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/brand_banner.dart';

class GuardPinSetupScreen extends ConsumerStatefulWidget {
  const GuardPinSetupScreen({
    super.key,
    this.initialEmployeeId,
    this.initialPhoneNumber,
  });

  final String? initialEmployeeId;
  final String? initialPhoneNumber;

  @override
  ConsumerState<GuardPinSetupScreen> createState() =>
      _GuardPinSetupScreenState();
}

class _GuardPinSetupScreenState extends ConsumerState<GuardPinSetupScreen> {
  late final TextEditingController _employeeIdController;
  late final TextEditingController _phoneController;
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  DateTime? _selectedDob;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _employeeIdController = TextEditingController(
      text: widget.initialEmployeeId ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.initialPhoneNumber ?? '',
    );
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String pin = _pinController.text.trim();
    final String confirmPin = _confirmPinController.text.trim();
    if (pin != confirmPin) {
      setState(() {
        _error = 'PIN confirmation does not match.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).setupGuardPin(
            employeeId: _employeeIdController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            dateOfBirth: _selectedDob != null
                ? DateFormat('yyyy-MM-dd').format(_selectedDob!)
                : _dobController.text.trim(),
            pin: pin,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN set successfully. Please log in to continue.'),
        ),
      );
      context.go('/login/guard');
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: <Widget>[
            const BrandBanner(showBackButton: true,
              title: 'First-time guard PIN setup',
              subtitle:
                  'Create your duty PIN so this device can sign in with your guard account.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Set up your PIN',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: tokens.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Enter the same phone number recorded for your employee profile, confirm your date of birth, and choose a 4 to 6 digit PIN.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _employeeIdController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID (optional)',
                      hintText: 'CISS/TCS/2025-26/871',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Registered phone number',
                      hintText: '9048255377',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: () async {
                      final initialDate = _selectedDob ?? DateTime(1995);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: DateTime(1960),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDob = picked;
                          _dobController.text =
                              DateFormat('dd/MM/yyyy').format(picked);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      hintText: 'Select date',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'New PIN',
                      hintText: '1234',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _confirmPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      hintText: '1234',
                      prefixIcon: Icon(Icons.lock_person_outlined),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Create PIN'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
