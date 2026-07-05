import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/account_menu_button.dart';
import '../../../shared/widgets/role_header.dart';
import 'admin_dashboard_screen.dart';
import 'admin_guards_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_more_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  static const List<_AdminTab> _tabs = <_AdminTab>[
    _AdminTab(
      label: 'Home',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      screen: AdminDashboardScreen(),
    ),
    _AdminTab(
      label: 'Workforce',
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      screen: AdminGuardsScreen(),
    ),
    _AdminTab(
      label: 'Operations',
      icon: Icons.assignment_turned_in_outlined,
      activeIcon: Icons.assignment_turned_in_rounded,
      screen: AdminOrdersScreen(),
    ),
    _AdminTab(
      label: 'More',
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz_rounded,
      screen: AdminMoreScreen(),
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
          builder:
              (BuildContext ctx) => AlertDialog(
                title: const Text('Exit CISS Admin?'),
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
        backgroundColor: tokens.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              RoleHeader(
                name: session?.displayName ?? 'Admin',
                role: 'Admin portal',
                icon: Icons.admin_panel_settings_rounded,
                trailing: const AccountMenuButton(),
              ),
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: _tabs.map((t) => t.screen).toList(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildNavBar(tokens, index),
      ),
    );
  }

  Widget _buildNavBar(CissThemeTokens tokens, int selectedIndex) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 6),
        child: SizedBox(
          height: 64,
          child: Row(
            children: _tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final tab = entry.value;
              final isActive = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    Haptics.selection();
                    ref.read(adminTabIndexProvider.notifier).state = i;
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isActive ? tokens.primarySoft : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              isActive ? tab.activeIcon : tab.icon,
                              size: 20,
                              color: isActive
                                  ? tokens.primaryStrong
                                  : tokens.inkMuted,
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 6),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.primaryStrong,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
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
