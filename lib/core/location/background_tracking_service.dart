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
import 'package:permission_handler/permission_handler.dart';

import '../region/region_service.dart';

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

  static Future<void> start({
    required String siteId,
    required String siteName,
    required double lat,
    required double lng,
    required double radiusMeters,
    required String employeeId,
    String? employeeDocId,
    String? guardName,
    String? clientName,
    String? district,
  }) async {
    // Verify location permission before starting
    final locStatus = await Permission.location.status;
    if (locStatus != PermissionStatus.granted &&
        locStatus != PermissionStatus.limited) {
      debugPrint('BackgroundTracking: location permission not granted ($locStatus)');
      return;
    }

    // Request battery optimization exemption (best-effort, Android only)
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (batteryStatus != PermissionStatus.granted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {
      debugPrint('BackgroundTracking: battery optimization request not supported on this platform');
    }

    final service = FlutterBackgroundService();
    final activeRegion = RegionService.instance.activeRegion;
    service.startService();
    service.invoke('set_site_context', {
      'siteId': siteId,
      'siteName': siteName,
      'lat': lat,
      'lng': lng,
      'radius': radiusMeters,
      'employeeId': employeeId,
      'employeeDocId': employeeDocId ?? employeeId,
      'guardName': guardName ?? '',
      'clientName': clientName ?? '',
      'district': district ?? '',
      'regionCode': activeRegion?.code ?? 'KL',
      'apiUrl': activeRegion?.apiUrl ?? 'https://cisskerala.site',
      if (activeRegion != null) 'regionConfig': activeRegion.toJson(),
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
  FirebaseAuth activeAuth = FirebaseAuth.instance;
  FirebaseFirestore activeFirestore = FirebaseFirestore.instance;
  bool isInside = true; // Assume inside until first check proves otherwise
  DateTime? lastOutsideAt;
  int heartbeatCount = 0;

  if (service is AndroidServiceInstance) {
    service.on('set_site_context').listen((event) {
      siteContext = event;
      isInside = true;
      heartbeatCount = 0;
      _configureBackgroundRegion(event).then((instances) {
        activeAuth = instances.$1;
        activeFirestore = instances.$2;
      });
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
      final baseUrl = (siteContext?['apiUrl'] as String?) ??
          const String.fromEnvironment(
            'CISS_API_BASE_URL',
            defaultValue: 'https://cisskerala.site',
          );

      final user = activeAuth.currentUser;
      String? token = await user?.getIdToken(false);

      try {
        final response = await http.post(
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
            'batteryLevel': null,
            'heartbeatCount': heartbeatCount,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 15));

        // Retry with fresh token on 401
        if (response.statusCode == 401) {
          token = await user?.getIdToken(true);
          if (token != null) {
            await http.post(
              Uri.parse('$baseUrl/api/guard/tracking/heartbeat'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
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
            ).timeout(const Duration(seconds: 15));
          }
        }
      } catch (httpErr) {
        debugPrint('Heartbeat upload error (will retry next cycle): $httpErr');
      }

      // ── Firestore live location update (with retry) ──────────────────────
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final employeeDocId = siteContext!['employeeDocId'] as String? ?? siteContext!['employeeId'] as String;
          final employeeId = siteContext!['employeeId'] as String? ?? '';
          await activeFirestore
              .collection('guardLocations')
              .doc(employeeDocId)
              .set({
            'employeeDocId': employeeDocId,
            'employeeId': employeeId,
            'guardName': siteContext!['guardName'] ?? employeeId,
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
          break; // Success — exit retry loop
        } catch (fsErr) {
          if (attempt < 2) {
            await Future<void>.delayed(const Duration(seconds: 1));
          } else {
            debugPrint('Firestore location update failed after retries: $fsErr');
          }
        }
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

      // Store movement trace in Firestore subcollection (with retry)
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final traceRef = activeFirestore
              .collection('guardLocations')
              .doc(siteContext!['employeeDocId'] as String? ?? siteContext!['employeeId'] as String)
              .collection('locationHistory')
              .doc();
          await traceRef.set({
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy': position.accuracy,
            'distanceFromSite': distance,
            'timestamp': FieldValue.serverTimestamp(),
          });
          break;
        } catch (e) {
          if (attempt < 2) {
            await Future<void>.delayed(const Duration(seconds: 1));
          } else {
            debugPrint('Movement trace write error after retries: $e');
          }
        }
      }
    } catch (e) {
      // Silent fail for fast check — primary heartbeat handles errors
    }
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Future<(FirebaseAuth, FirebaseFirestore)> _configureBackgroundRegion(
  Map<String, dynamic>? context,
) async {
  final code = context?['regionCode'] as String?;
  final rawConfig = context?['regionConfig'];
  if (code == null || code == 'KL' || rawConfig is! Map) {
    return (FirebaseAuth.instance, FirebaseFirestore.instance);
  }

  try {
    final region = RegionInfo.fromJson(Map<String, dynamic>.from(rawConfig));
    final appName = 'region_${region.code}';
    FirebaseApp app;
    try {
      app = Firebase.app(appName);
    } catch (_) {
      final options = region.androidConfig?.toFirebaseOptions() ??
          region.webConfig?.toFirebaseOptions();
      if (options == null) {
        return (FirebaseAuth.instance, FirebaseFirestore.instance);
      }
      app = await Firebase.initializeApp(name: appName, options: options);
    }
    return (
      FirebaseAuth.instanceFor(app: app),
      FirebaseFirestore.instanceFor(app: app),
    );
  } catch (error) {
    debugPrint('Background region init failed: $error');
    return (FirebaseAuth.instance, FirebaseFirestore.instance);
  }
}

Future<FirebaseAuth> _authForSiteContext(Map<String, dynamic> siteContext) async {
  final instances = await _configureBackgroundRegion(siteContext);
  return instances.$1;
}

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
  final baseUrl = (siteContext['apiUrl'] as String?) ??
      const String.fromEnvironment(
        'CISS_API_BASE_URL',
        defaultValue: 'https://cisskerala.site',
      );

  final user = (await _authForSiteContext(siteContext)).currentUser;
  String? token = await user?.getIdToken(false);

  try {
    final response = await http.post(
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
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      token = await user?.getIdToken(true);
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/api/guard/tracking/geofence-event'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'employeeId': siteContext['employeeId'],
            'siteId': siteContext['siteId'],
            'eventType': eventType,
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy': accuracy,
            'distanceFromSite': distance,
            'locationSource': locationSource,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 15));
      }
    }
  } catch (httpErr) {
    debugPrint('Geofence event HTTP error: $httpErr');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
