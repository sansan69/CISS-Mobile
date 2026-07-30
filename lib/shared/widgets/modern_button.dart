import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Branded button with three variants: filled, tonal, and outlined.
///
/// Matches the CISS Material 3 design system with rounded corners,
/// consistent sizing, and proper token-based colors.
class ModernButton extends StatelessWidget {
  const ModernButton._({
    super.key,
    required this.child,
    required this.onPressed,
    required this.height,
    required this.minWidth,
    required this.borderRadius,
    this.style,
  });

  /// Primary filled action button.
  factory ModernButton.filled({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    double height = 52,
    double minWidth = double.infinity,
    double borderRadius = 12,
  }) {
    return ModernButton._(
      key: key,
      onPressed: onPressed,
      height: height,
      minWidth: minWidth,
      borderRadius: borderRadius,
      style: null, // uses theme default FilledButton
      child: _buildContent(label, icon),
    );
  }

  /// Tonal/secondary action button.
  factory ModernButton.tonal({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    double height = 52,
    double minWidth = double.infinity,
    double borderRadius = 12,
  }) {
    return ModernButton._(
      key: key,
      onPressed: onPressed,
      height: height,
      minWidth: minWidth,
      borderRadius: borderRadius,
      child: _buildContent(label, icon),
    );
  }

  /// Outlined action button.
  factory ModernButton.outlined({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    Color? foregroundColor,
    Color? borderColor,
    double height = 52,
    double minWidth = double.infinity,
    double borderRadius = 12,
  }) {
    return ModernButton._(
      key: key,
      onPressed: onPressed,
      height: height,
      minWidth: minWidth,
      borderRadius: borderRadius,
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor ?? foregroundColor ?? const Color(0xFFAFC0CD)),
      ),
      child: _buildContent(label, icon),
    );
  }

  final Widget child;
  final VoidCallback? onPressed;
  final double height;
  final double minWidth;
  final double borderRadius;
  final ButtonStyle? style;

  static Widget _buildContent(String label, IconData? icon) {
    if (icon == null) {
      return Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    // Default tonal style for unnamed factory
    final effectiveStyle = style ??
        FilledButton.styleFrom(
          backgroundColor: tokens.primarySoft,
          foregroundColor: tokens.primaryStrong,
          minimumSize: Size(minWidth, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        );

    return SizedBox(
      width: minWidth,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: effectiveStyle,
        child: child,
      ),
    );
  }
}
