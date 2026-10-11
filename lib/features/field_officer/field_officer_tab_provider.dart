import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the selected top-level menu in [FieldOfficerShell].
/// Dashboard quick-action buttons and notifications write to this provider.
final fieldOfficerTabIndexProvider = StateProvider<int>((ref) => 0);
