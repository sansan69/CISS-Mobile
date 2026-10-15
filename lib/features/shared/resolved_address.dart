import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/address_cache.dart';

/// Shows the street address for a pair of coordinates.
///
/// Renders nothing while the lookup is pending and nothing when it fails, so a
/// guard who is offline sees the coordinates the screen already printed instead
/// of an error about an address they never asked for.
class ResolvedAddressLine extends ConsumerStatefulWidget {
  const ResolvedAddressLine({
    super.key,
    required this.latitude,
    required this.longitude,
    this.style,
    this.prefix,
    this.maxLines = 2,
  });

  final double? latitude;
  final double? longitude;
  final TextStyle? style;
  final String? prefix;
  final int maxLines;

  @override
  ConsumerState<ResolvedAddressLine> createState() =>
      _ResolvedAddressLineState();
}

class _ResolvedAddressLineState extends ConsumerState<ResolvedAddressLine> {
  String? _address;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ResolvedAddressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _address = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (_resolving) return;
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    if (latitude == null || longitude == null) return;
    _resolving = true;
    try {
      final address = await ref
          .read(addressResolverProvider)
          .forCoordinates(latitude, longitude);
      if (!mounted) return;
      setState(() => _address = address);
    } catch (error) {
      // Nothing to show is a valid outcome; an address is never worth an
      // unhandled async error on a punch card.
      debugPrint('Address lookup failed for $latitude,$longitude: $error');
    } finally {
      _resolving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = _address;
    if (address == null || address.isEmpty) return const SizedBox.shrink();
    return Text(
      widget.prefix == null ? address : '${widget.prefix} $address',
      style: widget.style ?? Theme.of(context).textTheme.bodySmall,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
