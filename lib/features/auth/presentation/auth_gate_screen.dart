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
import '../../../shared/widgets/auth/login_background.dart';
import '../../field_officer/presentation/field_officer_shell.dart';
import '../../guard/presentation/guard_shell.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../client/presentation/client_dashboard_screen.dart';
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
  AuthSession? _lastSession;

  Future<void> _checkBiometrics(bool enabled) async {
    if (!enabled || _authenticated || _isAuthenticating) return;
    if (!mounted) return;

    setState(() => _isAuthenticating = true);
    try {
      final biometricService = ref.read(biometricServiceProvider);
      final success = await biometricService.authenticate(
        localizedReason: 'Authenticate to access your duty workspace',
      );

      if (!mounted) return;
      setState(() {
        _authenticated = success;
        _isAuthenticating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      // Show error so user isn't silently locked out.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric error: $error'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              _bioTriggered = false;
              _maybeTriggerBiometrics();
            },
          ),
        ),
      );
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
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: CissThemeTokens.of(context).danger),
                    const SizedBox(height: 16),
                    Text('Auth error: $error', textAlign: TextAlign.center),
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
          }
          _lastSession = session;

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
          if (session.role == AppRole.admin) {
            return const AdminDashboardScreen();
          }
          if (session.role == AppRole.client) {
            return const ClientDashboardScreen();
          }

          return const GuardShell();
        },
      ),
    );
  }

  /// Check guard permissions in the background without blocking the UI.
  /// Routes to permission onboarding if any critical permission is missing.
  void _checkGuardPermissionsInBackground() {
    Future.wait([
      Permission.location.status,
      Permission.locationAlways.status,
      Permission.camera.status,
      Permission.notification.status,
    ]).then((statuses) {
      final allGranted = statuses.every((s) => s.isGranted);
      if (!allGranted && mounted) {
        context.go('/permissions');
      }
    }).catchError((_) {
      // Silently ignore permission check failures; they'll be checked again
      // when the user tries to use location or camera.
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
      body: SecurityGridBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand mark with gradient ring
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tokens.primary,
                        tokens.primaryStrong,
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.canvas,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      kCompanyLogoAsset,
                      fit: BoxFit.contain,
                    ),
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
    required this.isAuthenticating,
  });

  final VoidCallback onRetry;
  final bool isAuthenticating;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CissThemeTokens>()!;

    return Scaffold(
      body: SecurityGridBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock icon with gradient background
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tokens.primary,
                          tokens.primaryStrong,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tokens.primary.withValues(alpha: 0.25),
                          blurRadius: 32,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 44,
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
                    'Unlock with biometrics to continue accessing your workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.inkMuted,
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
                  else
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
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('Unlock App'),
                      ),
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
