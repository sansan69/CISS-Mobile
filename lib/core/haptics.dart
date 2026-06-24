import 'dart:io' show Platform;

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

  /// Guards haptic calls to only execute on Android, since iOS uses a
  /// different haptic API (via Cupertino) and calling `HapticFeedback` on
  /// iOS is a no-op — but this check keeps intent explicit.
  static bool get _isAndroid => Platform.isAndroid;

  // ── Core impact levels ─────────────────────────────────────────────────

  /// Subtle tap — use for button presses, chip selection, tab switches.
  static void light() {
    if (!_isAndroid) return;
    HapticFeedback.lightImpact();
  }

  /// Moderate tap — use for navigation, pull-to-refresh, form submission.
  static void medium() {
    if (!_isAndroid) return;
    HapticFeedback.mediumImpact();
  }

  /// Strong tap — use for destructive actions, sign out, critical confirmations.
  static void heavy() {
    if (!_isAndroid) return;
    HapticFeedback.heavyImpact();
  }

  /// Click selection — use for segmented control changes, toggle switches.
  static void selection() {
    if (!_isAndroid) return;
    HapticFeedback.selectionClick();
  }

  // ── Semantic aliases ───────────────────────────────────────────────────

  /// Heavy impact for successful operations (e.g. login, QR scan, form submit).
  static void success() {
    heavy();
  }

  /// Heavy impact for error states (e.g. failed login, validation error).
  static void error() {
    heavy();
  }

  /// Heavy impact for long-press / context-menu activation.
  static void longPress() {
    heavy();
  }

  /// Selection click for swipe gestures (e.g. edge-swipe back).
  static void swipe() {
    selection();
  }

  /// Light impact for virtual keyboard key-presses.
  static void keyboardTap() {
    light();
  }
}
