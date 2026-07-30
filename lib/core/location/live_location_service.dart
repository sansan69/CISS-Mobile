import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../region/region_service.dart';

// Firestore collection: guardLocations/{employeeDocId}
// Document ID is the employeeDocId (Firestore doc ID, no slashes).
// Shared real-time layer for Flutter FO app + Next.js admin/client dashboards.

class GuardLocationData {
  const GuardLocationData({
    required this.employeeDocId,
    required this.employeeId,
    required this.guardName,
    required this.siteId,
    required this.siteName,
    required this.clientName,
    required this.district,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.isOutOfZone,
    required this.status,
    required this.updatedAt,
    this.attendanceId,
    this.siteLat,
    this.siteLng,
    this.geofenceRadius,
  });

  /// Firestore doc ID (no slashes)
  final String employeeDocId;

  /// Employee code (e.g. CISS/TCS/2025-26/871)
  final String employeeId;
  final String guardName;
  final String siteId;
  final String siteName;
  final String clientName;
  final String district;
  final double lat;
  final double lng;
  final double accuracy;
  final bool isOutOfZone;
  final String status; // 'In' | 'Out'
  final DateTime updatedAt;
  final String? attendanceId;
  final double? siteLat;
  final double? siteLng;
  final double? geofenceRadius;

  /// Returns null if the document has no data (e.g. race during concurrent
  /// delete). Callers must handle null.
  static GuardLocationData? tryFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    if (d == null || !doc.exists) return null;
    return _buildFromData(doc.id, d);
  }

  factory GuardLocationData.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    if (d == null) {
      return GuardLocationData(
        employeeDocId: doc.id,
        employeeId: '',
        guardName: '',
        siteId: '',
        siteName: '',
        clientName: '',
        district: '',
        lat: 0,
        lng: 0,
        accuracy: 0,
        isOutOfZone: false,
        status: 'Out',
        updatedAt: DateTime.now(),
      );
    }
    return _buildFromData(doc.id, d);
  }

  static GuardLocationData _buildFromData(String id, Map<String, dynamic> d) {
    return GuardLocationData(
      employeeDocId: id,
      employeeId: (d['employeeId'] as String?) ?? '',
      guardName: (d['guardName'] as String?) ?? '',
      siteId: (d['siteId'] as String?) ?? '',
      siteName: (d['siteName'] as String?) ?? '',
      clientName: (d['clientName'] as String?) ?? '',
      district: (d['district'] as String?) ?? '',
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      accuracy: (d['accuracy'] as num?)?.toDouble() ?? 0,
      isOutOfZone: d['isOutOfZone'] == true,
      status: (d['status'] as String?) ?? 'Out',
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attendanceId: d['attendanceId'] as String?,
      siteLat: (d['siteLat'] as num?)?.toDouble(),
      siteLng: (d['siteLng'] as num?)?.toDouble(),
      geofenceRadius: (d['geofenceRadius'] as num?)?.toDouble(),
    );
  }
}

class LiveLocationService {
  LiveLocationService([FirebaseFirestore? firestore])
    : _firestore = firestore ?? RegionService.instance.activeFirestore;

  final FirebaseFirestore _firestore;

  static const String collection = 'guardLocations';

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Stream all guards currently clocked IN. Used by FO attendance tab.
  Stream<List<GuardLocationData>> streamActiveLocations({String? district}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collection)
        .where('status', isEqualTo: 'In');

    if (district != null && district.trim().isNotEmpty) {
      query = query.where('district', isEqualTo: district.trim());
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((d) => GuardLocationData.tryFromFirestore(d))
              .whereType<GuardLocationData>()
              .toList(),
    );
  }

  /// Stream a single guard's location. Used by the guard detail screen.
  Stream<GuardLocationData?> streamGuardLocation(String employeeDocId) {
    return _firestore
        .collection(collection)
        .doc(employeeDocId)
        .snapshots()
        .map((doc) => GuardLocationData.tryFromFirestore(doc));
  }

  /// One-shot fetch of all active locations. Used by Next.js dashboards
  /// as a fallback (they should prefer streaming).
  Future<List<GuardLocationData>> fetchActiveLocations({
    String? district,
    String? clientName,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collection)
        .where('status', isEqualTo: 'In');

    if (district != null && district.trim().isNotEmpty) {
      query = query.where('district', isEqualTo: district.trim());
    }
    if (clientName != null && clientName.trim().isNotEmpty) {
      query = query.where('clientName', isEqualTo: clientName.trim());
    }

    final snap = await query.get();
    return snap.docs.map((d) => GuardLocationData.fromFirestore(d)).toList();
  }
}

final liveLocationServiceProvider = Provider<LiveLocationService>(
  (ref) => LiveLocationService(),
);
