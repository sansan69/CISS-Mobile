import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../application/auth_controller.dart';
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

  Future<void> _checkBiometrics(bool enabled) async {
    if (!enabled || _authenticated || _isAuthenticating) return;

    setState(() => _isAuthenticating = true);
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
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
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

          // Biometric Gate
          if (settings.biometricsEnabled && !_authenticated) {
            _checkBiometrics(true);
            return _BiometricLockScreen(
              onRetry: () => _checkBiometrics(true),
              isAuthenticating: _isAuthenticating,
            );
          }

          if (session.role == AppRole.fieldOfficer) {
            return const FieldOfficerShell();
          }

          // Guard: check that the two operationally-required permissions are
          // granted (location for geofencing, camera for photo attendance).
          return FutureBuilder<bool>(
            future: _checkCorePermissions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.data == false) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) context.go('/permissions');
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return const GuardShell();
            },
          );
        },
      ),
    );
  }

  Future<bool> _checkCorePermissions() async {
    final statuses = await Future.wait([
      Permission.location.status,
      Permission.camera.status,
    ]);
    return statuses.every((s) => s.isGranted);
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.blueGrey),
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
    );
  }
}
