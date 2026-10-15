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
/// adapter ignores unavailable or failed platform channels. Each event keeps
/// its Flutter impact/selection mapping; it never falls back to vibration.
class FlutterHapticPlatform implements HapticPlatform {
  const FlutterHapticPlatform();

  Future<void> _dispatch(Future<void> Function() feedback) async {
    try {
      await feedback();
    } on MissingPluginException {
      // No platform implementation (desktop, web, or an unavailable plugin).
    } on PlatformException {
      // Feedback is optional: a motor/channel failure must not break the UI.
    }
  }

  @override
  Future<void> lightImpact() => _dispatch(HapticFeedback.lightImpact);

  @override
  Future<void> mediumImpact() => _dispatch(HapticFeedback.mediumImpact);

  @override
  Future<void> heavyImpact() => _dispatch(HapticFeedback.heavyImpact);

  @override
  Future<void> selectionClick() => _dispatch(HapticFeedback.selectionClick);

  @override
  Future<void> vibrate() => _dispatch(HapticFeedback.vibrate);
}
