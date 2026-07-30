import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Branded text input with filled background, rounded corners, and consistent
/// styling matching the CISS Material 3 theme.
class ModernInput extends StatelessWidget {
  const ModernInput({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines: maxLines,
      enabled: enabled,
      autofocus: autofocus,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: enabled ? tokens.ink : tokens.inkMuted,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: tokens.inkMuted)
            : null,
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: tokens.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: tokens.inkMuted,
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          color: tokens.inkMuted.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
