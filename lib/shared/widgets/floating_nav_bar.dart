import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_tokens.dart';

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount,
    this.compactLabel,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final IconData? selectedIcon;
  final int? badgeCount;
  final String? compactLabel;
  final String? semanticLabel;
}

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.allowSelectedTap = false,
    this.cornerRadius = AppRadius.pill,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;
  final bool allowSelectedTap;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final narrow = MediaQuery.sizeOf(context).width < 360 || textScale > 1.3;
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(11) * 1.4;
    final barHeight = math.max(66.0, 2 + 8 + 22 + 3 + scaledLabelHeight + 12);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: bottomInset > 0 ? bottomInset : 12,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cornerRadius),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.surfaceGlass,
                  borderRadius: BorderRadius.circular(cornerRadius),
                  border: Border.all(color: tokens.specularBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;

                    return Expanded(
                      child: Semantics(
                        container: true,
                        excludeSemantics: true,
                        selected: isSelected,
                        label: item.semanticLabel ?? item.label,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!isSelected || allowSelectedTap) {
                              HapticFeedback.lightImpact();
                              onTap(index);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 0,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? tokens.primarySoft
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      isSelected
                                          ? (item.selectedIcon ?? item.icon)
                                          : item.icon,
                                      size: 22,
                                      color:
                                          isSelected
                                              ? tokens.primary
                                              : tokens.inkMuted,
                                    ),
                                    if (item.badgeCount != null &&
                                        item.badgeCount! > 0)
                                      Positioned(
                                        top: -4,
                                        right: -8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.danger,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 14,
                                            minHeight: 14,
                                          ),
                                          child: Text(
                                            item.badgeCount! > 99
                                                ? '99+'
                                                : '${item.badgeCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  narrow && item.compactLabel != null
                                      ? item.compactLabel!
                                      : item.label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    color:
                                        isSelected
                                            ? tokens.primary
                                            : tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
