import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/location/live_location_service.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../../../shared/widgets/info_row.dart';
import '../../../../../shared/widgets/meta_chip.dart';

class FieldOfficerGuardDetailScreen extends StatefulWidget {
  const FieldOfficerGuardDetailScreen({
    super.key,
    required this.entry,
  });

  final FieldOfficerAttendanceEntry entry;

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
        .streamGuardLocation(widget.entry.employeeId)
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
    final profileImageUrl =
        (widget.entry.profilePhotoUrl != null &&
                widget.entry.profilePhotoUrl!.isNotEmpty)
            ? widget.entry.profilePhotoUrl
            : widget.entry.photoUrl;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: Text(
          widget.entry.guardName,
          style: GoogleFonts.roboto(fontWeight: FontWeight.w800, fontSize: 20),
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
                        widget.entry.guardName,
                        style: GoogleFonts.roboto(
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
                            style: GoogleFonts.roboto(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: tokens.primarySoft,
                      backgroundImage:
                          profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? NetworkImage(profileImageUrl)
                              : null,
                      child: profileImageUrl == null || profileImageUrl.isEmpty
                          ? Text(
                              widget.entry.guardName.isNotEmpty
                                  ? widget.entry.guardName
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'G',
                              style: GoogleFonts.roboto(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: tokens.primaryStrong,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.entry.employeeId.isNotEmpty)
                            MetaChip(
                              icon: Icons.badge_outlined,
                              label: widget.entry.employeeId,
                            ),
                          if (widget.entry.clientName.isNotEmpty)
                            MetaChip(
                              icon: Icons.business_outlined,
                              label: widget.entry.clientName,
                            ),
                          if (widget.entry.district.isNotEmpty)
                            MetaChip(
                              icon: Icons.place_outlined,
                              label: widget.entry.district,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                InfoRow(labelWidth: 110, label: 'Site', value: widget.entry.siteName),
                if (widget.entry.dutyPointName.isNotEmpty)
                  InfoRow(labelWidth: 110, label: 'Duty point', value: widget.entry.dutyPointName),
                if (widget.entry.shiftLabel.isNotEmpty)
                  InfoRow(labelWidth: 110, label: 'Shift', value: widget.entry.shiftLabel),
                if (widget.entry.checkIn != null)
                  InfoRow(labelWidth: 110, label: 'Check in', value: widget.entry.checkIn!),
                if (widget.entry.checkOut != null)
                  InfoRow(labelWidth: 110, label: 'Check out', value: widget.entry.checkOut!),
                if ((widget.entry.phoneNumber ?? '').trim().isNotEmpty)
                  InfoRow(labelWidth: 110, label: 'Phone', value: widget.entry.phoneNumber!.trim()),
                if ((widget.entry.gender ?? '').trim().isNotEmpty)
                  InfoRow(labelWidth: 110, label: 'Gender', value: widget.entry.gender!.trim()),
                if ((widget.entry.resourceIdNumber ?? '').trim().isNotEmpty)
                  InfoRow(
                    labelWidth: 110,
                    label: 'Resource ID',
                    value: widget.entry.resourceIdNumber!.trim(),
                  ),
                if ((widget.entry.joiningDate ?? '').trim().isNotEmpty)
                  InfoRow(
                    labelWidth: 110,
                    label: 'Joining date',
                    value: _formatDate(widget.entry.joiningDate!),
                  ),
                if ((widget.entry.address ?? '').trim().isNotEmpty)
                  InfoRow(labelWidth: 110, label: 'Address', value: widget.entry.address!.trim()),
                if (loc != null) ...[
                  InfoRow(labelWidth: 110, label: 'Status', value: loc.status),
                  InfoRow(
                    labelWidth: 110,
                    label: 'Last update',
                    value: formatTimeSince(loc.updatedAt),
                  ),
                  if (hasCoords && siteLat != null && siteLng != null) ...[
                    InfoRow(
                      labelWidth: 110,
                      label: 'Distance from site',
                      value: '${calculateDistanceMeters(
                            guardLat,
                            guardLng,
                            siteLat,
                            siteLng,
                          ).toStringAsFixed(0)} m',
                    ),
                  ],
                  InfoRow(
                    labelWidth: 110,
                    label: 'In zone',
                    value: loc.isOutOfZone ? '✗ OUTSIDE' : '✓ Inside',
                  ),
                ] else
                  InfoRow(labelWidth: 110, label: 'Status', value: 'No location data'),
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
                    style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
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
