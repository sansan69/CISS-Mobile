import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/cache/preload_controller.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../guard_tab_provider.dart';
import '../../../core/fcm/notification_service.dart';
import '../../../shared/widgets/modern_card.dart';
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
      label: 'Schedule',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      screen: _GuardScheduleHolder(),
    ),
    _GuardTab(
      label: 'Activity',
      icon: Icons.trending_up_outlined,
      activeIcon: Icons.trending_up_rounded,
      screen: _GuardActivityHolder(),
    ),
    _GuardTab(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
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
        body: SafeArea(
          bottom: false, // NavigationBar handles bottom inset
          child: IndexedStack(
            index: index,
            children: _tabs.map((t) => t.screen).toList(),
          ),
        ),
        bottomNavigationBar: _buildPillNav(context, index, ref),
      ),
    );
  }

  Widget _buildPillNav(BuildContext context, int index, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isSelected = i == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    Haptics.selection();
                    ref.read(guardTabIndexProvider.notifier).state = i;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? tokens.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          isSelected ? tab.activeIcon : tab.icon,
                          size: 20,
                          color: isSelected ? Colors.white : tokens.inkMuted,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _GuardScheduleHolder extends ConsumerWidget {
  const _GuardScheduleHolder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return Column(
      children: <Widget>[
        Container(
          color: tokens.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _GuardSubTab(label: 'Training', icon: Icons.school_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardTrainingScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _GuardSubTab(label: 'Payslips', icon: Icons.receipt_long_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardPayslipsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _GuardSubTab(label: 'Leave', icon: Icons.event_available_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardLeaveScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: tokens.border),
        const Expanded(child: GuardTrainingScreen()),
      ],
    );
  }
}

class _GuardActivityHolder extends ConsumerWidget {
  const _GuardActivityHolder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return Column(
      children: <Widget>[
        Container(
          color: tokens.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _GuardSubTab(label: 'Attendance', icon: Icons.fact_check_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardAttendanceScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _GuardSubTab(label: 'Patrol', icon: Icons.route_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardPatrolScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _GuardSubTab(label: 'Incidents', icon: Icons.report_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardIncidentsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _GuardSubTab(label: 'Evals', icon: Icons.workspace_premium,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardEvaluationsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: tokens.border),
        const Expanded(child: GuardAttendanceScreen()),
      ],
    );
  }
}

class _GuardSubTab extends StatelessWidget {
  const _GuardSubTab({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ModernCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: tokens.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: tokens.ink,
              ),
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

class GuardMoreScreen extends ConsumerWidget {
  const GuardMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            ModernHero(
              eyebrow: 'Guard Workspace',
              title: 'Tools & Support',
              subtitle: 'Manage profile, requests, reports, and preferences.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: <Widget>[
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
              ),
            ),
          ],
        ),
      ),
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
