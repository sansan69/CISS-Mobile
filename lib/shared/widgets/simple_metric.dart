import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class SimpleMetric extends StatelessWidget {
  const SimpleMetric({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.inkMuted,
          ),
        ),
      ],
    );
  }
}
