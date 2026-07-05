import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/cache/preload_controller.dart';
import '../../../core/haptics.dart';
import '../../auth/application/auth_controller.dart';
import '../field_officer_tab_provider.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../../../shared/widgets/security_settings_card.dart';
import '../../../shared/widgets/sync_status_badge.dart';
import '../../../core/fcm/notification_service.dart';
import '../../shared/notification_inbox_screen.dart';
import 'screens/field_officer_attendance_screen.dart';
import 'screens/field_officer_dashboard_screen.dart';
import 'screens/field_officer_guards_screen.dart';
import 'screens/field_officer_reports_screen.dart';
import 'screens/field_officer_work_orders_screen.dart';
import 'screens/field_officer_tools_screens.dart';

class FieldOfficerShell extends ConsumerStatefulWidget {
  const FieldOfficerShell({super.key});

  @override
  ConsumerState<FieldOfficerShell> createState() => _FieldOfficerShellState();
}

class _FieldOfficerShellState extends ConsumerState<FieldOfficerShell> {
  static const List<_FieldOfficerTab> _tabs = <_FieldOfficerTab>[
    _FieldOfficerTab(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      screen: FieldOfficerDashboardScreen(),
    ),
    _FieldOfficerTab(
      label: 'Duties',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      screen: _FieldOfficerDutiesHolder(),
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
  void initState() {
    super.initState();
    // Preload ALL field officer data eagerly after login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preloadControllerProvider).preloadAllFieldOfficer();
    });
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
                    ref.read(fieldOfficerTabIndexProvider.notifier).state = i;
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

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(fieldOfficerTabIndexProvider);

    // Keep all FO data providers alive so tab switching is instant.
    ref.watch(fieldOfficerDashboardProvider);
    ref.watch(fieldOfficerVisitReportsProvider);
    ref.watch(fieldOfficerTrainingReportsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? shouldExit = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Exit CISS Workforce?'),
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
          child: IndexedStack(
          index: index,
          children: _tabs.map((t) => t.screen).toList(),
        ),
        ),
        bottomNavigationBar: _buildPillNav(context, index, ref),
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

class _FieldOfficerDutiesHolder extends ConsumerWidget {
  const _FieldOfficerDutiesHolder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final index = ref.watch(fieldOfficerDutiesSubIndexProvider);

    // Keep duties sub-tab providers alive
    ref.watch(fieldOfficerWorkOrdersProvider);
    ref.watch(fieldOfficerGuardsProvider);
    ref.watch(fieldOfficerGuardAttendanceProvider);

    return Column(
      children: <Widget>[
        Container(
          color: tokens.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: <Widget>[
              _DutiesSubTab(
                label: 'Order',
                isSelected: index == 0,
                onTap: () =>
                    ref.read(fieldOfficerDutiesSubIndexProvider.notifier).state =
                        0,
              ),
              const SizedBox(width: 8),
              _DutiesSubTab(
                label: 'Guard',
                isSelected: index == 1,
                onTap: () =>
                    ref.read(fieldOfficerDutiesSubIndexProvider.notifier).state =
                        1,
              ),
              const SizedBox(width: 8),
              _DutiesSubTab(
                label: 'Attendance',
                isSelected: index == 2,
                onTap: () =>
                    ref.read(fieldOfficerDutiesSubIndexProvider.notifier).state =
                        2,
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          color: tokens.border,
        ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: const <Widget>[
              FieldOfficerWorkOrdersScreen(),
              FieldOfficerGuardsScreen(),
              FieldOfficerGuardAttendanceScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DutiesSubTab extends StatelessWidget {
  const _DutiesSubTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tokens.primary : tokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isSelected ? Colors.white : tokens.inkMuted,
          ),
        ),
      ),
    );
  }
}

class FieldOfficerMoreScreen extends ConsumerWidget {
  const FieldOfficerMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final session = ref.watch(authSessionProvider).value;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          ModernHero(
            eyebrow: 'Vault',
            title: 'Settings & Tools',
            subtitle: 'Secure system preferences and tools',
            trailing: const SyncStatusBadge(),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREFERENCES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                const ThemeModeSelector(),
                const SizedBox(height: 12),
                _NotificationTile(),
                const SizedBox(height: 12),
                const SecuritySettingsCard(),

                const SizedBox(height: 32),
                Text(
                  'SYSTEM TOOLS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _ToolTile(
                      icon: Icons.assignment_late_outlined,
                      label: 'Incidents',
                      color: tokens.warning,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FieldOfficerIncidentsScreen()),
                        );
                      },
                    ),
                    _ToolTile(
                      icon: Icons.place_outlined,
                      label: 'Sites',
                      color: tokens.primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FieldOfficerSitesScreen()),
                        );
                      },
                    ),
                    _ToolTile(
                      icon: Icons.sync_rounded,
                      label: 'Sync Logs',
                      color: tokens.success,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FieldOfficerSyncLogsScreen()),
                        );
                      },
                    ),
                    _ToolTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Support',
                      color: tokens.accent,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FieldOfficerSupportScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),
          ModernCard(
                  borderColor: tokens.danger.withValues(alpha: 0.3),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: tokens.primarySoft,
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session?.displayName.toUpperCase() ??
                                      'OFFICER',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.ink,
                                  ),
                                ),
                                Text(
                                  session?.email ?? 'active session',
                                  style:
                                      Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: tokens.inkMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Haptics.heavy();
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Sign out?'),
                                content: const Text('You will be signed out of your account.'),
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.danger,
                            side: BorderSide(
                              color: tokens.danger.withValues(alpha: 0.5),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(
                            'TERMINATE SESSION',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final unreadAsync = ref.watch(NotificationService.unreadCountProvider);
    final count = unreadAsync.valueOrNull ?? 0;

    return ModernCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.notifications_outlined, color: tokens.primary),
        title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(count > 0 ? '$count unread' : 'No new alerts'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationInboxScreen()),
          );
        },
      ),
    );
  }
}
