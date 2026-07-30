import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Consistent primary floating action button.
///
/// Wraps [FloatingActionButton.extended] with brand tokens, rounded pill shape,
/// and optional haptic feedback via [onPressed].
class ModernFab extends StatelessWidget {
  const ModernFab({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? tokens.primaryStrong,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: elevation ?? 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
