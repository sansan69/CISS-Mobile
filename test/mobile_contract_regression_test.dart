import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android tracking contract', () {
    late String manifest;
    late String trackingService;

    setUpAll(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      trackingService =
          File(
            'lib/core/location/background_tracking_service.dart',
          ).readAsStringSync();
    });

    test('uses a non-exported user-visible foreground service', () {
      expect(
        manifest,
        isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')),
      );
      expect(
        manifest,
        isNot(
          contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
        ),
      );
      expect(
        RegExp(
          r'<service[\s\S]*?flutter_background_service\.BackgroundService'
          r'[\s\S]*?android:exported="false"[\s\S]*?/>',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test('sends location only through the supported heartbeat API', () {
      expect(trackingService, contains('/api/guard/tracking/heartbeat'));
      expect(trackingService, isNot(contains("collection('guardLocations')")));
      expect(trackingService, isNot(contains("collection('locationHistory')")));
      expect(
        trackingService,
        isNot(contains('/api/guard/tracking/geofence-event')),
      );
    });

    test('persists active shift context and reconciles it after restart', () {
      expect(trackingService, contains('_sessionStore.save(context)'));
      expect(trackingService, contains('fetchGuardTrackingStatus()'));
      expect(trackingService, contains('_restartFromSavedContext(saved)'));
      expect(trackingService, contains('unawaited(sendHeartbeat())'));
    });
  });

  group('Mobile API route compatibility', () {
    test('leave queue uses the same supported route as online submission', () {
      final leaveScreen =
          File(
            'lib/features/guard/presentation/screens/guard_leave_screen.dart',
          ).readAsStringSync();
      expect(leaveScreen, contains("path: '/api/guard/leave'"));
      expect(leaveScreen, isNot(contains('/api/guard/leave/requests')));
    });

    test('forgot PIN no longer calls the removed self-service route', () {
      final repository =
          File('lib/core/network/mobile_repository.dart').readAsStringSync();
      final forgotPin =
          File(
            'lib/features/auth/presentation/guard_forgot_pin_screen.dart',
          ).readAsStringSync();
      expect(repository, isNot(contains('/api/public/guard/reset-pin')));
      expect(forgotPin, contains('administrator'));
    });
  });
}
