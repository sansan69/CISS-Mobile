import 'package:flutter/material.dart';

/// App-wide scroll behavior that applies BouncingScrollPhysics on all
/// platforms for a smooth, native-feeling scroll experience.
class CissScrollBehavior extends ScrollBehavior {
  const CissScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
