import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/location/live_location_service.dart';
import '../../../../shared/widgets/brand_banner.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/portal_primitives.dart';
import '../../../../shared/widgets/state_block.dart';
import '../../../../shared/widgets/status_chip.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({
    super.key,
    this.districtFilter,
    this.clientFilter,
    this.siteFilter,
  });

  final String? districtFilter;
  final String? clientFilter;
  final String? siteFilter;

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  List<GuardLocationData> _locations = const <GuardLocationData>[];
  StreamSubscription<List<GuardLocationData>>? _sub;
  bool _tilesFailed = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _sub = LiveLocationService()
        .streamActiveLocations(district: widget.districtFilter)
        .listen((data) {
      if (!mounted) return;
      setState(() => _locations = data);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  List<GuardLocationData> get _filtered {
    var result = _locations;
    if (widget.clientFilter != null && widget.clientFilter!.trim().isNotEmpty) {
      result = result
          .where((l) =>
              l.clientName.toLowerCase() == widget.clientFilter!.toLowerCase())
          .toList();
    }
    if (widget.siteFilter != null && widget.siteFilter!.trim().isNotEmpty) {
      result = result
          .where(
              (l) => l.siteId.toLowerCase() == widget.siteFilter!.toLowerCase())
          .toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((l) {
        return l.guardName.toLowerCase().contains(q) ||
            l.employeeId.toLowerCase().contains(q) ||
            l.siteName.toLowerCase().contains(q) ||
            l.clientName.toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  int get _outOfZoneCount =>
      _filtered.where((l) => l.isOutOfZone && l.status == 'In').length;

  LatLng get _mapCenter {
    final active = _filtered.where((l) => l.lat != 0 && l.lng != 0).toList();
    if (active.isEmpty) return const LatLng(10.0, 76.0);
    final avgLat = active.map((l) => l.lat).reduce((a, b) => a + b) / active.length;
    final avgLng = active.map((l) => l.lng).reduce((a, b) => a + b) / active.length;
    return LatLng(avgLat, avgLng);
  }

  double _zoomForBounds() {
    final active = _filtered.where((l) => l.lat != 0 && l.lng != 0).toList();
    if (active.length <= 1) return 15;
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    for (final l in active) {
      if (l.lat < minLat) minLat = l.lat;
      if (l.lat > maxLat) maxLat = l.lat;
      if (l.lng < minLng) minLng = l.lng;
      if (l.lng > maxLng) maxLng = l.lng;
    }
    final latDelta = maxLat - minLat;
    final lngDelta = maxLng - minLng;
    final maxDelta = math.max(latDelta, lngDelta);
    if (maxDelta <= 0) return 15;
    // rough zoom heuristic: log2(360 / delta) + padding
    final zoom = math.log(360 / maxDelta) / math.ln2;
    return zoom.clamp(10.0, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final filtered = _filtered;
    final outOfZone = _outOfZoneCount;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: BrandBanner(
              title: 'Live Tracking',
              subtitle: widget.districtFilter != null
                  ? '${widget.districtFilter} · ${filtered.length} active'
                  : '${filtered.length} guards on duty',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (outOfZone > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tokens.danger,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$outOfZone OUT OF ZONE',
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _mapController.move(_mapCenter, _zoomForBounds()),
                    icon: const Icon(Icons.my_location_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search guard, site, or client...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: tokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 340,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: _zoomForBounds(),
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
                    // Site geofence circles
                    CircleLayer(
                      circles: filtered
                          .where((l) =>
                              l.siteLat != null &&
                              l.siteLng != null &&
                              (l.geofenceRadius ?? 0) > 0)
                          .map((l) => CircleMarker(
                                point: LatLng(l.siteLat!, l.siteLng!),
                                radius: l.geofenceRadius!,
                                color: tokens.primary.withValues(alpha: 0.06),
                                borderColor:
                                    tokens.primary.withValues(alpha: 0.3),
                                borderStrokeWidth: 1,
                              ))
                          .toList(),
                    ),
                    // Guard markers
                    MarkerLayer(
                      markers: filtered
                          .where((l) => l.lat != 0 && l.lng != 0)
                          .map((l) => Marker(
                                point: LatLng(l.lat, l.lng),
                                width: 60,
                                height: 60,
                                child: _GuardMapMarker(
                                  isOutOfZone: l.isOutOfZone,
                                  guardName: l.guardName,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_tilesFailed)
            SliverToBoxAdapter(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: tokens.warningSoft,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: tokens.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Map tiles unavailable. Guard locations still updating.',
                        style: TextStyle(
                            fontSize: 12, color: tokens.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: PortalSectionHeading(
                      title: 'Active Guards (${filtered.length})',
                    ),
                  ),
                  if (outOfZone > 0)
                    StatusChip(
                      label: '$outOfZone outside zone',
                      tone: StatusChipTone.danger,
                    ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                child: StateBlock(
                  icon: Icons.location_off_outlined,
                  title: 'No active guards',
                  message:
                      'No guards are currently clocked in. Live locations will appear here once guards check in.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _GuardLocationCard(
                    data: filtered[index],
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuardMapMarker extends StatelessWidget {
  const _GuardMapMarker({
    required this.isOutOfZone,
    required this.guardName,
  });

  final bool isOutOfZone;
  final String guardName;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final color = isOutOfZone ? tokens.danger : tokens.success;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            guardName.isNotEmpty
                ? guardName.split(' ').first
                : 'Guard',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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

class _GuardLocationCard extends StatelessWidget {
  const _GuardLocationCard({required this.data});

  final GuardLocationData data;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final isOut = data.isOutOfZone && data.status == 'In';
    final accent = isOut ? tokens.danger : tokens.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        accentColor: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.guardName.isEmpty ? 'Unknown Guard' : data.guardName,
                    style: GoogleFonts.roboto(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                ),
                StatusChip(
                  label: isOut ? 'OUT OF ZONE' : 'IN ZONE',
                  tone: isOut ? StatusChipTone.danger : StatusChipTone.success,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _metaRow(
                    context,
                    tokens,
                    Icons.place_outlined,
                    data.siteName.isEmpty ? 'Unknown site' : data.siteName,
                  ),
                ),
                if (data.siteLat != null &&
                    data.siteLng != null &&
                    data.lat != 0 &&
                    data.lng != 0) ...[
                  _metaRow(
                    context,
                    tokens,
                    Icons.social_distance_outlined,
                    '${_distanceFromSite().toStringAsFixed(0)}m',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _metaRow(
                    context,
                    tokens,
                    Icons.business_outlined,
                    data.clientName.isEmpty ? '—' : data.clientName,
                  ),
                ),
                _metaRow(
                  context,
                  tokens,
                  Icons.schedule_outlined,
                  _formatSince(data.updatedAt),
                ),
              ],
            ),
            if (isOut && data.geofenceRadius != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.dangerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Guard is ${_distanceFromSite().toStringAsFixed(0)}m from site '
                  '(radius: ${data.geofenceRadius!.toStringAsFixed(0)}m)',
                  style: TextStyle(
                    color: tokens.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _distanceFromSite() {
    if (data.siteLat == null || data.siteLng == null) return 0;
    const r = 6371000;
    final dLat = (data.lat - data.siteLat!) * math.pi / 180;
    final dLng = (data.lng - data.siteLng!) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(data.siteLat! * math.pi / 180) *
            math.cos(data.lat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _formatSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _metaRow(BuildContext context, CissThemeTokens tokens, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tokens.inkMuted),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.inkMuted,
              ),
        ),
      ],
    );
  }
}
