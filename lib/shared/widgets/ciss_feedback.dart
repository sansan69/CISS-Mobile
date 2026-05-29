import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Lightweight feedback utility for consistent SnackBar messaging.
///
/// Use for action confirmations, errors, and status updates throughout the app.
///
/// ```dart
/// // Success feedback
/// CissFeedback.success(context, 'Attendance marked successfully');
///
/// // Error feedback with retry
/// CissFeedback.error(context, 'Failed to sync', actionLabel: 'Retry', onAction: () => retry());
///
/// // Info/neutral feedback
/// CissFeedback.info(context, '3 items queued for offline sync');
/// ```
class CissFeedback {
  CissFeedback._();

  /// Shows a success/positive confirmation snackbar.
  static void success(BuildContext context, String message) {
    _show(context, message, Icons.check_circle_outline_rounded, null, null);
  }

  /// Shows an error snackbar with optional retry action.
  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message,
      Icons.error_outline_rounded,
      actionLabel,
      onAction,
    );
  }

  /// Shows a neutral/info snackbar.
  static void info(BuildContext context, String message) {
    _show(context, message, Icons.info_outline_rounded, null, null);
  }

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  ) {
    final tokens = CissThemeTokens.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: tokens.canvas),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: tokens.accent,
                  onPressed: onAction,
                )
              : null,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
