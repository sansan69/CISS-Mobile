import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/models/auth_session.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/biometric_setup_controller.dart';
import 'biometric_setup_sheet.dart';

/// Security settings surface (guard profile + field-officer More screen).
///
/// Fingerprint unlock here is account-bound and fingerprint-only:
/// - Devices without a fingerprint scanner (optical/ultrasonic) show a
///   disabled state — face/iris/weak-class biometrics do not qualify.
/// - Devices with a scanner but no enrolled fingerprint get guidance and a
///   deep link to the OS enrollment screen (from the setup sheet).
/// - Enabling/disabling goes through the industry-standard flow in
///   [BiometricSetupSheet] (server-verified credential + fingerprint gate).
class SecuritySettingsCard extends ConsumerStatefulWidget {
  const SecuritySettingsCard({super.key});

  @override
  ConsumerState<SecuritySettingsCard> createState() =>
      _SecuritySettingsCardState();
}

class _SecuritySettingsCardState extends ConsumerState<SecuritySettingsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(authSessionProvider).value;
      if (session != null) {
        ref.read(biometricSetupProvider.notifier).load(session: session);
      }
    });
  }

  void _openSheet(AuthSession session) {
    final tokens = CissThemeTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        ref.read(biometricSetupProvider.notifier).load(session: session);
        return BiometricSetupSheet(session: session);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final session = ref.watch(authSessionProvider).value;
    final setupState = ref.watch(biometricSetupProvider);

    final availability = setupState.support.availability;
    final enabled = setupState.accountEnabled;

    final String subtitle;
    switch (availability) {
      case FingerprintAvailability.supported:
        subtitle = enabled
            ? 'Sign in with your fingerprint for this account.'
            : 'Register your fingerprint to sign in without typing.';
      case FingerprintAvailability.notEnrolled:
        subtitle = 'Scanner detected — no fingerprint registered yet.';
      case FingerprintAvailability.noSensor:
      case FingerprintAvailability.unknown:
        subtitle = 'No fingerprint scanner on this device.';
    }

    final bool actionable =
        availability == FingerprintAvailability.supported ||
        availability == FingerprintAvailability.notEnrolled;

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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.fingerprint_rounded,
              color: actionable ? tokens.primary : tokens.inkMuted,
            ),
            title: const Text('Fingerprint unlock'),
            subtitle: Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.inkMuted,
              ),
            ),
            trailing: actionable
                ? Switch(
                    value: enabled,
                    onChanged:
                        session != null ? (_) => _openSheet(session) : null,
                    activeTrackColor: tokens.primary,
                  )
                : const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: actionable && session != null
                ? () => _openSheet(session)
                : null,
          ),
          if (availability == FingerprintAvailability.notEnrolled) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add a fingerprint in your phone Settings, then enable '
              'fingerprint unlock here.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
