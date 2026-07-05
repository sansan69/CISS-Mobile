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

/// Brand-aware bottom navigation used across all role shells.
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 6),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tokens.primaryStrong,
                  height: 1.0,
                  letterSpacing: 0,
                );
              }
              return TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tokens.inkMuted,
                height: 1.0,
                letterSpacing: 0,
              );
            }),
            indicatorShape: const StadiumBorder(),
            indicatorColor: tokens.primarySoft,
            backgroundColor: tokens.surface,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            animationDuration: const Duration(milliseconds: 180),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations:
                items
                    .map(
                      (BrandedNavigationItem item) => NavigationDestination(
                        icon: Icon(item.icon, size: 20, color: tokens.inkMuted),
                        selectedIcon: Icon(
                          item.activeIcon,
                          size: 20,
                          color: tokens.primaryStrong,
                        ),
                        label: item.label,
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }
}
