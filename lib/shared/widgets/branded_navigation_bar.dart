import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class BrandedNavigationItem {
  const BrandedNavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// M3 NavigationBar wrapper with brand-aware theming.
/// Uses compact labels and proper icon sizing for 3-6 destinations.
class BrandedNavigationBar extends StatelessWidget {
  const BrandedNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<BrandedNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: tokens.primaryStrong,
              height: 1.0,
              letterSpacing: -0.3,
            );
          }
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: tokens.inkMuted,
            height: 1.0,
            letterSpacing: -0.3,
          );
        }),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        indicatorColor: tokens.primarySoft,
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        animationDuration: const Duration(milliseconds: 200),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: items
            .map(
              (BrandedNavigationItem item) => NavigationDestination(
                icon: Icon(item.icon, size: 20, color: tokens.inkMuted),
                selectedIcon: Icon(item.activeIcon, size: 20, color: tokens.primaryStrong),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
