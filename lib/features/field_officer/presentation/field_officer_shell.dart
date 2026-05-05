import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../field_officer_tab_provider.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import '../../../shared/widgets/screen_scaffold.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../../../shared/widgets/security_settings_card.dart';
import 'screens/field_officer_attendance_screen.dart';
import 'screens/field_officer_dashboard_screen.dart';
import 'screens/field_officer_guards_screen.dart';
import 'screens/field_officer_reports_screen.dart';
import 'screens/field_officer_work_orders_screen.dart';

class FieldOfficerShell extends ConsumerStatefulWidget {
  const FieldOfficerShell({super.key});

  @override
  ConsumerState<FieldOfficerShell> createState() => _FieldOfficerShellState();
}

class _FieldOfficerShellState extends ConsumerState<FieldOfficerShell> {
  static const List<_FieldOfficerTab> _tabs = <_FieldOfficerTab>[
    _FieldOfficerTab(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      screen: FieldOfficerDashboardScreen(),
    ),
    _FieldOfficerTab(
      label: 'Orders',
      icon: Icons.assignment_turned_in_outlined,
      activeIcon: Icons.assignment_turned_in_rounded,
      screen: FieldOfficerWorkOrdersScreen(),
    ),
    _FieldOfficerTab(
      label: 'Guards',
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      screen: FieldOfficerGuardsScreen(),
    ),
    _FieldOfficerTab(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      screen: FieldOfficerGuardAttendanceScreen(),
    ),
    _FieldOfficerTab(
      label: 'Reports',
      icon: Icons.edit_note_outlined,
      activeIcon: Icons.edit_note_rounded,
      screen: FieldOfficerReportsScreen(),
    ),
    _FieldOfficerTab(
      label: 'More',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      screen: FieldOfficerMoreScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(fieldOfficerTabIndexProvider);
    return Scaffold(
      body: _tabs[index].screen,
      bottomNavigationBar: BrandedNavigationBar(
        selectedIndex: index,
        onSelected: (int i) =>
            ref.read(fieldOfficerTabIndexProvider.notifier).state = i,
        items: _tabs
            .map(
              (_FieldOfficerTab tab) => BrandedNavigationItem(
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

class _FieldOfficerTab {
  const _FieldOfficerTab({
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

class FieldOfficerMoreScreen extends ConsumerWidget {
  const FieldOfficerMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    return ScreenScaffold(
      title: 'More tools',
      subtitle: 'Support, reference, and session actions',
      children: <Widget>[
        const ThemeModeSelector(),
        const SecuritySettingsCard(),
        const SectionCard(
          title: 'Incident feed',
          subtitle: 'Review field incidents and escalations',
          icon: Icons.assignment_late_outlined,
        ),
        const SectionCard(
          title: 'Sites',
          subtitle: 'District sites and duty coverage',
          icon: Icons.place_outlined,
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
