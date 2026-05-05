import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the selected tab in [GuardShell].
/// Dashboard quick-action buttons write to this provider to navigate tabs.
final guardTabIndexProvider = StateProvider<int>((ref) => 0);
