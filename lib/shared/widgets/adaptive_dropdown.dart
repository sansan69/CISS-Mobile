import 'package:flutter/material.dart';

/// Text-scale-safe dropdown field for duty and willingness forms.
///
/// `DropdownButtonFormField` defaults to `isDense: true`. Flutter clamps the
/// dense collapsed button to `max(scaledFontSize, 24)`, while the selected
/// value is painted with this theme's line height (`1.5x`). From any text
/// scale above 1.0 the line box is taller than the button, so the decoration
/// reserves the shorter height and the selected value is clipped vertically
/// (reported by device QA at 1.8 text scale in the assignment editor).
///
/// Opting out of the dense height lets the field size itself from the
/// intrinsic line height, which matches the original layout at 1.0 text scale
/// and keeps large text readable.
class AdaptiveDropdownFormField<T> extends StatelessWidget {
  const AdaptiveDropdownFormField({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    this.validator,
    this.onChanged,
  });

  final T? value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final FormFieldValidator<T>? validator;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    isDense: false,
    isExpanded: true,
    itemHeight: null,
    decoration: InputDecoration(labelText: label),
    items: items,
    validator: validator,
    onChanged: onChanged,
  );
}
