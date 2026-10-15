import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../motion.dart';
import '../../core/settings/remote_config_provider.dart';
import '../../core/settings/route_modules.dart';
import '../../core/fcm/duty_notification_destination.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/shared/module_unavailable_screen.dart';
import '../../features/auth/presentation/role_login_screen.dart';
import '../../features/auth/presentation/auth_gate_screen.dart';
import '../../features/auth/presentation/guard_pin_setup_screen.dart';
import '../../features/auth/presentation/login_hub_screen.dart';
import '../../features/auth/presentation/permission_onboarding_screen.dart';
import '../../features/guard/presentation/screens/guard_duties_screen.dart';
import '../../features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import '../../features/attendance_qr/qr_attendance_flow.dart';
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
      final faded = FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
        ),
        child: child,
      );
      // Respect the OS "reduce motion" setting: collapse to a cross-fade.
      if (MediaQuery.disableAnimationsOf(context)) {
        return faded;
      }
      return SlideTransition(
        position: Tween<Offset>(
          begin: AppMotion.routeSlideBegin,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.standardCurve),
        ),
        child: faded,
      );
    },
    transitionDuration: AppMotion.routeIn,
    reverseTransitionDuration: AppMotion.routeOut,
  );
}

/// Application router. A provider (not a global) so the module-gating
/// redirect can read server-driven settings and re-evaluate when they change.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(remoteConfigProvider, (_, __) => refresh.value++);
  ref.listen(workspaceAccessSessionKeyProvider, (_, __) => refresh.value++);
  ref.listen(authSessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final flags = ref.read(remoteConfigProvider).modules;
      final moduleRedirect = gatedRedirect(path: state.uri.path, flags: flags);
      if (moduleRedirect != null) return moduleRedirect;
      final path = state.uri.path;
      if (path.startsWith('/guard/duties/') ||
          path.startsWith('/field-officer/work-orders/')) {
        final session = ref.read(authSessionProvider).valueOrNull;
        final sessionKey =
            session == null ? null : '${session.role.name}:${session.uid}';
        final expectedRole =
            path.startsWith('/guard/duties/') ? 'guard' : 'fieldOfficer';
        if (session == null ||
            sessionKey == null ||
            session.role.name != expectedRole ||
            ref.read(workspaceAccessSessionKeyProvider) != sessionKey) {
          return '/';
        }
      }
      return null;
    },
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
        path: '/guard/duties/:id',
        pageBuilder:
            (BuildContext context, GoRouterState state) => _buildPage(
              context: context,
              state: state,
              child: _WorkspaceAccessRouteGuard(
                roleName: 'guard',
                child: _DutyNotificationDestinationLifetime(
                  destinationKey:
                      state.extra is String ? state.extra! as String : null,
                  child: GuardDutiesScreen(
                    initialDutyId: state.pathParameters['id'],
                  ),
                ),
              ),
            ),
      ),
      GoRoute(
        path: '/field-officer/work-orders/:id',
        pageBuilder:
            (BuildContext context, GoRouterState state) => _buildPage(
              context: context,
              state: state,
              child: _WorkspaceAccessRouteGuard(
                roleName: 'fieldOfficer',
                child: _DutyNotificationDestinationLifetime(
                  destinationKey:
                      state.extra is String ? state.extra! as String : null,
                  child: FieldOfficerWorkOrdersScreen(
                    initialWorkOrderId: state.pathParameters['id'],
                  ),
                ),
              ),
            ),
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
        path: '/module-unavailable',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _buildPage(
            context: context,
            state: state,
            child: const ModuleUnavailableScreen(),
          );
        },
      ),
    ],
  );
});

/// GoRouter can update its location while an imperative push remains on the
/// Navigator stack. This in-page guard closes that pushed page immediately
/// when AuthGate revokes access on relock, account switch or role change.
class _WorkspaceAccessRouteGuard extends ConsumerWidget {
  const _WorkspaceAccessRouteGuard({
    required this.roleName,
    required this.child,
  });
  final String roleName;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final allowed =
        session != null &&
        session.role.name == roleName &&
        ref.watch(workspaceAccessSessionKeyProvider) ==
            '${session.role.name}:${session.uid}';
    if (!allowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).maybePop();
        }
      });
      return const SizedBox.shrink();
    }
    return child;
  }
}

class _DutyNotificationDestinationLifetime extends ConsumerStatefulWidget {
  const _DutyNotificationDestinationLifetime({
    required this.destinationKey,
    required this.child,
  });

  final String? destinationKey;
  final Widget child;

  @override
  ConsumerState<_DutyNotificationDestinationLifetime> createState() =>
      _DutyNotificationDestinationLifetimeState();
}

class _DutyNotificationDestinationLifetimeState
    extends ConsumerState<_DutyNotificationDestinationLifetime> {
  late ProviderContainer _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    final key = widget.destinationKey;
    if (key != null) {
      final container = _container;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final provider = dutyNotificationActiveDestinationsProvider;
          final current = container.read(provider);
          container.read(provider.notifier).state = <String>{...current}
            ..remove(key);
        } catch (_) {
          // The provider container may already be disposing this route.
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
