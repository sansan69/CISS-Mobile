import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Background location tracking service optimized for CISS guard duty.
///
/// Handles all site types including buildings, offices, yards, godowns,
/// warehouses, factories, and vast land. Uses hybrid indoor/outdoor
/// positioning with network fallback for poor-GPS environments.
class BackgroundTrackingService {
  static bool _configured = false;

  static Future<void> initialize() async {
    if (_configured) return;
    _configured = true;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'ciss_tracking',
        initialNotificationTitle: 'CISS Active Duty',
        initialNotificationContent: 'Location monitoring active.',
        foregroundServiceNotificationId: 1001,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static void start({
    required String siteId,
    required String siteName,
    required double lat,
    required double lng,
    required double radiusMeters,
    required String employeeId,
    String? clientName,
    String? district,
  }) {
    final service = FlutterBackgroundService();
    service.startService();
    service.invoke('set_site_context', {
      'siteId': siteId,
      'siteName': siteName,
      'lat': lat,
      'lng': lng,
      'radius': radiusMeters,
      'employeeId': employeeId,
      'clientName': clientName ?? '',
      'district': district ?? '',
    });
  }

  static void stop() {
    FlutterBackgroundService().invoke('stopService');
  }
}

// ── Background isolate entry point ──────────────────────────────────────────

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Background Firebase init error: $e');
  }

  Map<String, dynamic>? siteContext;
  bool isInside = true; // Assume inside until first check proves otherwise
  DateTime? lastOutsideAt;
  int heartbeatCount = 0;

  if (service is AndroidServiceInstance) {
    service.on('set_site_context').listen((event) {
      siteContext = event;
      isInside = true;
      heartbeatCount = 0;
    });

    service.on('stopService').listen((_) {
      service.stopSelf();
    });
  }

  // Primary heartbeat: every 3 minutes (more responsive than 5 min)
  Timer.periodic(const Duration(minutes: 3), (timer) async {
    if (siteContext == null) return;

    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) return;
    }

    heartbeatCount++;

    try {
      final siteLat = (siteContext!['lat'] as num?)?.toDouble();
      final siteLng = (siteContext!['lng'] as num?)?.toDouble();
      final radius = (siteContext!['radius'] as num?)?.toDouble();

      if (siteLat == null || siteLng == null || radius == null) {
        debugPrint('BackgroundTracking: missing coordinates or radius');
        return;
      }

      // ── Hybrid indoor/outdoor positioning ────────────────────────────────
      Position? position;
      double? accuracy;
      String locationSource = 'unknown';

      // Attempt 1: High accuracy GPS (best for outdoor: yards, vast land)
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 8),
          ),
        );
        accuracy = position.accuracy;
        locationSource = 'gps';
      } catch (e) {
        debugPrint('GPS positioning failed (indoor/weak signal): $e');
      }

      // Attempt 2: Network-based positioning (WiFi/cell towers) for indoor
      // buildings, warehouses, factories, godowns where GPS is unreliable
      if (position == null || (accuracy != null && accuracy > 50)) {
        try {
          final networkPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          );
          // Use network only if it's better than GPS, or GPS failed
          if (position == null ||
              networkPos.accuracy < (position.accuracy * 1.5)) {
            position = networkPos;
            accuracy = networkPos.accuracy;
            locationSource = 'network';
          }
        } catch (e) {
          debugPrint('Network positioning also failed: $e');
        }
      }

      // Attempt 3: Last known position as absolute fallback
      if (position == null) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          position = lastKnown;
          accuracy = lastKnown.accuracy;
          locationSource = 'last_known';
        }
      }

      if (position == null) {
        debugPrint('BackgroundTracking: no position available');
        _updateNotification(service, siteContext, isInside,
            'Location unavailable — checking again shortly');
        return;
      }

      // ── Geofence calculation with accuracy buffer ────────────────────────
      final distance = Geolocator.distanceBetween(
        siteLat,
        siteLng,
        position.latitude,
        position.longitude,
      );

      // For indoor/warehouse/factory environments with poor accuracy,
      // add a buffer: if accuracy is >30m, don't flag as out until
      // distance exceeds radius + accuracy/2. This prevents false alarms
      // when GPS is bouncing inside a large warehouse.
      final accuracyBuffer = (accuracy != null && accuracy > 30.0)
          ? accuracy / 2
          : 0.0;
      final effectiveRadius = radius + accuracyBuffer;
      final isOut = distance > effectiveRadius;

      // ── State machine for entry/exit detection ───────────────────────────
      if (!isOut && !isInside) {
        // Guard re-entered site
        isInside = true;
        _sendGeofenceEvent(
          siteContext: siteContext!,
          eventType: 'enter',
          position: position,
          distance: distance,
          accuracy: accuracy,
          locationSource: locationSource,
        );
      } else if (isOut && isInside) {
        // Guard left site — require 2 consecutive outs to avoid GPS glitches
        if (lastOutsideAt != null &&
            DateTime.now().difference(lastOutsideAt!).inMinutes < 6) {
          isInside = false;
          _sendGeofenceEvent(
            siteContext: siteContext!,
            eventType: 'exit',
            position: position,
            distance: distance,
            accuracy: accuracy,
            locationSource: locationSource,
          );
        }
        lastOutsideAt = DateTime.now();
      }

      // ── Heartbeat upload ──────────────────────────────────────────────────
      final baseUrl = const String.fromEnvironment(
        'CISS_API_BASE_URL',
        defaultValue: 'https://cisskerala.site',
      );

      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(false);

      await http.post(
        Uri.parse('$baseUrl/api/guard/tracking/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'employeeId': siteContext!['employeeId'],
          'siteId': siteContext!['siteId'],
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': accuracy,
          'distanceFromSite': distance,
          'isOutOfZone': isOut,
          'locationSource': locationSource,
          'heartbeatCount': heartbeatCount,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // ── Firestore live location update ───────────────────────────────────
      try {
        final employeeId = siteContext!['employeeId'] as String;
        await FirebaseFirestore.instance
            .collection('guardLocations')
            .doc(employeeId)
            .set({
          'employeeId': employeeId,
          'guardName': siteContext!['guardName'] ?? '',
          'siteId': siteContext!['siteId'],
          'siteName': siteContext!['siteName'],
          'clientName': siteContext!['clientName'] ?? '',
          'district': siteContext!['district'] ?? '',
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': accuracy,
          'isOutOfZone': isOut,
          'locationSource': locationSource,
          'distanceFromSite': distance,
          'status': isInside ? 'In' : 'Out',
          'updatedAt': FieldValue.serverTimestamp(),
          'siteLat': siteLat,
          'siteLng': siteLng,
          'geofenceRadius': radius,
        }, SetOptions(merge: true));
      } catch (fsErr) {
        debugPrint('Firestore location update error: $fsErr');
      }

      // ── Notification update ────────────────────────────────────────────────
      _updateNotification(service, siteContext, isInside, null);

      debugPrint(
        'Tracking [$locationSource]: ${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)} '
        '— dist: ${distance.toStringAsFixed(1)}m '
        '— out: $isOut (buffer: ${accuracyBuffer.toStringAsFixed(1)}m)',
      );
    } catch (e) {
      debugPrint('BackgroundTracking error: $e');
      _updateNotification(
        service,
        siteContext,
        isInside,
        'Tracking error — will retry',
      );
    }
  });

  // Secondary: fast location check every 30s while inside, used for
  // patrol route detection and movement validation.
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (siteContext == null || !isInside) return;
    if (service is AndroidServiceInstance &&
        !(await service.isForegroundService())) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final siteLat = (siteContext!['lat'] as num?)?.toDouble();
      final siteLng = (siteContext!['lng'] as num?)?.toDouble();
      if (siteLat == null || siteLng == null) return;

      final distance = Geolocator.distanceBetween(
        siteLat,
        siteLng,
        position.latitude,
        position.longitude,
      );

      // Store movement trace in Firestore subcollection (lightweight)
      try {
        final traceRef = FirebaseFirestore.instance
            .collection('guardLocations')
            .doc(siteContext!['employeeId'] as String)
            .collection('movementTrace')
            .doc();
        await traceRef.set({
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'distanceFromSite': distance,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Movement trace write error: $e');
      }
    } catch (e) {
      // Silent fail for fast check — primary heartbeat handles errors
    }
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

void _updateNotification(
  ServiceInstance service,
  Map<String, dynamic>? siteContext,
  bool isInside,
  String? overrideContent,
) {
  if (service is! AndroidServiceInstance || siteContext == null) return;

  final siteName = siteContext['siteName'] as String? ?? 'Site';
  final title = 'CISS Active Duty: $siteName';
  final content = overrideContent ??
      (isInside
          ? 'On-site monitoring active'
          : 'WARNING: Outside site boundary!');

  service.setForegroundNotificationInfo(
    title: title,
    content: content,
  );
}

Future<void> _sendGeofenceEvent({
  required Map<String, dynamic> siteContext,
  required String eventType,
  required Position position,
  required double distance,
  required double? accuracy,
  required String locationSource,
}) async {
  final baseUrl = const String.fromEnvironment(
    'CISS_API_BASE_URL',
    defaultValue: 'https://cisskerala.site',
  );

  final user = FirebaseAuth.instance.currentUser;
  final token = await user?.getIdToken(false);

  await http.post(
    Uri.parse('$baseUrl/api/guard/tracking/geofence-event'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'employeeId': siteContext['employeeId'],
      'siteId': siteContext['siteId'],
      'eventType': eventType, // 'enter' | 'exit'
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': accuracy,
      'distanceFromSite': distance,
      'locationSource': locationSource,
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
