import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reading of "now" the attendance surfaces group shifts by.
///
/// Whether an overnight shift is still on duty or has become a missed
/// check-out depends on the current moment, so screens take their clock from
/// here and tests pin it to a fixed instant instead of racing the wall clock.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
