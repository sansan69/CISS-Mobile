import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/region/region_service.dart';
import '../../../../../shared/widgets/status_chip.dart';

/// One 5-minute breadcrumb from `guardLocations/{employeeDocId}/locationHistory`.
class _HistoryPoint {
  const _HistoryPoint({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    required this.zoneStatus,
    required this.isOutOfZone,
    required this.distanceFromSite,
    this.speed,
    this.batteryLevel,
    this.wifiConnected,
    this.accuracy,
  });

  final double lat;
  final double lng;
  final DateTime recordedAt;
  final String zoneStatus;
  final bool isOutOfZone;
  final double distanceFromSite;
  final double? speed;
  final double? batteryLevel;
  final bool? wifiConnected;
  final double? accuracy;
}

enum _Activity { still, walking, traveling }

_Activity _classify(double? speed) {
  final s = speed ?? 0;
  if (s < 0.6) return _Activity.still;
  if (s < 5.5) return _Activity.walking;
  return _Activity.traveling;
}

String _activityLabel(_Activity activity) => switch (activity) {
  _Activity.still => 'STILL',
  _Activity.walking => 'WALKING',
  _Activity.traveling => 'TRAVELING',
};

/// Guard day timeline — the CISS-AMS "activity as a timeline with polyline map
/// and markers" surface.
///
/// Renders the guard's 5-minute location breadcrumbs for one day: a polyline
/// route, stay markers where the guard remained in place, an optional site
/// geofence circle, and a scrollable activity list with device telemetry.
class GuardDayTimelineScreen extends StatefulWidget {
  const GuardDayTimelineScreen({
    super.key,
    required this.employeeDocId,
    required this.guardName,
    this.employeeId,
  });

  final String employeeDocId;
  final String guardName;
  final String? employeeId;

  @override
  State<GuardDayTimelineScreen> createState() =>
      _GuardDayTimelineScreenState();
}

class _GuardDayTimelineScreenState extends State<GuardDayTimelineScreen> {
  DateTime _selectedDay = DateTime.now();
  bool _mapReady = false;
  final MapController _mapController = MapController();

  final Distance _distance = const Distance();

  // IST day bounds (Kerala is UTC+5:30, no DST).
  (DateTime, DateTime) _dayBounds(DateTime day) {
    final startUtc = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(const Duration(hours: 5, minutes: 30));
    return (
      startUtc,
      startUtc.add(const Duration(days: 1)),
    );
  }

  void _fitRoute(List<_HistoryPoint> points) {
    if (points.isEmpty || _mapReady) return;
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(
              points.map((p) => LatLng(p.lat, p.lng)).toList(),
            ),
            padding: const EdgeInsets.all(48),
            maxZoom: 17,
          ),
        );
      } catch (_) {
        // Degenerate bounds — keep the default camera.
      }
    });
  }

  /// Groups consecutive low-speed breadcrumbs that stay within ~30 m of each
  /// other into "stay" segments. Returns the first point of each segment.
  List<_HistoryPoint> _stayPoints(List<_HistoryPoint> points) {
    final stays = <_HistoryPoint>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (_classify(point.speed) != _Activity.still) continue;
      if (i == 0) {
        stays.add(point);
        continue;
      }
      final previous = points[i - 1];
      final moved = _distance.as(
        LengthUnit.Meter,
        LatLng(previous.lat, previous.lng),
        LatLng(point.lat, point.lng),
      );
      // New stay segment when the guard walked away (>30 m) since the last point.
      if (previous.isOutOfZone != point.isOutOfZone || moved > 30) {
        stays.add(point);
      }
    }
    return stays;
  }

  double _routeDistance(List<_HistoryPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _distance.as(
        LengthUnit.Meter,
        LatLng(points[i - 1].lat, points[i - 1].lng),
        LatLng(points[i].lat, points[i].lng),
      );
    }
    return total;
  }

  String _formatDay(DateTime day) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final today = DateTime.now();
    final isToday =
        today.year == day.year &&
        today.month == day.month &&
        today.day == day.day;
    final label = '${day.day} ${months[day.month - 1]} ${day.year}';
    return isToday ? 'Today · $label' : label;
  }

  Future<(List<_HistoryPoint>, Map<String, dynamic>?)> _loadDayData(
    DateTime day,
  ) async {
    final history = await _loadHistory(day);
    final siteDoc = await _loadGuardLocationDoc();
    return (history, siteDoc);
  }

  Future<Map<String, dynamic>?> _loadGuardLocationDoc() async {
    try {
      final doc = await RegionService.instance.activeFirestore
          .collection('guardLocations')
          .doc(widget.employeeDocId)
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<List<_HistoryPoint>> _loadHistory(DateTime day) async {
    final (startUtc, endUtc) = _dayBounds(day);
    try {
      final snapshot = await RegionService.instance.activeFirestore
          .collection('guardLocations')
          .doc(widget.employeeDocId)
          .collection('locationHistory')
          .where('recordedAt', isGreaterThanOrEqualTo: startUtc)
          .where('recordedAt', isLessThan: endUtc)
          .orderBy('recordedAt', descending: false)
          .get();
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final recordedAt =
                (data['recordedAt'] as Timestamp?)?.toDate();
            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            if (recordedAt == null || lat == null || lng == null) return null;
            return _HistoryPoint(
              lat: lat,
              lng: lng,
              recordedAt: recordedAt,
              zoneStatus: (data['zoneStatus'] as String?) ?? 'unknown',
              isOutOfZone: data['isOutOfZone'] == true,
              distanceFromSite:
                  (data['distanceFromSite'] as num?)?.toDouble() ?? 0,
              speed: (data['speed'] as num?)?.toDouble(),
              batteryLevel: (data['batteryLevel'] as num?)?.toDouble(),
              wifiConnected: data['wifiConnected'] as bool?,
              accuracy: (data['accuracy'] as num?)?.toDouble(),
            );
          })
          .whereType<_HistoryPoint>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _changeDay(int delta) async {
    final next = _selectedDay.add(Duration(days: delta));
    final today = DateTime.now();
    if (delta > 0 &&
        (next.year > today.year ||
            (next.year == today.year && next.month > today.month) ||
            (next.year == today.year &&
                next.month == today.month &&
                next.day > today.day))) {
      return; // No future days.
    }
    setState(() {
      _selectedDay = next;
      _mapReady = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: Text(
          widget.guardName,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: tokens.ink,
          ),
        ),
        backgroundColor: tokens.canvas,
      ),
      body: FutureBuilder<(List<_HistoryPoint>, Map<String, dynamic>?)>(
        future: _loadDayData(_selectedDay),
        builder: (context, historySnapshot) {
          if (historySnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = historySnapshot.data;
          final points = data?.$1 ?? const <_HistoryPoint>[];
          final siteDoc = data?.$2;
          return Column(
            children: [
              _DaySelector(
                label: _formatDay(_selectedDay),
                canGoNext:
                    _selectedDay.isBefore(DateTime.now()) &&
                    !(_selectedDay.year == DateTime.now().year &&
                        _selectedDay.month == DateTime.now().month &&
                        _selectedDay.day == DateTime.now().day),
                onPrevious: () => _changeDay(-1),
                onNext: () => _changeDay(1),
              ),
              if (points.isEmpty)
                Expanded(child: _EmptyTimeline(tokens: tokens))
              else
                Expanded(
                  child: _TimelineContent(
                    points: points,
                    stayPoints: _stayPoints(points),
                    routeDistance: _routeDistance(points),
                    siteDoc: siteDoc,
                    mapController: _mapController,
                    onMapReady: () => _fitRoute(points),
                    employeeDocId: widget.employeeDocId,
                    guardName: widget.guardName,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.label,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous day',
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: tokens.ink,
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next day',
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: canGoNext ? tokens.ink : tokens.borderStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({
    required this.points,
    required this.stayPoints,
    required this.routeDistance,
    required this.siteDoc,
    required this.mapController,
    required this.onMapReady,
    required this.employeeDocId,
    required this.guardName,
  });

  final List<_HistoryPoint> points;
  final List<_HistoryPoint> stayPoints;
  final double routeDistance;
  final Map<String, dynamic>? siteDoc;
  final MapController mapController;
  final VoidCallback onMapReady;
  final String employeeDocId;
  final String guardName;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final first = points.first;
    final last = points.last;
    final span = last.recordedAt.difference(first.recordedAt);
    final outOfZoneCount = points.where((p) => p.isOutOfZone).length;

    final siteLat = (siteDoc?['siteLat'] as num?)?.toDouble();
    final siteLng = (siteDoc?['siteLng'] as num?)?.toDouble();
    final siteRadius = (siteDoc?['geofenceRadius'] as num?)?.toDouble();

    return Column(
      children: [
        // Route map
        SizedBox(
          height: 300,
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(first.lat, first.lng),
              initialZoom: 14,
              onMapReady: onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ciss.mobile',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points
                        .map((p) => LatLng(p.lat, p.lng))
                        .toList(),
                    strokeWidth: 3.5,
                    color: tokens.primary,
                    borderStrokeWidth: 1.5,
                    borderColor: tokens.surface.withValues(alpha: 0.8),
                  ),
                ],
              ),
              if (siteLat != null &&
                  siteLng != null &&
                  siteRadius != null &&
                  siteRadius > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(siteLat, siteLng),
                      radius: siteRadius,
                      color: tokens.primary.withValues(alpha: 0.08),
                      borderColor: tokens.primary.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Start
                  Marker(
                    point: LatLng(first.lat, first.lng),
                    width: 28,
                    height: 28,
                    child: Icon(
                      Icons.flag_circle_rounded,
                      color: tokens.success,
                      size: 26,
                    ),
                  ),
                  // End
                  Marker(
                    point: LatLng(last.lat, last.lng),
                    width: 28,
                    height: 28,
                    child: Icon(
                      Icons.flag_rounded,
                      color: tokens.primary,
                      size: 26,
                    ),
                  ),
                  // Out-of-zone breadcrumbs
                  ...points
                      .where((p) => p.isOutOfZone)
                      .map(
                        (p) => Marker(
                          point: LatLng(p.lat, p.lng),
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: tokens.danger,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tokens.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  // Stay markers (pulse)
                  ...stayPoints.map(
                    (p) => Marker(
                      point: LatLng(p.lat, p.lng),
                      width: 44,
                      height: 44,
                      child: _StayMarker(tokens: tokens),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Summary strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: tokens.surface,
          child: Row(
            children: [
              _SummaryStat(
                tokens: tokens,
                label: 'DISTANCE',
                value: routeDistance >= 1000
                    ? '${(routeDistance / 1000).toStringAsFixed(1)} km'
                    : '${routeDistance.round()} m',
              ),
              _SummaryStat(
                tokens: tokens,
                label: 'SPAN',
                value: '${span.inHours}h ${span.inMinutes % 60}m',
              ),
              _SummaryStat(
                tokens: tokens,
                label: 'OUT OF ZONE',
                value: '$outOfZoneCount',
                color: outOfZoneCount > 0 ? tokens.danger : tokens.success,
              ),
            ],
          ),
        ),

        // Activity timeline
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: points.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final point = points[index];
              final activity = _classify(point.speed);
              return _TimelineRow(
                tokens: tokens,
                point: point,
                activity: activity,
                isFirst: index == 0,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.tokens,
    required this.label,
    required this.value,
    this.color,
  });

  final CissThemeTokens tokens;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color ?? tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.tokens,
    required this.point,
    required this.activity,
    required this.isFirst,
  });

  final CissThemeTokens tokens;
  final _HistoryPoint point;
  final _Activity activity;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final battery = point.batteryLevel;
    final batteryColor = battery == null
        ? tokens.inkMuted
        : battery < 0.15
        ? tokens.danger
        : battery < 0.5
        ? tokens.warning
        : tokens.success;

    final activityTone = switch (activity) {
      _Activity.still => StatusChipTone.neutral,
      _Activity.walking => StatusChipTone.info,
      _Activity.traveling => StatusChipTone.warning,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time rail
          SizedBox(
            width: 64,
            child: Text(
              _timeLabel(point.recordedAt, isFirst),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFirst ? tokens.success : tokens.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                StatusChip(
                  label: _activityLabel(activity),
                  tone: activityTone,
                ),
                const SizedBox(width: 8),
                Icon(
                  point.wifiConnected == true
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  size: 15,
                  color: point.wifiConnected == true
                      ? tokens.success
                      : tokens.inkMuted,
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.battery_5_bar_rounded,
                  size: 15,
                  color: batteryColor,
                ),
                if (battery != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${(battery * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: batteryColor,
                    ),
                  ),
                ],
                const Spacer(),
                if (point.isOutOfZone)
                  StatusChip(
                    label: 'ZONE',
                    tone: StatusChipTone.danger,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt, bool isFirst) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final am = dt.hour < 12 ? 'AM' : 'PM';
    final label = '$h:${dt.minute.toString().padLeft(2, '0')} $am';
    return isFirst ? 'Start · $label' : label;
  }
}

class _StayMarker extends StatelessWidget {
  const _StayMarker({required this.tokens});

  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: tokens.primary.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: tokens.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: tokens.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.tokens});

  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 52,
              color: tokens.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No movement data for this day',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Location breadcrumbs are recorded every 5 minutes while '
              'the guard is clocked in and are kept for 30 days.',
              style: TextStyle(fontSize: 13, color: tokens.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
