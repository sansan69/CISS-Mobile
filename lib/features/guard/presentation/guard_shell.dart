import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/cache/preload_controller.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../guard_tab_provider.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../core/fcm/notification_service.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../../shared/notification_inbox_screen.dart';
import 'screens/guard_attendance_screen.dart';
import 'screens/guard_dashboard_screen.dart';
import 'screens/guard_evaluations_screen.dart';
import 'screens/guard_incidents_screen.dart';
import 'screens/guard_leave_screen.dart';
import 'screens/guard_payslips_screen.dart';
import 'screens/guard_patrol_screen.dart';
import 'screens/guard_profile_screen.dart';
import 'screens/guard_training_screen.dart';
import 'widgets/guard_portal_widgets.dart';

class GuardShell extends ConsumerStatefulWidget {
  const GuardShell({super.key});

  @override
  ConsumerState<GuardShell> createState() => _GuardShellState();
}

class _GuardShellState extends ConsumerState<GuardShell> {
  static const List<_GuardTab> _tabs = <_GuardTab>[
    _GuardTab(
      label: 'Dashboard',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      screen: GuardDashboardScreen(),
    ),
    _GuardTab(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      screen: GuardAttendanceScreen(),
    ),
    _GuardTab(
      label: 'Training',
      icon: Icons.school_outlined,
      activeIcon: Icons.school_rounded,
      screen: GuardTrainingScreen(),
    ),
    _GuardTab(
      label: 'Payslips',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      screen: GuardPayslipsScreen(),
    ),
    _GuardTab(
      label: 'More',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      screen: GuardMoreScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Preload ALL guard data eagerly after login so tab switching is instant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preloadControllerProvider).preloadAllGuard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(guardTabIndexProvider);

    // Keep all guard data providers alive so tab switching is instant.
    // These watches ensure the providers never auto-dispose.
    ref.watch(guardDashboardProvider);
    ref.watch(attendanceSitesProvider);
    ref.watch(guardProfileProvider);
    ref.watch(guardTrainingProvider);
    ref.watch(guardPayslipsProvider);
    ref.watch(guardEvaluationsProvider);
    ref.watch(guardIncidentsProvider);
    ref.watch(guardLeaveProvider);
    ref.watch(guardPatrolStatusProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? shouldExit = await showDialog<bool>(
          context: context,
          builder:
              (BuildContext ctx) => AlertDialog(
                title: const Text('Exit CISS Workforce?'),
                content: const Text('Are you sure you want to close the app?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Stay'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
        );
        if (shouldExit == true && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false, // NavigationBar handles bottom inset
          child: IndexedStack(
            index: index,
            children: _tabs.map((t) => t.screen).toList(),
          ),
        ),
        bottomNavigationBar: BrandedNavigationBar(
          selectedIndex: index,
          onSelected: (int i) {
            Haptics.selection();
            ref.read(guardTabIndexProvider.notifier).state = i;
          },
          items:
              _tabs
                  .map(
                    (_GuardTab tab) => BrandedNavigationItem(
                      label: tab.label,
                      icon: tab.icon,
                      activeIcon: tab.activeIcon,
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _GuardTab {
  const _GuardTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
}

class GuardMoreScreen extends ConsumerWidget {
  const GuardMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return ScreenScaffold(
      title: 'More',
      subtitle: 'Guard tools and account settings',
      children: <Widget>[
        GuardHeroPanel(
          eyebrow: 'Guard workspace',
          title: 'Tools and support',
          subtitle: 'Manage profile, requests, reports, and app preferences.',
          icon: Icons.grid_view_rounded,
          accentColor: tokens.accent,
        ),
        const SizedBox(height: AppSpacing.lg),
        const ThemeModeSelector(),
        const SizedBox(height: AppSpacing.md),
        GuardRecordCard(
          title: 'Notifications',
          subtitle: 'View alerts, updates, and broadcasts',
          icon: Icons.notifications_outlined,
          trailing: const _NotificationBadge(),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationInboxScreen(),
              ),
            );
          },
        ),
        GuardRecordCard(
          title: 'Patrol',
          subtitle: 'Hourly night checks and patrol rounds',
          icon: Icons.route_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GuardPatrolScreen(),
              ),
            );
          },
        ),
        GuardRecordCard(
          title: 'Profile',
          subtitle: 'Personal and employment details',
          icon: Icons.person_outline_rounded,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GuardProfileScreen(),
              ),
            );
          },
        ),
        GuardRecordCard(
          title: 'Leave',
          subtitle: 'Apply and review leave requests',
          icon: Icons.event_available_rounded,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuardLeaveScreen()),
            );
          },
        ),
        GuardRecordCard(
          title: 'Evaluations',
          subtitle: 'Quiz and performance records',
          icon: Icons.workspace_premium_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GuardEvaluationsScreen(),
              ),
            );
          },
        ),
        GuardRecordCard(
          title: 'Incidents',
          subtitle: 'Report incidents from the field',
          icon: Icons.report_gmailerrorred_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GuardIncidentsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () {
            Haptics.heavy();
            showDialog(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                      'You will be signed out of your account.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ref.read(authControllerProvider).signOut();
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: tokens.dangerSoft,
            foregroundColor: tokens.danger,
          ),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _NotificationBadge extends ConsumerWidget {
  const _NotificationBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(NotificationService.unreadCountProvider);
    return unreadAsync.when(
      data:
          (count) =>
              count > 0
                  ? StatusChip(label: '$count new', tone: StatusChipTone.danger)
                  : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
