import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/role_login_screen.dart';
import '../../features/auth/presentation/auth_gate_screen.dart';
import '../../features/auth/presentation/guard_pin_setup_screen.dart';
import '../../features/auth/presentation/login_hub_screen.dart';
import '../../features/auth/presentation/admin_login_screen.dart';
import '../../features/auth/presentation/permission_onboarding_screen.dart';
import '../../features/attendance_qr/qr_attendance_flow.dart';
import '../../features/enrollment/presentation/guard_enrollment_screen.dart';
import '../../features/attendance_public/public_attendance_screen.dart';
import '../../features/region/presentation/region_selector_screen.dart';
import '../../core/gestures/edge_gesture_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Shared page transition used on all routes for consistent UX.
///
/// Slides in from the right with a brief fade, matching platform convention.
Page<void> _buildPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: EdgeGestureWrapper(child: child),
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const AuthGateScreen(),
        );
      },
    ),
    GoRoute(
      path: '/region-select',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const RegionSelectorScreen(),
        );
      },
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const LoginHubScreen(),
        );
      },
    ),
    GoRoute(
      path: '/login/guard',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const RoleLoginScreen.guard(),
        );
      },
    ),
    GoRoute(
      path: '/login/guard/setup',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final params = state.uri.queryParameters;
        return _buildPage(
          context: context,
          state: state,
          child: GuardPinSetupScreen(
            initialEmployeeId: params['employeeId'],
            initialPhoneNumber: params['phoneNumber'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/login/field-officer',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const RoleLoginScreen.fieldOfficer(),
        );
      },
    ),
    GoRoute(
      path: '/login/admin',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const AdminLoginScreen(),
        );
      },
    ),
    GoRoute(
      path: '/permissions',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const PermissionOnboardingScreen(),
        );
      },
    ),
    GoRoute(
      path: '/qr-attendance',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const QrAttendanceFlow(),
        );
      },
    ),
    GoRoute(
      path: '/attendance',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const PublicAttendanceScreen(),
        );
      },
    ),
    GoRoute(
      path: '/enroll',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildPage(
          context: context,
          state: state,
          child: const GuardEnrollmentScreen(),
        );
      },
    ),
  ],
);
