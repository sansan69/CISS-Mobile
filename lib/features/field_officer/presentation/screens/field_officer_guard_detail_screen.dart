import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/location/live_location_service.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/modern_card.dart';
import 'guard_attendance_logs_screen.dart';
import 'guard_day_timeline_screen.dart';

class FieldOfficerGuardDetailScreen extends StatefulWidget {
  const FieldOfficerGuardDetailScreen({
    super.key,
    required this.employeeId,
    required this.guardName,
    required this.siteName,
    this.attendanceEntry,
    this.employeeDocId,
    this.siteLatitude,
    this.siteLongitude,
    this.siteGeofenceRadius,
  });

  final String employeeId;
  final String guardName;
  final String siteName;
  final FieldOfficerAttendanceEntry? attendanceEntry;
  final String? employeeDocId;
  final double? siteLatitude;
  final double? siteLongitude;
  final double? siteGeofenceRadius;

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
  bool _tilesFailed = false;

  @override
  void initState() {
    super.initState();
    final locationKey =
        widget.employeeDocId ??
        widget.attendanceEntry?.guardId ??
        widget.employeeId;
    _sub = LiveLocationService().streamGuardLocation(locationKey).listen((
      data,
    ) {
      if (!mounted) return;
      setState(() {
        _location = data;
      });
      if (_followGuard) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _animateToMapPoints(),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToMapPoints());
  }

  List<LatLng> _mapPoints() {
    final points = <LatLng>[];
    final loc = _location;
    if (loc != null && _validCoordinates(loc.lat, loc.lng)) {
      points.add(LatLng(loc.lat, loc.lng));
    }
    final entry = widget.attendanceEntry;
    if (entry != null &&
        _validCoordinates(
          entry.attendanceLatitude,
          entry.attendanceLongitude,
        )) {
      points.add(LatLng(entry.attendanceLatitude!, entry.attendanceLongitude!));
    }

    final siteLat = widget.siteLatitude ?? loc?.siteLat;
    final siteLng = widget.siteLongitude ?? loc?.siteLng;
    if (_validCoordinates(siteLat, siteLng)) {
      points.add(LatLng(siteLat!, siteLng!));
    }
    return points;
  }

  void _animateToMapPoints() {
    final points = _mapPoints();
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 17);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 64),
            maxZoom: 17,
          ),
        );
      }
    } catch (_) {
      // The map controller can be unavailable during the first frame.
      // Location updates will retry after the map is mounted.
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

    final isActive = loc != null && loc.status.toLowerCase() == 'in';
    final guardLat = loc?.lat ?? 0;
    final guardLng = loc?.lng ?? 0;
    final hasLiveCoords = _validCoordinates(guardLat, guardLng);
    final attendanceLat = widget.attendanceEntry?.attendanceLatitude;
    final attendanceLng = widget.attendanceEntry?.attendanceLongitude;
    final hasAttendanceCoords = _validCoordinates(attendanceLat, attendanceLng);
    final siteLat = widget.siteLatitude ?? loc?.siteLat;
    final siteLng = widget.siteLongitude ?? loc?.siteLng;
    final radius =
        widget.siteGeofenceRadius ??
        loc?.geofenceRadius ??
        widget.attendanceEntry?.geofenceRadiusAtTime?.toDouble() ??
        0.0;
    final mapPoints = _mapPoints();
    final initialCenter =
        mapPoints.isNotEmpty ? mapPoints.first : const LatLng(10.0, 76.0);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: CissAppBar(title: widget.guardName, subtitle: 'Guard details'),
      body: Column(
        children: <Widget>[
          // Map
          Expanded(
            flex: 3,
            child: SizedBox(
              width: double.infinity,
              child: ClipRRect(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: mapPoints.length > 1 ? 14 : 17,
                    onMapEvent: (event) {
                      if (event.source != MapEventSource.mapController &&
                          (event is MapEventMoveStart ||
                              event is MapEventFlingAnimation)) {
                        setState(() => _followGuard = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'co.in.ciss.ciss_mobile',
                      errorTileCallback: (tile, error, stackTrace) {
                        if (!_tilesFailed) {
                          setState(() => _tilesFailed = true);
                        }
                      },
                    ),
                    // Guard marker
                    if (hasLiveCoords)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(guardLat, guardLng),
                            width: 60,
                            height: 60,
                            child: _GuardMarker(
                              isOutOfZone: loc?.isOutOfZone ?? false,
                            ),
                          ),
                        ],
                      ),
                    if (!hasLiveCoords && hasAttendanceCoords)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(attendanceLat!, attendanceLng!),
                            width: 68,
                            height: 68,
                            child: _AttendanceMarker(
                              isCheckedOut:
                                  widget.attendanceEntry?.checkOut != null,
                            ),
                          ),
                        ],
                      ),
                    if (hasLiveCoords && hasAttendanceCoords)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(attendanceLat!, attendanceLng!),
                            width: 58,
                            height: 58,
                            child: _RecordedPointMarker(),
                          ),
                        ],
                      ),
                    if (_validCoordinates(siteLat, siteLng))
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(siteLat!, siteLng!),
                            width: 58,
                            height: 58,
                            child: _SiteMarker(),
                          ),
                        ],
                      ),
                    // Site geofence circle
                    if (_validCoordinates(siteLat, siteLng) && radius > 0)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(siteLat!, siteLng!),
                            radius: radius,
                            color: tokens.primary.withValues(alpha: 0.08),
                            borderColor: tokens.primary.withValues(alpha: 0.35),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    // Accuracy ring
                    if (hasLiveCoords && (loc?.accuracy ?? 0) > 0)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(guardLat, guardLng),
                            radius: loc!.accuracy,
                            color: (loc.isOutOfZone
                                    ? tokens.danger
                                    : tokens.success)
                                .withValues(alpha: 0.06),
                            borderColor: (loc.isOutOfZone
                                    ? tokens.danger
                                    : tokens.success)
                                .withValues(alpha: 0.25),
                            borderStrokeWidth: 1,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Keep the map outside the scrollable detail panel. This prevents a
          // vertical swipe over the map from scrolling the entire page.
          Expanded(
            flex: 2,
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                // Tile error banner
                if (_tilesFailed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: tokens.warningSoft,
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: tokens.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Map tiles unavailable. Guard location still visible.',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Info card
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ModernCard(
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
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isActive
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
                                      color:
                                          isActive
                                              ? tokens.success
                                              : tokens.danger,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isActive ? 'ON DUTY' : 'OFF DUTY',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color:
                                          isActive
                                              ? tokens.success
                                              : tokens.danger,
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
                          if (hasLiveCoords &&
                              siteLat != null &&
                              siteLng != null) ...[
                            _infoRow(
                              tokens,
                              'Distance from site',
                              '${_calculateDistance(guardLat, guardLng, siteLat, siteLng).toStringAsFixed(0)} m',
                            ),
                          ],
                          _DeviceStatusRow(location: loc),
                        ] else
                          _infoRow(tokens, 'Status', 'No location data'),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => GuardDayTimelineScreen(
                                            employeeDocId:
                                                loc?.employeeDocId ??
                                                widget.employeeId,
                                            guardName: widget.guardName,
                                            employeeId:
                                                loc?.employeeId ??
                                                widget.employeeId,
                                          ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.route_rounded, size: 18),
                                label: Text(
                                  'TIMELINE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => GuardAttendanceLogsScreen(
                                            employeeId:
                                                loc?.employeeId ??
                                                widget.employeeId,
                                            guardId:
                                                loc?.employeeDocId ??
                                                widget.employeeId,
                                            guardName: widget.guardName,
                                          ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'ATTENDANCE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (widget.attendanceEntry != null)
                  _AttendanceDetailsCard(
                    entry: widget.attendanceEntry!,
                    siteLatitude: siteLat,
                    siteLongitude: siteLng,
                  ),

                // Recenter button
                if (!_followGuard && mapPoints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _followGuard = true);
                          _animateToMapPoints();
                        },
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          'RECENTER ON GUARD',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000; // Earth radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

/// Device telemetry strip — battery level, network state, GPS reliability.
class _DeviceStatusRow extends StatelessWidget {
  const _DeviceStatusRow({required this.location});

  final GuardLocationData location;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final battery = location.batteryLevel;
    final batteryColor =
        battery == null
            ? tokens.inkMuted
            : battery < 0.15
            ? tokens.danger
            : battery < 0.5
            ? tokens.warning
            : tokens.success;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _telemetryItem(
            tokens,
            icon: Icons.battery_5_bar_rounded,
            label:
                battery == null
                    ? 'Battery —'
                    : 'Battery ${(battery * 100).round()}%',
            color: batteryColor,
          ),
          _telemetryDivider(tokens),
          _telemetryItem(
            tokens,
            icon:
                location.wifiConnected == true
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
            label:
                location.wifiConnected == true
                    ? (location.networkType?.toUpperCase() ?? 'WIFI')
                    : 'DATA',
            color:
                location.wifiConnected == true
                    ? tokens.success
                    : tokens.inkMuted,
          ),
          _telemetryDivider(tokens),
          _telemetryItem(
            tokens,
            icon:
                location.gpsReliable == true
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_off_rounded,
            label:
                location.gpsReliable == true
                    ? 'GPS ${location.accuracy.round()} m'
                    : 'GPS weak',
            color:
                location.gpsReliable == true ? tokens.success : tokens.danger,
          ),
        ],
      ),
    );
  }

  Widget _telemetryItem(
    CissThemeTokens tokens, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryDivider(CissThemeTokens tokens) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: tokens.border,
    );
  }
}

class _AttendanceDetailsCard extends StatelessWidget {
  const _AttendanceDetailsCard({
    required this.entry,
    this.siteLatitude,
    this.siteLongitude,
  });

  final FieldOfficerAttendanceEntry entry;
  final double? siteLatitude;
  final double? siteLongitude;

  String? _formatPoint(double? latitude, double? longitude) {
    if (!_validCoordinates(latitude, longitude)) return null;
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final photo = entry.photoCompliance;
    final photoWarnings =
        photo?['warnings'] is List
            ? (photo!['warnings'] as List)
                .whereType<String>()
                .where((item) => item.trim().isNotEmpty)
                .toList()
            : const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: ModernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.fact_check_outlined,
                  size: 20,
                  color: tokens.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Attendance details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _AttendanceStatusChip(status: entry.status),
              ],
            ),
            const SizedBox(height: 12),
            _detailGrid(context, <_AttendanceDetail>[
              _AttendanceDetail('Date', entry.dateLabel),
              _AttendanceDetail('Shift', entry.shiftLabel),
              _AttendanceDetail('Duty point', entry.dutyPointName),
              _AttendanceDetail('Check-in', entry.checkIn ?? '--:--'),
              _AttendanceDetail('Check-out', entry.checkOut ?? '--:--'),
              _AttendanceDetail('Client', entry.clientName),
              _AttendanceDetail('District', entry.district),
            ]),
            const SizedBox(height: 14),
            Divider(color: tokens.border),
            const SizedBox(height: 10),
            Text(
              'Location evidence',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.inkMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            _detailGrid(context, <_AttendanceDetail>[
              _AttendanceDetail(
                'Recorded check-in',
                _formatPoint(
                  entry.attendanceLatitude,
                  entry.attendanceLongitude,
                ),
              ),
              _AttendanceDetail(
                'Working location',
                _formatPoint(siteLatitude, siteLongitude),
              ),
              _AttendanceDetail(
                'Distance from site',
                entry.distanceMeters == null
                    ? null
                    : '${entry.distanceMeters!.round()} m',
              ),
              _AttendanceDetail(
                'GPS accuracy',
                entry.gpsAccuracyMeters == null
                    ? null
                    : '${entry.gpsAccuracyMeters!.round()} m',
              ),
              _AttendanceDetail(
                'Geofence radius',
                entry.geofenceRadiusAtTime == null
                    ? null
                    : '${entry.geofenceRadiusAtTime!.round()} m',
              ),
              _AttendanceDetail('Review status', entry.reviewStatus),
            ]),
            if (entry.isMockLocationSuspected ||
                entry.requiresAdminReview) ...<Widget>[
              const SizedBox(height: 12),
              _AlertDetail(
                icon: Icons.warning_amber_rounded,
                color: tokens.danger,
                title:
                    entry.isMockLocationSuspected
                        ? 'Mock location suspected'
                        : 'Admin review required',
                message: entry.mockLocationReason,
              ),
            ],
            if (photo != null) ...<Widget>[
              const SizedBox(height: 14),
              Divider(color: tokens.border),
              const SizedBox(height: 10),
              Text(
                'Photo compliance',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _PhotoCheck(
                    label: 'Shoes',
                    ok: photo['missingShoes'] != true,
                  ),
                  _PhotoCheck(
                    label: 'ID card',
                    ok: photo['missingIdCard'] != true,
                  ),
                  _PhotoCheck(
                    label: 'Uniform',
                    ok: photo['uniformIssue'] != true,
                  ),
                  _PhotoCheck(
                    label: 'Full body',
                    ok: photo['fullBodyVisible'] == true,
                  ),
                  if (photo['adminFlag'] == true)
                    const _PhotoCheck(label: 'Admin flag', ok: false),
                ],
              ),
              if (photoWarnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  photoWarnings.join(' • '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.warning),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailGrid(BuildContext context, List<_AttendanceDetail> details) {
    final visible =
        details.where((item) => item.value?.trim().isNotEmpty == true).toList();
    if (visible.isEmpty) {
      return Text(
        'No additional data available.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children:
          visible
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.label,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: CissThemeTokens.of(context).inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          item.value!,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _AttendanceDetail {
  const _AttendanceDetail(this.label, this.value);

  final String label;
  final String? value;
}

class _AttendanceStatusChip extends StatelessWidget {
  const _AttendanceStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isPresent =
        status.toLowerCase().contains('present') ||
        status.toLowerCase().contains('duty');
    final color = isPresent ? tokens.success : tokens.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AlertDetail extends StatelessWidget {
  const _AlertDetail({
    required this.icon,
    required this.color,
    required this.title,
    this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (message?.trim().isNotEmpty == true)
                  Text(message!, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCheck extends StatelessWidget {
  const _PhotoCheck({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = ok ? tokens.success : tokens.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

bool _validCoordinates(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);
}

class _SiteMarker extends StatelessWidget {
  const _SiteMarker();

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: tokens.primary,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.surface, width: 2.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.primary.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.business_rounded, color: tokens.surface, size: 16),
    );
  }
}

class _AttendanceMarker extends StatelessWidget {
  const _AttendanceMarker({required this.isCheckedOut});

  final bool isCheckedOut;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = isCheckedOut ? tokens.accent : tokens.success;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: tokens.surface, width: 2.5),
          ),
          child: Icon(
            Icons.person_pin_circle_rounded,
            color: tokens.surface,
            size: 17,
          ),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 18),
      ],
    );
  }
}

class _RecordedPointMarker extends StatelessWidget {
  const _RecordedPointMarker();

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: tokens.accent,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.surface, width: 2),
      ),
      child: Icon(Icons.flag_rounded, color: tokens.surface, size: 13),
    );
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
            border: Border.all(color: tokens.surface, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.person, color: tokens.surface, size: 14),
        ),
        Container(width: 2, height: 10, color: color.withValues(alpha: 0.6)),
        Icon(Icons.arrow_drop_down, color: color, size: 20),
      ],
    );
  }
}
