import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../guard_tab_provider.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import 'screens/guard_attendance_screen.dart';
import 'screens/guard_dashboard_screen.dart';
import 'screens/guard_evaluations_screen.dart';
import 'screens/guard_incidents_screen.dart';
import 'screens/guard_leave_screen.dart';
import 'screens/guard_payslips_screen.dart';
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
  Widget build(BuildContext context) {
    final index = ref.watch(guardTabIndexProvider);
    return Scaffold(
      body: _tabs[index].screen,
      bottomNavigationBar: BrandedNavigationBar(
        selectedIndex: index,
        onSelected: (int i) =>
            ref.read(guardTabIndexProvider.notifier).state = i,
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
      subtitle: 'Profile, leave, incident, and support actions',
      children: <Widget>[
const ThemeModeSelector(),
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
          title: 'Leave',
          subtitle: 'Apply and review leave requests',
          icon: Icons.event_available_rounded,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuardLeaveScreen()),
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
          onPressed: () => ref.read(authControllerProvider).signOut(),
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
