import 'package:flutter/material.dart';

import '../haptics.dart';

/// Mixin that adds swipe-back gesture support to any screen.
///
/// Detects a right-swipe drag and triggers [Navigator.pop] with haptic
/// feedback when the drag exceeds a configurable threshold.
///
/// **Usage — as a wrapper widget:**
/// ```dart
/// EdgeGestureWrapper(
///   child: YourScreen(),
/// )
/// ```
///
/// **Usage — as a mixin (for StatefulWidgets):**
/// ```dart
/// class _MyScreenState extends State<MyScreen> with EdgeGestureMixin {
///   @override
///   Widget build(BuildContext context) {
///     return buildWithEdgeGesture(
///       child: Scaffold(/* ... */),
///     );
///   }
/// }
/// ```
mixin EdgeGestureMixin<T extends StatefulWidget> on State<T> {
  /// The minimum horizontal drag distance (in logical pixels) required to
  /// trigger a back navigation.
  static const double _swipeThreshold = 80.0;

  /// Wraps [child] in a [GestureDetector] that listens for horizontal drag
  /// ends and triggers back navigation when the swipe exceeds the threshold.
  Widget buildWithEdgeGesture({required Widget child}) {
    return _EdgeGestureDetector(
      swipeThreshold: _swipeThreshold,
      child: child,
    );
  }
}

/// A standalone widget that wraps [child] with edge-swipe-back support.
///
/// Designed to work alongside [PopScope] — if the route's [PopScope]
/// intercepts the pop (e.g. shows a confirmation dialog), the dialog will
/// appear naturally and the swipe gesture won't double-pop.
class EdgeGestureWrapper extends StatelessWidget {
  const EdgeGestureWrapper({
    super.key,
    required this.child,
    this.swipeThreshold = 80.0,
    this.enabled = true,
  });

  final Widget child;
  final double swipeThreshold;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return _EdgeGestureDetector(
      swipeThreshold: swipeThreshold,
      child: child,
    );
  }
}

// ── Internal detector ────────────────────────────────────────────────────────

class _EdgeGestureDetector extends StatefulWidget {
  const _EdgeGestureDetector({
    required this.swipeThreshold,
    required this.child,
  });

  final double swipeThreshold;
  final Widget child;

  @override
  State<_EdgeGestureDetector> createState() => _EdgeGestureDetectorState();
}

class _EdgeGestureDetectorState extends State<_EdgeGestureDetector> {
  double _dragStartX = 0.0;
  bool _tracking = false;

  void _onHorizontalDragStart(DragStartDetails details) {
    // Only track swipes that start near the left edge (within 40px).
    if (details.globalPosition.dx <= 40) {
      _dragStartX = details.globalPosition.dx;
      _tracking = true;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // No-op — we only care about the end position.
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_tracking) return;
    _tracking = false;

    // Check if the swipe moved right past the threshold.
    final delta = details.globalPosition.dx - _dragStartX;
    if (delta >= widget.swipeThreshold && mounted) {
      Haptics.swipe();
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
