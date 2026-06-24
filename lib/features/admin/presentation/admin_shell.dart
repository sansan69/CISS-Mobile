import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import 'admin_dashboard_screen.dart';
import 'admin_guards_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_orders_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  static const List<_AdminTab> _tabs = <_AdminTab>[
    _AdminTab(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      screen: AdminDashboardScreen(),
    ),
    _AdminTab(
      label: 'Guards',
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      screen: AdminGuardsScreen(),
    ),
    _AdminTab(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      screen: AdminAttendanceScreen(),
    ),
    _AdminTab(
      label: 'Orders',
      icon: Icons.assignment_turned_in_outlined,
      activeIcon: Icons.assignment_turned_in_rounded,
      screen: AdminOrdersScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(adminTabIndexProvider);
    final tokens = CissThemeTokens.of(context);
    final session = ref.watch(authSessionProvider).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? shouldExit = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Exit CISS Admin?'),
            content: const Text(
              'Are you sure you want to close the app?',
            ),
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
        backgroundColor: tokens.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // Header with admin name
              _AdminHeader(
                adminName:
                    session?.displayName ?? 'Admin',
                tokens: tokens,
              ),
              // Indexed stack for tab content
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: _tabs.map((t) => t.screen).toList(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BrandedNavigationBar(
          selectedIndex: index,
          onSelected: (int i) {
            Haptics.selection();
            ref.read(adminTabIndexProvider.notifier).state = i;
          },
          items: _tabs
              .map(
                (_AdminTab tab) => BrandedNavigationItem(
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

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.adminName,
    required this.tokens,
  });

  final String adminName;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(color: tokens.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Color(0xFF1A56DB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  adminName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Admin Portal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.inkMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTab {
  const _AdminTab({
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
