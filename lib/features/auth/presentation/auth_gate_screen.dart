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
import '../../../core/brand.dart';
import '../../../core/location/background_tracking_service.dart';
import '../../../core/network/providers.dart';
import '../../../core/region/region_service.dart';
import '../../../shared/widgets/auth/login_background.dart';
import '../../field_officer/presentation/field_officer_shell.dart';
import '../../guard/presentation/guard_shell.dart';
import 'login_hub_screen.dart';

/// Session → workspace routing for the `/` route.
///
/// The biometric app lock deliberately lives outside this widget: it is an
/// app-level overlay rendered above the navigator (`AppLockOverlay` in
/// `lib/core/auth/app_lock_overlay.dart`), because a lock rendered from inside
/// one route is covered by every pushed route. This widget only decides which
/// authenticated surface to show, plus the one-time permission onboarding and
/// region redirects.
class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  bool _permissionsChecked = false;
  bool _regionChecked = false;
  String? _trackingReconciledUid;
  AuthSession? _lastSession;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(authSessionProvider);
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
        error: (Object error, StackTrace stackTrace) {
          final regionService = ref.read(regionServiceProvider);
          if (!regionService.hasActiveSelectedRegion) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) GoRouter.of(context).go('/region-select');
            });
            return const _AppLoadingScreen();
          }
          return Scaffold(
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
                      Text(
                        'Could not sign in. Please try again.',
                        textAlign: TextAlign.center,
                      ),
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
          );
        },
        data: (session) {
          // Reset permission check when session changes (new login).
          if (_lastSession?.uid != session?.uid ||
              _lastSession?.role != session?.role) {
            _permissionsChecked = false;
            _trackingReconciledUid = null;
          }
          _lastSession = session;

          if (session == null) {
            if (!_regionChecked) {
              _regionChecked = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                final router = GoRouter.of(context);
                final regionService = ref.read(regionServiceProvider);
                final saved = await regionService.getSavedRegion();
                if (!mounted) return;
                if (saved == null || !regionService.hasActiveSelectedRegion) {
                  router.go('/region-select');
                }
              });
            }
            return const LoginHubScreen();
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
