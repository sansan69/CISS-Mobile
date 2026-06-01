import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/location/live_location_service.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/utils/date_format.dart';
import '../../../../../shared/widgets/info_row.dart';
import '../../../../../shared/widgets/meta_chip.dart';

class AttendanceRecordDetailScreen extends StatefulWidget {
  const AttendanceRecordDetailScreen({
    super.key,
    required this.entry,
  });

  final FieldOfficerAttendanceEntry entry;

  @override
  State<AttendanceRecordDetailScreen> createState() =>
      _AttendanceRecordDetailScreenState();
}

class _AttendanceRecordDetailScreenState
    extends State<AttendanceRecordDetailScreen> {
  StreamSubscription<GuardLocationData?>? _sub;
  GuardLocationData? _location;
  final MapController _mapController = MapController();
  bool _tilesFailed = false;

  @override
  void initState() {
    super.initState();
    _sub = LiveLocationService()
        .streamGuardLocation(widget.entry.employeeId)
        .listen((data) {
      if (!mounted) return;
      setState(() => _location = data);
    });
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
    final entry = widget.entry;
    final loc = _location;
    final isActive = loc != null && loc.status == 'In';
    final hasCoords = loc != null && loc.lat != 0 && loc.lng != 0;
    final profileImageUrl = (entry.profilePhotoUrl != null &&
            entry.profilePhotoUrl!.isNotEmpty)
        ? entry.profilePhotoUrl
        : entry.photoUrl;
    final attendancePhotoUrl = entry.photoUrl;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: Text(
          'Attendance Record',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: tokens.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          // Guard Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: tokens.primarySoft,
                      backgroundImage:
                          (profileImageUrl != null && profileImageUrl.isNotEmpty)
                              ? NetworkImage(profileImageUrl)
                              : null,
                      child: (profileImageUrl == null ||
                              profileImageUrl.isEmpty)
                          ? Text(
                              entry.guardName.isNotEmpty
                                  ? entry.guardName.substring(0, 1).toUpperCase()
                                  : 'G',
                              style: GoogleFonts.roboto(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: tokens.primaryStrong,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.guardName.isEmpty ? 'Unknown Guard' : entry.guardName,
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (entry.employeeId.isNotEmpty) entry.employeeId,
                              if (entry.clientName.isNotEmpty) entry.clientName,
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // Live status dot
                    if (loc != null)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isActive
                              ? (loc.isOutOfZone ? tokens.danger : tokens.success)
                              : tokens.border,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: (loc.isOutOfZone
                                            ? tokens.danger
                                            : tokens.success)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (entry.district.isNotEmpty)
                      MetaChip(icon: Icons.place_outlined, label: entry.district),
                    if ((entry.gender ?? '').isNotEmpty)
                      MetaChip(icon: Icons.person_outline_rounded, label: entry.gender!),
                    if ((entry.phoneNumber ?? '').isNotEmpty)
                      MetaChip(icon: Icons.call_outlined, label: entry.phoneNumber!),
                  ],
                ),
              ],
            ),
          ),

          // Attendance Photo
          if (attendancePhotoUrl != null && attendancePhotoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ATTENDANCE PHOTO',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Image.network(
                      attendancePhotoUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 220,
                          color: tokens.surface,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 220,
                        color: tokens.surface,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_not_supported_outlined,
                                  color: tokens.inkMuted, size: 40),
                              const SizedBox(height: 8),
                              Text('Photo unavailable',
                                  style: TextStyle(color: tokens.inkMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Attendance Info Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ATTENDANCE DETAILS',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoRow(label: 'Date', value: entry.dateLabel),
                  InfoRow(label: 'Status', value: entry.status),
                  if (entry.checkIn != null)
                    InfoRow(label: 'Check In', value: entry.checkIn!),
                  if (entry.checkOut != null)
                    InfoRow(label: 'Check Out', value: entry.checkOut!),
                  InfoRow(label: 'Site', value: entry.siteName),
                  if (entry.dutyPointName.isNotEmpty)
                    InfoRow(label: 'Duty Point', value: entry.dutyPointName),
                  if (entry.shiftLabel.isNotEmpty)
                    InfoRow(label: 'Shift', value: entry.shiftLabel),
                ],
              ),
            ),
          ),

          // Live Location Section
          if (loc != null && hasCoords)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE LOCATION',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: tokens.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(loc.lat, loc.lng),
                        initialZoom: 16,
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
                        if (loc.siteLat != null &&
                            loc.siteLng != null &&
                            (loc.geofenceRadius ?? 0) > 0)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(loc.siteLat!, loc.siteLng!),
                                radius: loc.geofenceRadius!,
                                color: tokens.primary.withValues(alpha: 0.08),
                                borderColor:
                                    tokens.primary.withValues(alpha: 0.35),
                                borderStrokeWidth: 1.5,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(loc.lat, loc.lng),
                              width: 50,
                              height: 50,
                              child: _GuardMapMarker(
                                isOutOfZone: loc.isOutOfZone,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_tilesFailed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: tokens.warningSoft,
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: tokens.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Map tiles unavailable',
                              style: TextStyle(
                                  fontSize: 11, color: tokens.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Column(
                      children: [
                        InfoRow(label: 'Live Status', value: loc.status),
                        InfoRow(
                            label: 'Last Update', value: formatTimeSince(loc.updatedAt)),
                        if (loc.siteLat != null && loc.siteLng != null)
                          InfoRow(
                            label: 'Distance from Site',
                            value: '${calculateDistanceMeters(
                                  loc.lat,
                                  loc.lng,
                                  loc.siteLat!,
                                  loc.siteLng!,
                                ).toStringAsFixed(0)} m',
                          ),
                        InfoRow(
                          label: 'Zone Status',
                          value: loc.isOutOfZone ? '✗ OUTSIDE GEOFENCE' : '✓ Inside geofence',
                          valueColor:
                              loc.isOutOfZone ? tokens.danger : tokens.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (loc == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off_outlined,
                        color: tokens.inkMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No live location data available. Guard is not currently clocked in.',
                        style: TextStyle(color: tokens.inkMuted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

}

class _GuardMapMarker extends StatelessWidget {
  const _GuardMapMarker({required this.isOutOfZone});
  final bool isOutOfZone;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = isOutOfZone ? tokens.danger : tokens.success;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
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
          child: const Icon(Icons.person, color: Colors.white, size: 12),
        ),
        Container(
          width: 2,
          height: 8,
          color: color.withValues(alpha: 0.6),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 18),
      ],
    );
  }
}
