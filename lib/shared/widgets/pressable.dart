import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../core/haptics.dart';
import '../../core/haptics/haptic_event.dart';

/// Wraps a tappable surface with press-in scale feedback and a single haptic.
///
/// Press feedback lands on press-*in* (never on release), runs for
/// [AppMotion.press], and fires exactly one [Haptics] event per tap. This is
/// the one press behaviour every interactive card/row/button should share.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = HapticEvent.light,
    this.pressedScale = 0.97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Haptic fired once on press-in. Pass `null` to opt out (e.g. very
  /// high-frequency surfaces).
  final HapticEvent? haptic;

  /// Scale applied while pressed.
  final double pressedScale;

  /// Optional screen-reader label. When omitted, the child's text semantics
  /// are used. The surface is always exposed as a button when [onTap] is set.
  final String? semanticLabel;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleDown(TapDownDetails _) {
    _setPressed(true);
    final haptic = widget.haptic;
    if (haptic != null) Haptics.emit(haptic);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleDown,
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: reduceMotion ? Duration.zero : AppMotion.press,
          curve: AppMotion.standardCurve,
          child: widget.child,
        ),
      ),
    );
  }
}
