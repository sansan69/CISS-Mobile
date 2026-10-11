import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/cache/preload_controller.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../guard_tab_provider.dart';
import '../../../core/fcm/notification_service.dart';
import '../../../shared/widgets/floating_nav_bar.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../../../shared/widgets/status_chip.dart';
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
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      screen: GuardDashboardScreen(),
    ),
    _GuardTab(
      label: 'Duty',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      screen: GuardAttendanceScreen(),
    ),
    _GuardTab(
      label: 'Activity',
      icon: Icons.local_activity_outlined,
      activeIcon: Icons.local_activity_rounded,
      screen: GuardActivityScreen(),
    ),
    _GuardTab(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      screen: GuardProfileHubScreen(),
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
    ref.watch(guardDashboardProvider);
    ref.watch(guardProfileProvider);

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
        body: Stack(
          children: [
            IndexedStack(
              index: index,
              children: _tabs.map((t) => t.screen).toList(),
            ),
            FloatingNavBar(
              currentIndex: index,
              onTap: (i) {
                Haptics.selection();
                ref.read(guardTabIndexProvider.notifier).state = i;
              },
              items: _tabs
                  .map(
                    (t) => FloatingNavItem(
                      icon: t.icon,
                      selectedIcon: t.activeIcon,
                      label: t.label,
                    ),
                  )
                  .toList(),
            ),
          ],
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

class GuardActivityScreen extends ConsumerWidget {
  const GuardActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: 120 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            ModernHero(
              eyebrow: 'Operations',
              title: 'Duty Activity',
              subtitle: 'Patrol, hourly night checks, leave and incident reports.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: <Widget>[
                  GuardRecordCard(
                    title: 'Patrol & Night Checks',
                    subtitle: 'Hourly photo checks and patrol checkpoint rounds',
                    icon: Icons.route_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GuardPatrolScreen(),
                        ),
                      );
                    },
                  ),
                  GuardRecordCard(
                    title: 'Leave Requests',
                    subtitle: 'Apply for time off and review approval status',
                    icon: Icons.event_available_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GuardLeaveScreen(),
                        ),
                      );
                    },
                  ),
                  GuardRecordCard(
                    title: 'Incident Reports',
                    subtitle: 'Report field safety or security incidents with photo',
                    icon: Icons.report_gmailerrorred_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GuardIncidentsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuardProfileHubScreen extends ConsumerWidget {
  const GuardProfileHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: 120 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            ModernHero(
              eyebrow: 'Account',
              title: 'Profile & Growth',
              subtitle: 'Credentials, payslips, training modules, and settings.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: <Widget>[
                  GuardRecordCard(
                    title: 'Personal Profile',
                    subtitle: 'Personal details and document verification status',
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
                    title: 'Salary Payslips',
                    subtitle: 'Monthly earnings, deductions, and PDF slips',
                    icon: Icons.receipt_long_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GuardPayslipsScreen(),
                        ),
                      );
                    },
                  ),
                  GuardRecordCard(
                    title: 'Training & Quizzes',
                    subtitle: 'Assigned learning modules, tests, and certifications',
                    icon: Icons.school_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GuardTrainingScreen(),
                        ),
                      );
                    },
                  ),
                  GuardRecordCard(
                    title: 'Evaluations & Awards',
                    subtitle: 'Performance ratings, criteria breakdown, and honors',
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
                  const SizedBox(height: AppSpacing.md),
                  const ThemeModeSelector(),
                  const SizedBox(height: AppSpacing.lg),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef GuardMoreScreen = GuardProfileHubScreen;

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
