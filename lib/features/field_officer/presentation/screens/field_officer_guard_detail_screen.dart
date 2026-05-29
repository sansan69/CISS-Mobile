import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/location/live_location_service.dart';

class FieldOfficerGuardDetailScreen extends StatefulWidget {
  const FieldOfficerGuardDetailScreen({
    super.key,
    required this.employeeId,
    required this.guardName,
    required this.siteName,
  });

  final String employeeId;
  final String guardName;
  final String siteName;

  @override
  State<FieldOfficerGuardDetailScreen> createState() =>
      _FieldOfficerGuardDetailScreenState();
}

class _FieldOfficerGuardDetailScreenState
    extends State<FieldOfficerGuardDetailScreen> {
  StreamSubscription<GuardLocationData?>? _sub;
  GuardLocationData? _location;
  bool _followGuard = true;
  final MapController _mapController = MapController();
  bool _hasPendingPosition = false;
  bool _tilesFailed = false;

  @override
  void initState() {
    super.initState();
    _sub = LiveLocationService()
        .streamGuardLocation(widget.employeeId)
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _location = data;
        if (_followGuard && data != null && data.lat != 0 && data.lng != 0) {
          _hasPendingPosition = true;
        }
      });
    });

    // Defer map animation to first post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToGuard());
  }

  void _animateToGuard() {
    final loc = _location;
    if (loc == null || loc.lat == 0 || loc.lng == 0) return;
    _mapController.move(LatLng(loc.lat, loc.lng), 17);
  }

  @override
  void didUpdateWidget(FieldOfficerGuardDetailScreen old) {
    super.didUpdateWidget(old);
    if (_hasPendingPosition) {
      _hasPendingPosition = false;
      _animateToGuard();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final loc = _location;

    final isActive = loc != null && loc.status == 'In';
    final guardLat = loc?.lat ?? 0;
    final guardLng = loc?.lng ?? 0;
    final hasCoords = guardLat != 0 && guardLng != 0;
    final siteLat = loc?.siteLat;
    final siteLng = loc?.siteLng;
    final radius = loc?.geofenceRadius ?? 0;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: Text(
          widget.guardName,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: tokens.canvas,
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 3,
            child: ClipRRect(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: hasCoords
                      ? LatLng(guardLat, guardLng)
                      : const LatLng(10.0, 76.0),
                  initialZoom: 17,
                  onMapEvent: (event) {
                    if (event is MapEventMoveStart ||
                        event is MapEventFlingAnimation) {
                      setState(() => _followGuard = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ciss.mobile',
                    errorTileCallback: (tile, error, stackTrace) {
                      if (!_tilesFailed) {
                        setState(() => _tilesFailed = true);
                      }
                    },
                  ),
                  // Guard marker
                  if (hasCoords)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(guardLat, guardLng),
                          width: 60,
                          height: 60,
                          child: _GuardMarker(isOutOfZone: loc?.isOutOfZone ?? false),
                        ),
                      ],
                    ),
                  // Site geofence circle
                  if (siteLat != null && siteLng != null && radius > 0)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(siteLat, siteLng),
                          radius: radius,
                          color: tokens.primary.withValues(alpha: 0.08),
                          borderColor: tokens.primary.withValues(alpha: 0.35),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  // Accuracy ring
                  if (hasCoords && (loc?.accuracy ?? 0) > 0)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(guardLat, guardLng),
                          radius: loc!.accuracy,
                          color: (loc.isOutOfZone ? tokens.danger : tokens.success)
                              .withValues(alpha: 0.06),
                          borderColor: (loc.isOutOfZone ? tokens.danger : tokens.success)
                              .withValues(alpha: 0.25),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Tile error banner
          if (_tilesFailed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: tokens.warningSoft,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: tokens.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Map tiles unavailable. Guard location still visible.',
                      style: TextStyle(fontSize: 12, color: tokens.warning),
                    ),
                  ),
                ],
              ),
            ),

          // Info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.guardName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? tokens.successSoft
                            : tokens.dangerSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? tokens.success : tokens.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'ON DUTY' : 'OFF DUTY',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: isActive ? tokens.success : tokens.danger,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _infoRow(tokens, 'Site', widget.siteName),
                if (loc != null) ...[
                  _infoRow(tokens, 'Status', loc.status),
                  _infoRow(
                    tokens,
                    'Last update',
                    _formatSince(loc.updatedAt),
                  ),
                  if (hasCoords && siteLat != null && siteLng != null) ...[
                    _infoRow(
                      tokens,
                      'Distance from site',
                      '${_calculateDistance(
                            guardLat,
                            guardLng,
                            siteLat,
                            siteLng,
                          ).toStringAsFixed(0)} m',
                    ),
                  ],
                  _infoRow(
                    tokens,
                    'In zone',
                    loc.isOutOfZone ? '✗ OUTSIDE' : '✓ Inside',
                  ),
                ] else
                  _infoRow(tokens, 'Status', 'No location data'),
              ],
            ),
          ),

          // Recenter button
          if (!_followGuard && hasCoords)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _followGuard = true);
                    _animateToGuard();
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    'RECENTER ON GUARD',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(CissThemeTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: tokens.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000; // Earth radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _GuardMarker extends StatelessWidget {
  const _GuardMarker({required this.isOutOfZone});
  final bool isOutOfZone;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = isOutOfZone ? tokens.danger : tokens.success;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 14),
        ),
        Container(
          width: 2,
          height: 10,
          color: color.withValues(alpha: 0.6),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 20),
      ],
    );
  }
}
