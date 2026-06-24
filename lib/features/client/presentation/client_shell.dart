import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/cache/preload_controller.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import '../../../shared/widgets/sync_status_badge.dart';
import 'client_dashboard_screen.dart';
import 'client_guards_screen.dart';
import 'client_attendance_screen.dart';
import 'client_orders_screen.dart';

class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key});

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  static const List<_ClientTab> _tabs = <_ClientTab>[
    _ClientTab(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      screen: ClientDashboardScreen(),
    ),
    _ClientTab(
      label: 'Guards',
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      screen: ClientGuardsScreen(),
    ),
    _ClientTab(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      screen: ClientAttendanceScreen(),
    ),
    _ClientTab(
      label: 'Orders',
      icon: Icons.assignment_turned_in_outlined,
      activeIcon: Icons.assignment_turned_in_rounded,
      screen: ClientOrdersScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Preload client data eagerly after login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preloadControllerProvider).preloadAllClient();
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(clientTabIndexProvider);
    final tokens = CissThemeTokens.of(context);
    final session = ref.watch(authSessionProvider).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? shouldExit = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Exit CISS Client Portal?'),
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
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // Header with client name
              _ClientHeader(
                clientName: session?.clientName ?? session?.displayName ?? 'Client',
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
            ref.read(clientTabIndexProvider.notifier).state = i;
          },
          items: _tabs
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

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({
    required this.clientName,
    required this.tokens,
  });

  final String clientName;
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
              Icons.business_rounded,
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
                  clientName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Client Portal',
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
          const SyncStatusBadge(),
        ],
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
