import 'package:flutter/services.dart';

/// Thin, injectable boundary over the platform haptics motor.
///
/// Keeping this behind an interface lets the mapping be unit-tested with a
/// recording fake instead of a real device.
abstract interface class HapticPlatform {
  Future<void> lightImpact();
  Future<void> mediumImpact();
  Future<void> heavyImpact();
  Future<void> selectionClick();
  Future<void> vibrate();
}

/// Real implementation backed by [HapticFeedback].
///
/// Works on Android and iOS. On platforms without a haptics motor the
/// underlying channel calls are safe no-ops.
class FlutterHapticPlatform implements HapticPlatform {
  const FlutterHapticPlatform();

  @override
  Future<void> lightImpact() => HapticFeedback.lightImpact();

  @override
  Future<void> mediumImpact() => HapticFeedback.mediumImpact();

  @override
  Future<void> heavyImpact() => HapticFeedback.heavyImpact();

  @override
  Future<void> selectionClick() => HapticFeedback.selectionClick();

  @override
  Future<void> vibrate() => HapticFeedback.vibrate();
}
