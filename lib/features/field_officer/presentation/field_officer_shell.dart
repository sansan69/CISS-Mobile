import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../field_officer_tab_provider.dart';
import '../../../shared/widgets/brand_banner.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/branded_navigation_bar.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../../../shared/widgets/security_settings_card.dart';
import '../../../shared/widgets/sync_status_badge.dart';
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
    final session = ref.watch(authSessionProvider).value;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          BrandBanner(
            title: 'Vault',
            subtitle: 'Secure tools and system settings',
            trailing: const SyncStatusBadge(),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREFERENCES',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: tokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                const ThemeModeSelector(),
                const SizedBox(height: 12),
                const SecuritySettingsCard(),
                
                const SizedBox(height: 32),
                Text(
                  'SYSTEM TOOLS',
                  style: GoogleFonts.rajdhani(
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
                      onTap: () {},
                    ),
                    _ToolTile(
                      icon: Icons.place_outlined,
                      label: 'Sites',
                      color: tokens.primary,
                      onTap: () {},
                    ),
                    _ToolTile(
                      icon: Icons.sync_rounded,
                      label: 'Sync Logs',
                      color: tokens.success,
                      onTap: () {},
                    ),
                    _ToolTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Support',
                      color: tokens.accent,
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 40),
                GlassCard(
                  accentColor: tokens.danger,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: tokens.primarySoft,
                            child: const Icon(Icons.person_outline_rounded, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session?.displayName.toUpperCase() ?? 'OFFICER',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.ink,
                                  ),
                                ),
                                Text(
                                  session?.email ?? 'active session',
                                  style: Theme.of(context).textTheme.labelSmall,
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
                          onPressed: () => ref.read(authControllerProvider).signOut(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.danger,
                            side: BorderSide(color: tokens.danger.withValues(alpha: 0.5)),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(
                            'TERMINATE SESSION',
                            style: GoogleFonts.rajdhani(fontWeight: FontWeight.w800, letterSpacing: 1),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          accentColor: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.rajdhani(
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
