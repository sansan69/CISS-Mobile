import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// A label-value row used in detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 120,
    this.valueColor,
  });

  final String label;
  final String value;
  final double labelWidth;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                color: tokens.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
