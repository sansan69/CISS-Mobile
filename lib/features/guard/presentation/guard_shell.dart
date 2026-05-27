import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/cache/preload_controller.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../guard_tab_provider.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../core/fcm/notification_service.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../../shared/notification_inbox_screen.dart';
import 'screens/guard_attendance_screen.dart';
import 'screens/guard_dashboard_screen.dart';
import 'screens/guard_evaluations_screen.dart';
import 'screens/guard_incidents_screen.dart';
import 'screens/guard_payslips_screen.dart';
import 'screens/guard_patrol_screen.dart';
import 'screens/guard_profile_screen.dart';
import 'screens/guard_training_screen.dart';

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
    ref.watch(guardPatrolStatusProvider);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: _tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: BrandedNavigationBar(
        selectedIndex: index,
        onSelected: (int i) {
          Haptics.selection();
          ref.read(guardTabIndexProvider.notifier).state = i;
        },
        items: _tabs
            .map(
              (_GuardTab tab) => BrandedNavigationItem(
                label: tab.label,
                icon: tab.icon,
                activeIcon: tab.activeIcon,
              ),
            )
            .toList(),
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
      title: 'More tools',
      subtitle: 'Profile, incident, training, and support actions',
      children: <Widget>[
        const ThemeModeSelector(),
        SectionCard(
          title: 'Notifications',
          subtitle: 'View alerts, updates, and broadcasts',
          icon: Icons.notifications_outlined,
          trailing: _NotificationBadge(),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationInboxScreen(),
              ),
            );
          },
        ),
        SectionCard(
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
        SectionCard(
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

        SectionCard(
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
        SectionCard(
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
        FilledButton(
          onPressed: () {
            Haptics.heavy();
            ref.read(authControllerProvider).signOut();
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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final unreadAsync = ref.watch(NotificationService.unreadCountProvider);
    return unreadAsync.when(
      data: (count) => count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
