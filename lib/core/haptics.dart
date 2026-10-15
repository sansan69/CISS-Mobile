import 'haptics/haptic_event.dart';
import 'haptics/haptic_platform.dart';
import 'haptics/haptics_engine.dart';

/// Semantic haptic feedback for the app.
///
/// Prefer the intent-named methods ([selection], [confirm], [reject]) over
/// the raw impact levels ([light], [medium], [heavy]). Works on Android and
/// iOS and no-ops safely where no haptics motor is present.
///
/// ```dart
/// Haptics.selection(); // a value moved past a step
/// Haptics.confirm();   // action succeeded
/// Haptics.reject();    // action failed
/// ```
class Haptics {
  Haptics._();

  /// Swappable engine. Tests replace this with a recording platform.
  static HapticsEngine engine = const HapticsEngine(FlutterHapticPlatform());

  /// Whether haptics are enabled. Wire this to the OS/app preference so a
  /// user preference is honoured without threading it through every call.
  static bool enabled = true;

  /// Fires a semantic haptic event. No-op when [enabled] is false.
  static Future<void> emit(HapticEvent event) {
    if (!enabled) return Future<void>.value();
    return engine.emit(event);
  }

  // ── Core impact levels ────────────────────────────────────────────────

  /// Subtle tap — button presses, low-importance interactions.
  static Future<void> light() => emit(HapticEvent.light);

  /// Moderate tap — ordinary confirmations and navigation.
  static Future<void> medium() => emit(HapticEvent.medium);

  /// Strong tap — destructive actions, sign out, critical confirmations.
  static Future<void> heavy() => emit(HapticEvent.heavy);

  /// Selection click — segmented controls, toggles, step changes.
  static Future<void> selection() => emit(HapticEvent.selection);

  // ── Semantic aliases ──────────────────────────────────────────────────

  /// Successful outcome (login, QR scan, form submit).
  static Future<void> success() => emit(HapticEvent.confirm);

  /// Failed/rejected action (failed login, validation error).
  static Future<void> error() => emit(HapticEvent.reject);

  /// Long-press / context-menu activation.
  static Future<void> longPress() => emit(HapticEvent.heavy);

  /// Swipe gestures (e.g. edge-swipe back).
  static Future<void> swipe() => emit(HapticEvent.selection);

  /// Virtual keyboard key-press.
  static Future<void> keyboardTap() => emit(HapticEvent.light);

  // ── Extended vocabulary ───────────────────────────────────────────────

  /// A discrete increment tick (pickers, steppers, count-ups).
  static Future<void> tick() => emit(HapticEvent.tick);

  /// A toggle or segmented-control state change.
  static Future<void> toggle() => emit(HapticEvent.toggle);

  /// A successful outcome.
  static Future<void> confirm() => emit(HapticEvent.confirm);

  /// A failed or rejected action.
  static Future<void> reject() => emit(HapticEvent.reject);

  /// A caution that is neither success nor failure.
  static Future<void> warning() => emit(HapticEvent.warning);

  /// Attention vibration. Reserved for events that must be noticed; never
  /// for discrete UI feedback.
  static Future<void> vibrate() => emit(HapticEvent.vibrate);
}
