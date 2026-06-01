import 'package:flutter/services.dart';

/// Lightweight haptic feedback utility for tactile interactions.
///
/// Usage:
/// ```dart
/// Haptics.light();    // button taps
/// Haptics.medium();   // successful actions (submit, save)
/// Haptics.heavy();    // significant events (clock-in, clock-out)
/// Haptics.selection(); // picker changes, tab switches
/// ```
class Haptics {
  const Haptics._();

  /// Light tap — button presses, list item taps.
  static void light() => HapticFeedback.lightImpact();

  /// Medium tap — successful submissions, toggles.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy tap — clock-in/out, major state changes.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection click — dropdown changes, tab switches, segment toggles.
  static void selection() => HapticFeedback.selectionClick();
}
