import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/providers.dart';

/// Guard forgot PIN recovery screen.
/// Guard enters their employee ID and phone number to request a PIN reset.
///
/// Mirrors web app's /guard-forgot-pin flow.
class GuardForgotPinScreen extends ConsumerStatefulWidget {
  const GuardForgotPinScreen({super.key});

  @override
  ConsumerState<GuardForgotPinScreen> createState() => _GuardForgotPinScreenState();
}

class _GuardForgotPinScreenState extends ConsumerState<GuardForgotPinScreen> {
  final _employeeIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(mobileRepositoryProvider);
      await repo.resetGuardPin(
        employeeId: _employeeIdCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'PIN reset failed. Check your details and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Forgot PIN'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _submitted ? _buildSuccess(tokens) : _buildForm(tokens),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(CissThemeTokens tokens) {
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.lock_reset_rounded, color: tokens.primary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Reset Your PIN',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tokens.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your employee ID and registered phone number to receive a new PIN.',
              style: TextStyle(fontSize: 14, color: tokens.inkMuted),
            ),
            const SizedBox(height: 28),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: tokens.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: tokens.danger, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _employeeIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Employee ID *',
                prefixIcon: Icon(Icons.badge_outlined),
                hintText: 'e.g. CISS-1234',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '10-digit mobile number',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 10) return 'Enter 10-digit number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Reset PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(CissThemeTokens tokens) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tokens.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: tokens.success, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            'PIN Reset Requested',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tokens.ink),
          ),
          const SizedBox(height: 10),
          Text(
            'If the details match our records, your PIN has been reset. '
            'Contact your supervisor if you don\'t receive the new PIN shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tokens.inkMuted),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Login'),
            ),
          ),
        ],
      ),
    );
  }
}
