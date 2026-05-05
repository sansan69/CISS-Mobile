import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/theme_mode_controller.dart';
import '../../core/auth/biometric_service.dart';

class SecuritySettingsCard extends ConsumerWidget {
  const SecuritySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    final biometricService = ref.watch(biometricServiceProvider);

    return FutureBuilder<bool>(
      future: biometricService.isSupported(),
      builder: (context, snapshot) {
        final bool isSupported = snapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Security', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Protect your duty workspace with device security.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Biometric Unlock'),
                subtitle: Text(
                  isSupported
                      ? 'Use Fingerprint or Face ID to unlock the app.'
                      : 'Biometrics not supported on this device.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
                value: settings.biometricsEnabled && isSupported,
                onChanged: isSupported
                    ? (bool value) {
                        ref
                            .read(appSettingsControllerProvider.notifier)
                            .setBiometricsEnabled(value);
                      }
                    : null,
                activeTrackColor: tokens.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}
