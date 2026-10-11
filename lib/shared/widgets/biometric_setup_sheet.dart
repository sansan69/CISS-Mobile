import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/location/device_compat_service.dart';
import '../../../core/haptics.dart';
import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
import '../../features/auth/application/biometric_setup_controller.dart';
import '../../../shared/widgets/status_chip.dart';

/// Biometric app-lock enrollment sheet for guards and field officers.
///
/// Guides the user through the industry-standard enable flow:
/// 1. Device has an enrolled biometric — verified via
///    [FingerprintAvailability].
/// 2. If no qualifying biometric is enrolled, deep-link to device enrollment.
/// 3. Enable: verify PIN/password against the backend, then confirm a strong
///    biometric gesture before enabling the account's app lock.
/// 4. Disable: confirm with a biometric gesture before clearing it.
class BiometricSetupSheet extends ConsumerStatefulWidget {
  const BiometricSetupSheet({super.key, required this.session});

  final AuthSession session;

  @override
  ConsumerState<BiometricSetupSheet> createState() =>
      _BiometricSetupSheetState();
}

class _BiometricSetupSheetState extends ConsumerState<BiometricSetupSheet> {
  final TextEditingController _passwordController = TextEditingController();
  final DeviceCompatService _deviceCompat = DeviceCompatService();
  bool _verifying = false;
  String? _message;
  bool _messageIsError = false;

  bool get _isGuard => widget.session.role == AppRole.guard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(biometricSetupProvider.notifier).load(session: widget.session);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    final enteredCredential = _passwordController.text;
    // Guard PINs are normalized; Field Officer passwords are opaque and must
    // reach Firebase exactly as the officer entered them.
    final password = _isGuard ? enteredCredential.trim() : enteredCredential;
    if (password.isEmpty) {
      setState(() {
        _message =
            _isGuard
                ? 'Enter your duty PIN to continue.'
                : 'Enter your account password to continue.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _verifying = true;
      _message = null;
    });

    final result = await ref
        .read(biometricSetupProvider.notifier)
        .enable(session: widget.session, password: password);

    if (!mounted) return;
    setState(() {
      _verifying = false;
      _message = result.message;
      _messageIsError = !result.success;
    });
    if (result.success) {
      Haptics.heavy();
      _passwordController.clear();
    }
  }

  Future<void> _disable() async {
    setState(() {
      _verifying = true;
      _message = null;
    });
    final result = await ref
        .read(biometricSetupProvider.notifier)
        .disable(session: widget.session);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _message = result.message;
      _messageIsError = !result.success;
    });
    if (result.success) {
      Haptics.heavy();
    }
  }

  Future<void> _openFingerprintSettings() async {
    await _deviceCompat.openFingerprintEnrollSettings();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final state = ref.watch(biometricSetupProvider);
    final availability = state.support.availability;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 28,
                      color: tokens.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometric app lock',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.session.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (state.accountEnabled)
                    const StatusChip(label: 'ON', tone: StatusChipTone.success),
                ],
              ),
              const SizedBox(height: 18),

              if (availability == FingerprintAvailability.noSensor ||
                  availability == FingerprintAvailability.unknown) ...[
                _InfoBlock(
                  icon: Icons.smartphone_rounded,
                  title: 'No biometric authentication available',
                  message:
                      'This device does not have an enrolled biometric '
                      'available for app lock.',
                ),
              ] else if (availability ==
                  FingerprintAvailability.notEnrolled) ...[
                _InfoBlock(
                  icon: Icons.fingerprint_rounded,
                  title: 'No biometric set up on this device',
                  message:
                      'Register a biometric in your phone Settings '
                      'first, then come back to enable the app lock.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openFingerprintSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('OPEN BIOMETRIC SETTINGS'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ] else ...[
                if (state.accountEnabled) ...[
                  _InfoBlock(
                    icon: Icons.check_circle_rounded,
                    title: 'Biometric app lock is on',
                    message:
                        'Biometric authentication is required to reopen this active '
                        'account session on this device. Your PIN or password '
                        'is not stored on-device.',
                    tone: _InfoTone.success,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _verifying ? null : _disable,
                      icon: const Icon(Icons.fingerprint_rounded, size: 18),
                      label: const Text('DISABLE STRONG BIOMETRIC APP LOCK'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: tokens.danger,
                        side: BorderSide(color: tokens.danger),
                      ),
                    ),
                  ),
                ] else ...[
                  _InfoBlock(
                    icon: Icons.shield_rounded,
                    title: 'Enable biometric app lock',
                    message:
                        _isGuard
                            ? 'Enter your duty PIN to verify, then verify your '
                                'biometric authentication to enable the app lock.'
                            : 'Enter your account password to verify, then verify '
                                'biometric authentication to enable the app lock.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_verifying,
                    keyboardType:
                        _isGuard
                            ? TextInputType.number
                            : TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: _isGuard ? 'Duty PIN' : 'Account password',
                      helperText:
                          'Verified against the CISS server before enabling.',
                      prefixIcon: Icon(
                        _isGuard
                            ? Icons.pin_rounded
                            : Icons.lock_outline_rounded,
                      ),
                    ),
                    onSubmitted: (_) => _enable(),
                  ),
                  const SizedBox(height: 12),
                  if (_message != null) ...[
                    _MessageLine(message: _message!, isError: _messageIsError),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _verifying ? null : _enable,
                      icon:
                          _verifying
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.fingerprint_rounded, size: 18),
                      label: Text(
                        _verifying
                            ? 'VERIFYING...'
                            : 'ENABLE STRONG BIOMETRIC APP LOCK',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  if (_message != null && !_messageIsError) ...[
                    const SizedBox(height: 8),
                    _MessageLine(message: _message!, isError: false),
                  ],
                ],
              ],

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Biometric data never leaves your device.',
                  style: TextStyle(fontSize: 11, color: tokens.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _InfoTone { neutral, success }

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = _InfoTone.neutral,
  });

  final IconData icon;
  final String title;
  final String message;
  final _InfoTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = tone == _InfoTone.success ? tokens.success : tokens.primary;
    final soft =
        tone == _InfoTone.success ? tokens.successSoft : tokens.primarySoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = isError ? tokens.danger : tokens.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 13, color: color, height: 1.35),
          ),
        ),
      ],
    );
  }
}
