import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_gate_screen.dart';
import '../../features/auth/presentation/guard_pin_setup_screen.dart';
import '../../features/auth/presentation/login_hub_screen.dart';
import '../../features/auth/presentation/permission_onboarding_screen.dart';
import '../../features/auth/presentation/role_login_screen.dart';
import '../../features/field_officer/presentation/field_officer_shell.dart';
import '../../features/guard/presentation/guard_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const AuthGateScreen();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginHubScreen();
      },
    ),
    GoRoute(
      path: '/login/guard',
      builder: (BuildContext context, GoRouterState state) {
        return const RoleLoginScreen.guard();
      },
    ),
    GoRoute(
      path: '/login/guard/setup',
      builder: (BuildContext context, GoRouterState state) {
        final params = state.uri.queryParameters;
        return GuardPinSetupScreen(
          initialEmployeeId: params['employeeId'],
          initialPhoneNumber: params['phoneNumber'],
        );
      },
    ),
    GoRoute(
      path: '/login/field-officer',
      builder: (BuildContext context, GoRouterState state) {
        return const RoleLoginScreen.fieldOfficer();
      },
    ),
    GoRoute(
      path: '/permissions',
      builder: (BuildContext context, GoRouterState state) {
        return const PermissionOnboardingScreen();
      },
    ),
    GoRoute(
      path: '/guard',
      builder: (BuildContext context, GoRouterState state) {
        return const GuardShell();
      },
    ),
    GoRoute(
      path: '/field-officer',
      builder: (BuildContext context, GoRouterState state) {
        return const FieldOfficerShell();
      },
    ),
  ],
);
