import 'package:flutter/services.dart';

/// Provides standard haptic feedback patterns across the app.
///
/// Usage:
/// ```dart
/// Haptics.light();   // subtle feedback (button press, selection)
/// Haptics.medium();  // moderate feedback (navigation, confirmation)
/// Haptics.heavy();   // strong feedback (sign out, critical action)
/// ```
class Haptics {
  Haptics._();

  /// Subtle tap — use for button presses, chip selection, tab switches.
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Moderate tap — use for navigation, pull-to-refresh, form submission.
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Strong tap — use for destructive actions, sign out, critical confirmations.
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Click selection — use for segmented control changes, toggle switches.
  static void selection() {
    HapticFeedback.selectionClick();
  }
}
