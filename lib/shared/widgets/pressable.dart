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
    this.highlightColor,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Haptic fired once on press-in. Pass `null` to opt out (e.g. very
  /// high-frequency surfaces).
  final HapticEvent? haptic;

  /// Scale applied while pressed.
  final double pressedScale;

  /// Combined accessible label; excludes decorative child semantics when set.
  final String? semanticLabel;

  /// Optional press highlight, used by rows instead of spatial feedback.
  final Color? highlightColor;

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
    if (widget.onTap == null) return;
    _setPressed(true);
    final haptic = widget.haptic;
    if (haptic != null) Haptics.emit(haptic);
  }

  void _handleSemanticTap() {
    if (widget.onTap == null) return;
    final haptic = widget.haptic;
    if (haptic != null) Haptics.emit(haptic);
    widget.onTap!();
  }

  @override
  void didUpdateWidget(covariant PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.press;
    final child =
        widget.highlightColor == null
            ? widget.child
            : Stack(
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.standardCurve,
                      color:
                          _pressed ? widget.highlightColor : Colors.transparent,
                    ),
                  ),
                ),
              ],
            );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: enabled ? _handleSemanticTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? _handleDown : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? widget.pressedScale : 1.0,
          duration: duration,
          curve: AppMotion.standardCurve,
          child: child,
        ),
      ),
    );
  }
}
