import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/cache/preload_controller.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/account_menu_button.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import '../../../shared/widgets/role_header.dart';
import '../../../shared/widgets/sync_status_badge.dart';
import 'client_dashboard_screen.dart';
import 'client_guards_screen.dart';
import 'client_attendance_screen.dart';
import 'client_more_screen.dart';

class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key});

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  static const List<_ClientTab> _tabs = <_ClientTab>[
    _ClientTab(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      screen: ClientDashboardScreen(),
    ),
    _ClientTab(
      label: 'Guards',
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      screen: ClientGuardsScreen(),
    ),
    _ClientTab(
      label: 'Activity',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      screen: ClientAttendanceScreen(),
    ),
    _ClientTab(
      label: 'More',
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz_rounded,
      screen: ClientMoreScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preloadControllerProvider).preloadAllClient();
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(clientTabIndexProvider);
    final tokens = CissThemeTokens.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? shouldExit = await showDialog<bool>(
          context: context,
          builder:
              (BuildContext ctx) => AlertDialog(
                title: const Text('Exit CISS Client Portal?'),
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
                name: session?.clientName ?? session?.displayName ?? 'Client',
                role: 'Client portal',
                icon: Icons.business_rounded,
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[SyncStatusBadge(), AccountMenuButton()],
                ),
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
        bottomNavigationBar: BrandedNavigationBar(
          selectedIndex: index,
          onSelected: (int i) {
            Haptics.selection();
            ref.read(clientTabIndexProvider.notifier).state = i;
          },
          items:
              _tabs
                  .map(
                    (_ClientTab tab) => BrandedNavigationItem(
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

class _ClientTab {
  const _ClientTab({
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
