import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../application/auth_controller.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/app_role.dart';
import '../../../core/models/auth_session.dart';
import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/brand.dart';
import '../../../core/location/background_tracking_service.dart';
import '../../../core/network/providers.dart';
import '../../../core/region/region_service.dart';
import '../../../shared/widgets/auth/login_background.dart';
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
  bool _regionChecked = false;
  String? _bioMessage;
  String? _trackingReconciledUid;
  AuthSession? _lastSession;

  Future<void> _checkBiometrics(bool enabled) async {
    if (!enabled || _authenticated || _isAuthenticating) return;
    if (!mounted) return;

    setState(() {
      _isAuthenticating = true;
      _bioMessage = null;
    });
    try {
      final biometricService = ref.read(biometricServiceProvider);
      final outcome = await biometricService.authenticateFingerprint(
        localizedReason: 'Authenticate to access your duty workspace',
      );

      if (!mounted) return;
      switch (outcome) {
        case BiometricAuthOutcome.success:
          setState(() {
            _authenticated = true;
            _isAuthenticating = false;
          });
        case BiometricAuthOutcome.notAvailable:
        case BiometricAuthOutcome.notEnrolled:
          // The stored binding no longer matches this device — never brick
          // the user; fall back to a fresh PIN/password sign-in.
          setState(() {
            _isAuthenticating = false;
            _bioMessage =
                'Fingerprint unlock is not available right now. '
                'Sign in with your PIN or password to continue.';
          });
        case BiometricAuthOutcome.permanentlyLockedOut:
          setState(() {
            _isAuthenticating = false;
            _bioMessage =
                'Fingerprint was permanently locked on this device. '
                'Sign in with your PIN or password to continue.';
          });
        case BiometricAuthOutcome.lockedOut:
          setState(() {
            _isAuthenticating = false;
            _bioMessage =
                'Fingerprint is temporarily locked. Unlock your phone '
                'with its PIN or pattern, then retry.';
          });
        case BiometricAuthOutcome.failed:
        case BiometricAuthOutcome.error:
          setState(() {
            _isAuthenticating = false;
            _bioMessage = 'Could not verify with fingerprint. Try again.';
          });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _bioMessage = 'Could not verify with fingerprint. Please try again.';
      });
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
      value:
          isDark
              ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
              : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
      child: sessionAsync.when(
        // Show a branded skeleton on initial load instead of a bare spinner.
        loading: () => const _AppLoadingScreen(),
        error:
            (Object error, StackTrace stackTrace) => Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: CissThemeTokens.of(context).danger,
                        ),
                        const SizedBox(height: 16),
                        Text('Could not sign in. Please try again.', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(authSessionProvider),
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(authControllerProvider).signOut();
                          },
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        data: (session) {
          // Reset permission check when session changes (new login).
          if (_lastSession?.uid != session?.uid) {
            _permissionsChecked = false;
            _bioTriggered = false;
            _authenticated = false;
            _trackingReconciledUid = null;
          }
          _lastSession = session;

          if (session == null) {
            if (!_regionChecked) {
              _regionChecked = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                final router = GoRouter.of(context);
                final saved =
                    await ref.read(regionServiceProvider).getSavedRegion();
                if (!mounted) return;
                if (saved == null) {
                  router.go('/region-select');
                }
              });
            }
            return const LoginHubScreen();
          }

          // Biometric Gate — triggered once via post-frame callback,
          // NOT called directly in build to avoid infinite prompt loops.
          if (settings.biometricsEnabled && !_authenticated) {
            _maybeTriggerBiometrics();
            return _BiometricLockScreen(
              onRetry:
                  () => setState(() {
                    _isAuthenticating = false;
                    _bioTriggered = false;
                    _bioMessage = null;
                  }),
              onUsePassword: () {
                ref.read(authControllerProvider).signOut();
              },
              isAuthenticating: _isAuthenticating,
              message: _bioMessage,
            );
          }

          // Non-blocking permission check for guard — show shell immediately,
          // check permissions in background.
          if (session.role == AppRole.guard && !_permissionsChecked) {
            _permissionsChecked = true;
            unawaited(_prepareGuardRuntime(session.uid));
          }

          if (session.role == AppRole.fieldOfficer) {
            return const FieldOfficerShell();
          }

          return const GuardShell();
        },
      ),
    );
  }

  /// Verifies the Android runtime prerequisites before recovering an active
  /// shift. This avoids starting the foreground service while permission
  /// onboarding is still in progress.
  Future<void> _prepareGuardRuntime(String uid) async {
    try {
      final statuses = await Future.wait([
        Permission.location.status,
        Permission.camera.status,
        Permission.notification.status,
      ]);
      if (!mounted) return;

      final allGranted = statuses.every((status) => status.isGranted);
      if (!allGranted) {
        context.go('/permissions');
        return;
      }

      if (_trackingReconciledUid == uid) return;
      _trackingReconciledUid = uid;
      await BackgroundTrackingService.initialize();
      await BackgroundTrackingService.reconcileWithServer(
        ref.read(mobileRepositoryProvider),
      );
    } catch (error) {
      debugPrint('Tracking reconciliation deferred: $error');
    }
  }
}

/// Branded loading screen shown during initial session resolution.
class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SecurityGridBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand mark with solid ring
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.primary,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.canvas,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(kCompanyLogoAsset, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  kCompanyName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.inkMuted,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 36,
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: tokens.surfaceMuted,
                    color: tokens.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometricLockScreen extends StatelessWidget {
  const _BiometricLockScreen({
    required this.onRetry,
    required this.onUsePassword,
    required this.isAuthenticating,
    this.message,
  });

  final VoidCallback onRetry;
  final VoidCallback onUsePassword;
  final bool isAuthenticating;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      body: SecurityGridBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock icon on solid background
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'App Locked',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message ??
                        'Place your finger on the scanner to continue '
                            'accessing your workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message == null ? tokens.inkMuted : tokens.warning,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (isAuthenticating)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: tokens.primary,
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(Icons.fingerprint_rounded, size: 20),
                        label: const Text('Try fingerprint again'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onUsePassword,
                      child: const Text('Sign in with PIN or password'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
