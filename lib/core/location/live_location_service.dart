import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Firestore collection: guardLocations/{employeeId}
// Shared real-time layer for Flutter FO app + Next.js admin/client dashboards.

class GuardLocationData {
  const GuardLocationData({
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

  factory GuardLocationData.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return GuardLocationData(
      employeeId: (d['employeeId'] as String?) ?? doc.id,
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

  Map<String, dynamic> toFirestore() => {
    'employeeId': employeeId,
    'guardName': guardName,
    'siteId': siteId,
    'siteName': siteName,
    'clientName': clientName,
    'district': district,
    'lat': lat,
    'lng': lng,
    'accuracy': accuracy,
    'isOutOfZone': isOutOfZone,
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
    if (attendanceId != null) 'attendanceId': attendanceId,
    if (siteLat != null) 'siteLat': siteLat,
    if (siteLng != null) 'siteLng': siteLng,
    if (geofenceRadius != null) 'geofenceRadius': geofenceRadius,
  };
}

class LiveLocationService {
  LiveLocationService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'guardLocations';

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Called when a guard marks IN or during heartbeat updates.
  Future<void> setLocation(GuardLocationData data) async {
    await _firestore
        .collection(collection)
        .doc(data.employeeId)
        .set(data.toFirestore(), SetOptions(merge: true));
  }

  /// Called when a guard marks OUT — clears location but keeps the doc for
  /// the shared status flag.
  Future<void> markOut(String employeeId) async {
    await _firestore.collection(collection).doc(employeeId).update({
      'status': 'Out',
      'lat': 0,
      'lng': 0,
      'isOutOfZone': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove the document entirely (e.g. guard logs out or data stale).
  Future<void> remove(String employeeId) async {
    await _firestore.collection(collection).doc(employeeId).delete();
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Stream all guards currently clocked IN. Used by FO attendance tab.
  Stream<List<GuardLocationData>> streamActiveLocations({
    String? district,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collection)
        .where('status', isEqualTo: 'In');

    if (district != null && district.trim().isNotEmpty) {
      query = query.where('district', isEqualTo: district.trim());
    }

    return query.snapshots().map((snap) =>
        snap.docs.map((d) => GuardLocationData.fromFirestore(d)).toList());
  }

  /// Stream a single guard's location. Used by the guard detail screen.
  Stream<GuardLocationData?> streamGuardLocation(String employeeId) {
    return _firestore
        .collection(collection)
        .doc(employeeId)
        .snapshots()
        .map((doc) =>
            doc.exists ? GuardLocationData.fromFirestore(doc) : null);
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
    return snap.docs
        .map((d) => GuardLocationData.fromFirestore(d))
        .toList();
  }
}

final liveLocationServiceProvider = Provider<LiveLocationService>(
  (ref) => LiveLocationService(),
);
