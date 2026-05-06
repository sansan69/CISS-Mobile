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

class BackgroundTrackingService {
  static bool _configured = false;

  static Future<void> initialize() async {
    // Idempotent: only configure once per process lifecycle.
    if (_configured) return;
    _configured = true;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        // Channel must already exist by the time the service calls startForeground().
        // It is created in MainActivity.kt before Flutter boots.
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
    });
  }

  static void stop() {
    FlutterBackgroundService().invoke('stopService');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Firebase for the background isolate
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Background Firebase init error: $e');
  }

  Map<String, dynamic>? siteContext;

  if (service is AndroidServiceInstance) {
    service.on('set_site_context').listen((event) {
      siteContext = event;
    });

    service.on('stopService').listen((_) {
      service.stopSelf();
    });
  }

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (siteContext == null) return;

    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) return;
    }

    try {
      final lat = siteContext!['lat'] as num?;
      final lng = siteContext!['lng'] as num?;
      final radius = siteContext!['radius'] as num?;
      
      if (lat == null || lng == null || radius == null) {
        debugPrint('BackgroundTracking: missing coordinates or radius');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final distance = Geolocator.distanceBetween(
        lat.toDouble(),
        lng.toDouble(),
        position.latitude,
        position.longitude,
      );

      final isOut = distance > radius.toDouble();

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
          'accuracy': position.accuracy,
          'distanceFromSite': distance,
          'isOutOfZone': isOut,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // ── Firestore live location update ──────────────────────────────────
      try {
        await FirebaseFirestore.instance
            .collection('guardLocations')
            .doc(siteContext!['employeeId'] as String)
            .update({
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'isOutOfZone': isOut,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (fsErr) {
        debugPrint('Firestore location update error: $fsErr');
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'CISS Active Duty: ${siteContext!['siteName']}',
          content: isOut
              ? 'WARNING: Outside site boundary!'
              : 'On-site monitoring active.',
        );
      }

      debugPrint(
        'Tracking: ${position.latitude}, ${position.longitude} — out: $isOut',
      );
    } catch (e) {
      debugPrint('BackgroundTracking error: $e');
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
