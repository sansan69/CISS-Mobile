import 'package:flutter/material.dart';

/// One motion vocabulary for the whole app.
///
/// Every duration, curve and offset used by navigation and press feedback
/// lives here so motion stays consistent and auditable in one place.
/// Purpose-first: only add a token when a named purpose needs it.
abstract final class AppMotion {
  /// Route enter duration. A standard, occasional transition.
  static const Duration routeIn = Duration(milliseconds: 240);

  /// Route exit duration. Exits are faster than entrances.
  static const Duration routeOut = Duration(milliseconds: 180);

  /// Press feedback duration (press-in scale/highlight).
  static const Duration press = Duration(milliseconds: 120);

  /// Strong ease-out for entrances. Built-in curves are too weak.
  static const Curve standardCurve = Cubic(0.23, 1, 0.32, 1);

  /// Exit curve for departures.
  static const Curve exitCurve = Curves.easeIn;

  /// How far a pushed route slides in from the right.
  static const Offset routeSlideBegin = Offset(0.06, 0);
}
