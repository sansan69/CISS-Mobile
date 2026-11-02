import 'haptic_event.dart';
import 'haptic_platform.dart';

/// Maps semantic [HapticEvent]s to platform primitives.
///
/// Pure and dependency-free so the mapping table can be unit-tested.
///
/// Mapping rationale (Android guidance: favor clear over buzzy; scale
/// strength to importance and frequency):
/// - selection/tick/toggle -> selection click (very frequent, must stay subtle)
/// - light/medium/heavy    -> the matching impact
/// - confirm               -> medium (a short, satisfying confirmation)
/// - reject/warning        -> heavy (clearly signals failure/caution)
/// - vibrate               -> the raw vibrator, for attention events only
class HapticsEngine {
  const HapticsEngine(this.platform);

  final HapticPlatform platform;

  Future<void> emit(HapticEvent event) {
    switch (event) {
      case HapticEvent.selection:
      case HapticEvent.tick:
      case HapticEvent.toggle:
        return platform.selectionClick();
      case HapticEvent.light:
        return platform.lightImpact();
      case HapticEvent.medium:
      case HapticEvent.confirm:
        return platform.mediumImpact();
      case HapticEvent.heavy:
      case HapticEvent.reject:
      case HapticEvent.warning:
        return platform.heavyImpact();
      case HapticEvent.vibrate:
        return platform.vibrate();
    }
  }
}
