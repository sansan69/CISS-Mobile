import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

enum ComplianceStatus { verified, pending, rejected, missing }

class ComplianceTag extends StatelessWidget {
  const ComplianceTag({
    super.key,
    required this.label,
    required this.status,
    this.compact = false,
  });

  final String label;
  final ComplianceStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String statusText;

    switch (status) {
      case ComplianceStatus.verified:
        bgColor = tokens.successSoft;
        fgColor = tokens.success;
        icon = Icons.verified_rounded;
        statusText = 'Verified';
      case ComplianceStatus.pending:
        bgColor = tokens.warningSoft;
        fgColor = tokens.warning;
        icon = Icons.hourglass_top_rounded;
        statusText = 'Pending';
      case ComplianceStatus.rejected:
        bgColor = tokens.dangerSoft;
        fgColor = tokens.danger;
        icon = Icons.cancel_rounded;
        statusText = 'Action needed';
      case ComplianceStatus.missing:
        bgColor = tokens.surfaceMuted;
        fgColor = tokens.inkMuted;
        icon = Icons.info_outline_rounded;
        statusText = 'Missing';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: fgColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            compact ? label : '$label: $statusText',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
