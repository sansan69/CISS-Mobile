import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Branded dropdown selector with consistent styling.
class ModernDropdown<T> extends StatelessWidget {
  const ModernDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: tokens.inkMuted)
            : null,
        filled: true,
        fillColor: enabled ? tokens.surfaceStrong : tokens.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: tokens.primary, width: 2),
        ),
      ),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: tokens.ink,
      ),
      dropdownColor: tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      icon: Icon(Icons.expand_more_rounded, color: tokens.inkMuted),
    );
  }
}
