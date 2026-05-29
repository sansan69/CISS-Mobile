import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../application/auth_controller.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/app_role.dart';
import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/auth/biometric_service.dart';
import '../../field_officer/presentation/field_officer_shell.dart';
import '../../guard/presentation/guard_shell.dart';
import 'login_hub_screen.dart';

class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  bool _authenticated = false;
  bool _isAuthenticating = false;
  bool _permissionsChecked = false;
  bool _bioTriggered = false;

  Future<void> _checkBiometrics(bool enabled) async {
    if (!enabled || _authenticated || _isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final biometricService = ref.read(biometricServiceProvider);
      final success = await biometricService.authenticate(
        localizedReason: 'Authenticate to access your duty workspace',
      );

      if (mounted) {
        setState(() {
          _authenticated = success;
          _isAuthenticating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  /// Trigger biometric check once, after the first frame with a valid session.
  void _maybeTriggerBiometrics() {
    if (_bioTriggered) return;
    _bioTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = ref.read(appSettingsControllerProvider);
        _checkBiometrics(settings.biometricsEnabled);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(authSessionProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
      child: sessionAsync.when(
        // Show a branded skeleton on initial load instead of a bare spinner.
        loading: () => const _AppLoadingScreen(),
        error: (Object error, StackTrace stackTrace) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Auth error: $error'),
            ),
          ),
        ),
        data: (session) {
          if (session == null) {
            return const LoginHubScreen();
          }

          // Biometric Gate — triggered once via post-frame callback,
          // NOT called directly in build to avoid infinite prompt loops.
          if (settings.biometricsEnabled && !_authenticated) {
            _maybeTriggerBiometrics();
            return _BiometricLockScreen(
              onRetry: () => setState(() {
                _isAuthenticating = false;
                _bioTriggered = false;
              }),
              isAuthenticating: _isAuthenticating,
            );
          }

          // Non-blocking permission check for guard — show shell immediately,
          // check permissions in background.
          if (session.role == AppRole.guard && !_permissionsChecked) {
            _permissionsChecked = true;
            _checkGuardPermissionsInBackground();
          }

          if (session.role == AppRole.fieldOfficer) {
            return const FieldOfficerShell();
          }

          return const GuardShell();
        },
      ),
    );
  }

  /// Check guard permissions in the background without blocking the UI.
  void _checkGuardPermissionsInBackground() {
    Future.wait([
      Permission.location.status,
      Permission.camera.status,
    ]).then((statuses) {
      final allGranted = statuses.every((s) => s.isGranted);
      if (!allGranted && mounted) {
        context.go('/permissions');
      }
    });
  }
}

/// Branded loading screen shown during initial session resolution.
class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CissThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brand mark
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.15),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Image.asset('assets/ciss-logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 32,
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: tokens.surfaceMuted,
                  color: tokens.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricLockScreen extends StatelessWidget {
  const _BiometricLockScreen({
    required this.onRetry,
    required this.isAuthenticating,
  });

  final VoidCallback onRetry;
  final bool isAuthenticating;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CissThemeTokens>()!;
    return Scaffold(
      body: SafeArea(
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 64,
              color: tokens.inkMuted,
            ),
            const SizedBox(height: 24),
            const Text(
              'App Locked',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Unlock with biometrics to continue'),
            const SizedBox(height: 32),
            if (isAuthenticating)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock App'),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
