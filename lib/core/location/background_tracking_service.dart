import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../network/mobile_repository.dart';
import '../region/region_service.dart';
import 'tracking_session_store.dart';

/// Background location tracking service optimized for CISS guard duty.
///
/// Handles all site types including buildings, offices, yards, godowns,
/// warehouses, factories, and vast land. Uses hybrid indoor/outdoor
/// positioning with network fallback for poor-GPS environments.
class BackgroundTrackingService {
  static bool _configured = false;
  static const TrackingSessionStore _sessionStore = TrackingSessionStore();

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
      debugPrint(
        'BackgroundTracking: location permission not granted ($locStatus)',
      );
      return;
    }

    final service = FlutterBackgroundService();
    final activeRegion = RegionService.instance.activeRegion;
    final context = <String, dynamic>{
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
    };
    await _sessionStore.save(context);
    await service.startService();
    service.invoke('set_site_context', context);
  }

  static Future<void> stop() async {
    await _sessionStore.clear();
    FlutterBackgroundService().invoke('stopService');
  }

  static Future<void> reconcileWithServer(MobileRepository repository) async {
    final status = await repository.fetchGuardTrackingStatus();
    if (status['isClockedIn'] != true) {
      await stop();
      return;
    }

    final siteId = status['siteId'] as String?;
    if (siteId == null || siteId.isEmpty) return;

    final saved = await _sessionStore.load();
    if (saved != null && saved['siteId'] == siteId) {
      await _restartFromSavedContext(saved);
      return;
    }

    final profile = await repository.fetchGuardProfile();
    final sites = await repository.fetchAttendanceSites();
    final matches = sites.where((site) => site.id == siteId);
    if (matches.isEmpty) return;
    final site = matches.first;
    if (site.lat == null || site.lng == null) return;

    await start(
      siteId: site.id,
      siteName: site.siteName,
      lat: site.lat!,
      lng: site.lng!,
      radiusMeters: site.geofenceRadiusMeters.toDouble(),
      employeeId: profile.employeeId,
      employeeDocId: profile.id,
      guardName: profile.fullName,
      clientName: profile.clientName,
      district: profile.district,
    );
  }

  static Future<void> _restartFromSavedContext(
    Map<String, dynamic> saved,
  ) async {
    final service = FlutterBackgroundService();
    await service.startService();
    service.invoke('set_site_context', saved);
  }
}

// ── Background isolate entry point ──────────────────────────────────────────

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Catch isolate-level errors and forward to Crashlytics
  Isolate.current.addErrorListener(
    RawReceivePort((dynamic errorAndStack) {
      if (errorAndStack is List && errorAndStack.length == 2) {
        FirebaseCrashlytics.instance.recordError(
          errorAndStack[0],
          errorAndStack[1] as StackTrace?,
          fatal: true,
        );
      }
    }).sendPort,
  );

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Background Firebase init error: $e');
  }

  Map<String, dynamic>? siteContext = await const TrackingSessionStore().load();
  FirebaseAuth activeAuth = FirebaseAuth.instance;
  bool isInside = true; // Assume inside until first check proves otherwise
  bool firstReading = true;
  DateTime? lastOutsideAt;

  if (siteContext != null) {
    activeAuth = await _configureBackgroundRegion(siteContext);
  }

  if (service is AndroidServiceInstance) {
    service.on('set_site_context').listen((event) {
      siteContext = event;
      isInside = true;
      firstReading = true;
      lastOutsideAt = null;
      _configureBackgroundRegion(event).then((auth) {
        activeAuth = auth;
      });
    });

    service.on('stopService').listen((_) {
      service.stopSelf();
    });
  }

  Future<void> sendHeartbeat() async {
    if (siteContext == null) return;

    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) return;
    }

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
        _updateNotification(
          service,
          siteContext,
          isInside,
          'Location unavailable — checking again shortly',
        );
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
      final accuracyBuffer =
          (accuracy != null && accuracy > 30.0) ? accuracy / 2 : 0.0;
      final effectiveRadius = radius + accuracyBuffer;
      final isOut = distance > effectiveRadius;

      // ── State machine for entry/exit detection ───────────────────────────
      // First reading: set isInside based on actual position, not assumption
      // (must happen every heartbeat cycle, not just on init)
      if (firstReading) {
        firstReading = false;
        isInside = !isOut;
        lastOutsideAt = isOut ? DateTime.now() : null;
      } else if (!isOut && !isInside) {
        // Guard re-entered site — reset exit counter
        isInside = true;
        lastOutsideAt = null;
      } else if (isOut && isInside) {
        // Guard may have left — require 2 consecutive outs to avoid GPS glitches
        if (lastOutsideAt != null &&
            DateTime.now().difference(lastOutsideAt!).inMinutes < 6) {
          isInside = false;
          lastOutsideAt = null;
        } else {
          // First consecutive out — start the 6-minute window
          lastOutsideAt = DateTime.now();
        }
      }

      // ── Heartbeat upload ──────────────────────────────────────────────────
      final baseUrl =
          (siteContext?['apiUrl'] as String?) ??
          const String.fromEnvironment(
            'CISS_API_BASE_URL',
            defaultValue: 'https://cisskerala.site',
          );

      final user = activeAuth.currentUser;
      String? token = await user?.getIdToken(false);
      var heartbeatSucceeded = false;

      try {
        http.Response response = await http
            .post(
              Uri.parse('$baseUrl/api/guard/tracking/heartbeat'),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'siteId': siteContext!['siteId'],
                'lat': position.latitude,
                'lng': position.longitude,
                'accuracy': accuracy,
                'batteryLevel': null,
                'speed': position.speed >= 0 ? position.speed : null,
                'capturedAt': DateTime.now().toUtc().toIso8601String(),
              }),
            )
            .timeout(const Duration(seconds: 15));

        // Retry with fresh token on 401
        if (response.statusCode == 401) {
          token = await user?.getIdToken(true);
          if (token != null) {
            response = await http
                .post(
                  Uri.parse('$baseUrl/api/guard/tracking/heartbeat'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'siteId': siteContext!['siteId'],
                    'lat': position.latitude,
                    'lng': position.longitude,
                    'accuracy': accuracy,
                    'batteryLevel': null,
                    'speed': position.speed >= 0 ? position.speed : null,
                    'capturedAt': DateTime.now().toUtc().toIso8601String(),
                  }),
                )
                .timeout(const Duration(seconds: 15));
          }
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          heartbeatSucceeded = true;
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          final zoneStatus = responseData['zoneStatus'] as String?;
          if (zoneStatus == 'in_zone') {
            isInside = true;
          } else if (zoneStatus == 'out_of_zone') {
            isInside = false;
          }
        } else if (response.statusCode == 403 || response.statusCode == 409) {
          _updateNotification(
            service,
            siteContext,
            isInside,
            'Duty session closed — tracking stopped',
          );
          if (service is AndroidServiceInstance) {
            await const TrackingSessionStore().clear();
            await service.stopSelf();
          }
          return;
        } else {
          _updateNotification(
            service,
            siteContext,
            isInside,
            'Location update delayed — retrying',
          );
        }
      } catch (httpErr) {
        debugPrint('Heartbeat upload error (will retry next cycle): $httpErr');
        _updateNotification(
          service,
          siteContext,
          isInside,
          'Location update delayed — retrying',
        );
      }

      if (heartbeatSucceeded) {
        _updateNotification(service, siteContext, isInside, null);
      }

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
  }

  // Send a reading as soon as a shift starts or is recovered, then maintain
  // the three-minute heartbeat expected by the live operations dashboard.
  unawaited(sendHeartbeat());
  Timer.periodic(const Duration(minutes: 3), (_) => unawaited(sendHeartbeat()));
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Future<FirebaseAuth> _configureBackgroundRegion(
  Map<String, dynamic>? context,
) async {
  final code = context?['regionCode'] as String?;
  final rawConfig = context?['regionConfig'];
  if (code == null || code == 'KL' || rawConfig is! Map) {
    return FirebaseAuth.instance;
  }

  try {
    final region = RegionInfo.fromJson(Map<String, dynamic>.from(rawConfig));
    final appName = 'region_${region.code}';
    FirebaseApp app;
    try {
      app = Firebase.app(appName);
    } catch (_) {
      final options =
          region.androidConfig?.toFirebaseOptions() ??
          region.webConfig?.toFirebaseOptions();
      if (options == null) {
        return FirebaseAuth.instance;
      }
      app = await Firebase.initializeApp(name: appName, options: options);
    }
    return FirebaseAuth.instanceFor(app: app);
  } catch (error) {
    debugPrint('Background region init failed: $error');
    return FirebaseAuth.instance;
  }
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
  final content =
      overrideContent ??
      (isInside
          ? 'On-site monitoring active'
          : 'WARNING: Outside site boundary!');

  service.setForegroundNotificationInfo(title: title, content: content);
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
