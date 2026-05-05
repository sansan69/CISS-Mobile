import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the selected tab in [FieldOfficerShell].
/// Dashboard quick-action buttons write to this provider to navigate tabs.
final fieldOfficerTabIndexProvider = StateProvider<int>((ref) => 0);
