import 'package:flutter/widgets.dart';

/// Tracks when a uid-scoped app lock must be shown again after the app leaves
/// the foreground. A biometric system prompt itself can briefly background the
/// app, so it must not arm a second lock while that prompt is active.
class AppLockLifecycle {
  bool _lockOnResume = false;

  void reset() => _lockOnResume = false;

  void didChangeAppLifecycleState(
    AppLifecycleState state, {
    required bool appLockEnabled,
    required bool biometricPromptActive,
  }) {
    if (!appLockEnabled || biometricPromptActive) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lockOnResume = true;
    }
  }

  bool consumeLockOnResume({
    required AppLifecycleState state,
    required bool appLockEnabled,
    required bool biometricPromptActive,
  }) {
    if (state != AppLifecycleState.resumed ||
        !appLockEnabled ||
        biometricPromptActive ||
        !_lockOnResume) {
      return false;
    }
    _lockOnResume = false;
    return true;
  }
}
