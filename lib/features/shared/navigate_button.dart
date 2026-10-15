import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/location/navigate_action.dart';

/// "Navigate" affordance for a site or duty point.
///
/// Renders nothing when the destination has no coordinates, so a row is never
/// offered a button that cannot do anything.
class NavigateAction extends ConsumerWidget {
  const NavigateAction({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
    this.compact = true,
  });

  final double? latitude;
  final double? longitude;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return const SizedBox.shrink();
    final strings = AppStrings.of(context);

    Future<void> navigate() async {
      final opened = await ref
          .read(navigationLauncherProvider)
          .open(lat, lng, label: label);
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.navigateUnavailable)));
    }

    if (!compact) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: navigate,
          icon: const Icon(Icons.navigation_rounded, size: 18),
          label: Text(strings.navigate),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      );
    }
    return Semantics(
      label: label == null ? strings.navigate : '${strings.navigate}. $label',
      button: true,
      child: ExcludeSemantics(
        child: ActionChip(
          avatar: const Icon(Icons.navigation_rounded, size: 16),
          label: Text(
            strings.navigate,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          onPressed: navigate,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
