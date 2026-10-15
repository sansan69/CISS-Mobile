import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/haptics.dart';
import '../../../../../core/location/live_location_service.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../shared/navigate_button.dart';
import '../../../auth/application/auth_controller.dart';
import 'field_officer_guard_detail_screen.dart';
import 'guard_day_timeline_screen.dart';

/// Realtime map of every guard currently on duty — the CISS-AMS "realtime map
/// view of employees" surface.
///
/// Streams `guardLocations` (Firestore) so the map updates live. Firestore
/// rules already scope reads to the field officer's assigned districts, so no
/// district predicate is needed here — the chips below are a client-side
/// filter over whatever the rules allow.
class FieldOfficerLiveMapScreen extends ConsumerStatefulWidget {
  const FieldOfficerLiveMapScreen({super.key});

  @override
  ConsumerState<FieldOfficerLiveMapScreen> createState() =>
      _FieldOfficerLiveMapScreenState();
}

class _FieldOfficerLiveMapScreenState
    extends ConsumerState<FieldOfficerLiveMapScreen> {
  final MapController _mapController = MapController();
  final LiveLocationService _liveLocationService = LiveLocationService();

  String? _selectedDistrict;
  bool _fitRequested = false;
  bool _tilesFailed = false;

  List<String> get _assignedDistricts =>
      ref.watch(authSessionProvider).valueOrNull?.assignedDistricts ??
      const <String>[];

  List<GuardLocationData> _current(List<GuardLocationData> guards) {
    if (_selectedDistrict == null) return guards;
    return guards
        .where((guard) => guard.district == _selectedDistrict)
        .toList();
  }

  List<String> _districts(List<GuardLocationData> guards) {
    final districts =
        guards
            .map((guard) => guard.district.trim())
            .where((district) => district.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return districts;
  }

  List<_SiteGeofence> _uniqueSites(List<GuardLocationData> guards) {
    final map = <String, _SiteGeofence>{};
    for (final g in guards) {
      if (g.siteId.isNotEmpty && g.siteLat != null && g.siteLng != null) {
        map.putIfAbsent(
          g.siteId,
          () => _SiteGeofence(
            siteId: g.siteId,
            siteName: g.siteName.isNotEmpty ? g.siteName : 'Duty Site',
            lat: g.siteLat!,
            lng: g.siteLng!,
            radius: (g.geofenceRadius != null && g.geofenceRadius! > 0)
                ? g.geofenceRadius!
                : 150.0,
          ),
        );
      }
    }
    return map.values.toList();
  }

  void _fitBounds(List<GuardLocationData> guards) {
    if (guards.isEmpty || _fitRequested) return;
    _fitRequested = true;
    final points = guards.map((g) => LatLng(g.lat, g.lng)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(48, 140, 48, 220),
            maxZoom: 16,
          ),
        );
      } catch (_) {
        // Single point or degenerate bounds — keep current camera.
      }
    });
  }

  void _openGuardSheet(BuildContext context, GuardLocationData guard) {
    final tokens = CissThemeTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guard.guardName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              guard.employeeId,
                              if (guard.siteName.isNotEmpty) guard.siteName,
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.inkMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: guard.isOutOfZone ? 'OUT OF ZONE' : 'IN ZONE',
                      icon:
                          guard.isOutOfZone
                              ? Icons.location_off_rounded
                              : Icons.location_on_rounded,
                      tone:
                          guard.isOutOfZone
                              ? StatusChipTone.danger
                              : StatusChipTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Navigating to a guard's live position is what turns a
                // pinned map into a supervisor who actually arrives.
                NavigateAction(
                  latitude: guard.lat,
                  longitude: guard.lng,
                  label: guard.siteName,
                  compact: false,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _deviceStatusSheet(tokens, guard)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _pushTimeline(guard);
                        },
                        icon: const Icon(Icons.route_rounded, size: 18),
                        label: const Text('DAY TIMELINE'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => FieldOfficerGuardDetailScreen(
                                    employeeId: guard.employeeId,
                                    employeeDocId: guard.employeeDocId,
                                    guardName: guard.guardName,
                                    siteName: guard.siteName,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_rounded, size: 18),
                        label: const Text('GUARD DETAIL'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _deviceStatusSheet(CissThemeTokens tokens, GuardLocationData guard) {
    final battery = guard.batteryLevel;
    final batteryLabel = battery == null ? '—' : '${(battery * 100).round()}%';
    final batteryColor =
        battery == null
            ? tokens.inkMuted
            : battery < 0.15
            ? tokens.danger
            : battery < 0.5
            ? tokens.warning
            : tokens.success;

    return ModernCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _telemetryRow(
            tokens,
            Icons.battery_5_bar_rounded,
            'Battery',
            batteryLabel,
            color: batteryColor,
          ),
          const SizedBox(height: 8),
          _telemetryRow(
            tokens,
            guard.wifiConnected == true
                ? Icons.wifi_rounded
                : Icons.wifi_off_rounded,
            'Network',
            guard.wifiConnected == true
                ? (guard.networkType?.toUpperCase() ?? 'WIFI')
                : 'MOBILE DATA',
            color:
                guard.wifiConnected == true ? tokens.success : tokens.inkMuted,
          ),
          const SizedBox(height: 8),
          _telemetryRow(
            tokens,
            guard.gpsReliable == true
                ? Icons.gps_fixed_rounded
                : Icons.gps_off_rounded,
            'GPS',
            guard.gpsReliable == true
                ? 'LOCKED (${guard.accuracy.round()} m)'
                : 'UNRELIABLE',
            color: guard.gpsReliable == true ? tokens.success : tokens.danger,
          ),
          const SizedBox(height: 8),
          _telemetryRow(
            tokens,
            Icons.schedule_rounded,
            'Last update',
            _formatSince(guard.updatedAt),
          ),
        ],
      ),
    );
  }

  Widget _telemetryRow(
    CissThemeTokens tokens,
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? tokens.inkMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: tokens.inkMuted),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color ?? tokens.ink,
          ),
        ),
      ],
    );
  }

  void _pushTimeline(GuardLocationData guard) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => GuardDayTimelineScreen(
              employeeDocId: guard.employeeDocId,
              guardName: guard.guardName,
              employeeId: guard.employeeId,
            ),
      ),
    );
  }

  String _formatSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    }
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: const CissAppBar(title: 'Live Map', subtitle: 'Active guards'),
      body: StreamBuilder<List<GuardLocationData>>(
        // The officer's own districts, because the Firestore rule authorises a
        // live-location read per district and cannot filter an unscoped query.
        stream: _liveLocationService.streamActiveLocations(
          districts: _assignedDistricts,
        ),
        builder: (context, snapshot) {
          final guards = snapshot.data ?? const <GuardLocationData>[];
          final visible = _current(guards);
          _fitBounds(visible);

          if (snapshot.hasError) {
            return _ErrorState(message: 'Could not load live locations.');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (guards.isEmpty) {
            return _EmptyState(
              onRefresh: () {
                setState(() => _fitRequested = false);
              },
            );
          }

          final districts = _districts(guards);

          return Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(10.5, 76.2),
                    initialZoom: 8,
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
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
                    CircleLayer(
                      circles: _uniqueSites(visible).map((site) {
                        return CircleMarker(
                          point: LatLng(site.lat, site.lng),
                          radius: site.radius,
                          useRadiusInMeter: true,
                          color: tokens.primary.withValues(alpha: 0.12),
                          borderColor: tokens.primary.withValues(alpha: 0.45),
                          borderStrokeWidth: 1.5,
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers: _uniqueSites(visible).map((site) {
                        return Marker(
                          point: LatLng(site.lat, site.lng),
                          width: 120,
                          height: 32,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surface.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: tokens.borderStrong,
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.business_rounded,
                                    size: 12,
                                    color: tokens.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      site.siteName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers:
                          visible.map((guard) {
                            final zoneColor =
                                guard.isOutOfZone
                                    ? tokens.danger
                                    : tokens.success;
                            return Marker(
                              point: LatLng(guard.lat, guard.lng),
                              width: 86,
                              height: 92,
                              child: GestureDetector(
                                onTap: () => _openGuardSheet(context, guard),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: zoneColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: tokens.surface,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: zoneColor.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _initials(guard.guardName),
                                        style: TextStyle(
                                          color: tokens.surface,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    // Battery strip under the marker.
                                    Container(
                                      width: 26,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: tokens.surface,
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: tokens.borderStrong,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: guard.batteryLevel ?? 0,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: _batteryColor(tokens, guard),
                                            borderRadius: BorderRadius.circular(
                                              1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),

              // District filter chips
              if (districts.length > 1)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          tokens,
                          label: 'All',
                          selected: _selectedDistrict == null,
                          onTap: () {
                            setState(() {
                              _selectedDistrict = null;
                              _fitRequested = false;
                            });
                          },
                        ),
                        ...districts.map(
                          (district) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _filterChip(
                              tokens,
                              label: district,
                              selected: _selectedDistrict == district,
                              onTap: () {
                                setState(() {
                                  _selectedDistrict = district;
                                  _fitRequested = false;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Tile error banner
              if (_tilesFailed)
                Positioned(
                  top: 72,
                  left: 12,
                  right: 12,
                  child: _TileWarning(tokens: tokens),
                ),

              // Bottom status bar
              Positioned(
                left: 14,
                right: 14,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: tokens.specularBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: tokens.glowEmerald.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tokens.glowEmerald.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          size: 18,
                          color: tokens.glowEmerald,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${visible.length} Active Duty Guard${visible.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: tokens.ink,
                              ),
                            ),
                            Text(
                              '${visible.where((g) => !g.isOutOfZone).length} in zone • ${visible.where((g) => g.isOutOfZone).length} out of zone',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.glowEmerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'LIVE GPS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: tokens.glowEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(
    CissThemeTokens tokens, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? tokens.primary : tokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: () {
          Haptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? tokens.primary : tokens.specularBorder,
              width: 1,
            ),
            boxShadow: selected ? AppShadows.glow(tokens.primary) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  Color _batteryColor(CissThemeTokens tokens, GuardLocationData guard) {
    final battery = guard.batteryLevel;
    if (battery == null) return tokens.borderStrong;
    if (battery < 0.15) return tokens.danger;
    if (battery < 0.5) return tokens.warning;
    return tokens.success;
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _TileWarning extends StatelessWidget {
  const _TileWarning({required this.tokens});

  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: tokens.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Map tiles unavailable. Guard positions still live.',
              style: TextStyle(fontSize: 12, color: tokens.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 48, color: tokens.inkMuted),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: tokens.inkMuted)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_pin_circle_outlined,
              size: 56,
              color: tokens.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No guards on duty right now',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Guards appear here the moment they clock in. '
              'The map updates live as their positions stream in.',
              style: TextStyle(fontSize: 14, color: tokens.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('REFRESH'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteGeofence {
  const _SiteGeofence({
    required this.siteId,
    required this.siteName,
    required this.lat,
    required this.lng,
    required this.radius,
  });

  final String siteId;
  final String siteName;
  final double lat;
  final double lng;
  final double radius;
}

