import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

class GuardForgotPinScreen extends StatelessWidget {
  const GuardForgotPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(title: const Text('Forgot PIN')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: tokens.primaryStrong,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Ask an administrator to reset your PIN',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'For your security, guard PINs cannot be reset using '
                    'personal details in the app.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.inkMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Text(
                      'Contact your CISS administrator and provide your '
                      'employee ID. The administrator will verify your '
                      'identity, reset the PIN, and record the action.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.ink,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Return to guard login'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.key_rounded, size: 16, color: tokens.inkMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'First-time PIN setup remains available.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
