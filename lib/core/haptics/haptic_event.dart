/// Semantic haptics vocabulary.
///
/// Name the *meaning* of the feedback, not the motor that produces it, so
/// call sites stay stable if the underlying actuator mapping changes.
enum HapticEvent {
  /// A value moved past a step (picker, slider detent).
  selection,

  /// A discrete increment tick.
  tick,

  /// A toggle/segmented-control state change.
  toggle,

  /// Subtle feedback for low-importance presses.
  light,

  /// Moderate feedback for ordinary confirmations.
  medium,

  /// Strong feedback for high-importance or destructive actions.
  heavy,

  /// A successful outcome (login, scan, submit).
  confirm,

  /// A failed or rejected action.
  reject,

  /// A caution that is neither success nor failure.
  warning,

  /// Attention-grabbing vibration. Reserved for events that must be noticed
  /// (incoming notification/call), never for discrete UI feedback.
  vibrate,
}
