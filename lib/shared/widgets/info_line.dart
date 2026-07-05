import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class InfoLine extends StatelessWidget {
  const InfoLine(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 13, color: tokens.inkMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: tokens.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
