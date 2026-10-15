import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android tracking contract', () {
    late String manifest;
    late String trackingService;
    late String deviceCompat;

    setUpAll(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      trackingService =
          File(
            'lib/core/location/background_tracking_service.dart',
          ).readAsStringSync();
      deviceCompat =
          File(
            'lib/core/location/device_compat_service.dart',
          ).readAsStringSync();
    });

    test('uses a non-exported user-visible foreground service', () {
      // Background location is declared deliberately: tracking runs on a
      // user-visible foreground service, and the permission covers the restart
      // gap after a swipe-away or reboot, when the watchdog/boot receivers
      // bring the service back before the app is visible again.
      expect(
        manifest,
        contains('android.permission.ACCESS_BACKGROUND_LOCATION'),
      );
      // The direct battery-exemption dialog needs a Play-restricted permission
      // and is deliberately not used. The app instead opens the battery
      // settings page through the native device-compat channel, which is what
      // this assertion protects.
      expect(
        manifest,
        isNot(
          contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
        ),
      );
      expect(
        deviceCompat,
        contains('openBatteryOptimizationSettings'),
        reason: 'battery guidance must stay available without the permission',
      );
      expect(deviceCompat, contains('openBrandAutostartSettings'));
      expect(
        RegExp(
          r'<service[\s\S]*?flutter_background_service\.BackgroundService'
          r'[\s\S]*?android:exported="false"[\s\S]*?/>',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test('ships the background-tracking disclosure in every language', () {
      for (final language in AppLanguage.values) {
        final strings = AppStrings.forLanguage(language);
        expect(
          strings.readinessBackgroundLocationWhy.trim(),
          isNotEmpty,
          reason: '${language.code} must explain why background location is used',
        );
        expect(
          strings.readinessBatteryWhy.trim(),
          isNotEmpty,
          reason: '${language.code} must explain the battery settings step',
        );
      }
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

    test(
      'guard login does not preflight the enumeration-prone PIN status API',
      () {
        final repository =
            File('lib/core/network/mobile_repository.dart').readAsStringSync();
        final controller =
            File(
              'lib/features/auth/application/auth_controller.dart',
            ).readAsStringSync();
        final loginScreen =
            File(
              'lib/features/auth/presentation/role_login_screen.dart',
            ).readAsStringSync();

        expect(repository, isNot(contains('/api/guard/auth/pin-status')));
        expect(controller, isNot(contains('checkGuardPinStatus')));
        expect(loginScreen, isNot(contains('checkGuardPinStatus')));
        expect(loginScreen, contains('Unable to sign in with those details.'));
        expect(loginScreen, contains('Set up PIN for first-time login'));
      },
    );

    test(
      'public attendance uses the signed backend identification contract',
      () {
        final repository =
            File('lib/core/network/mobile_repository.dart').readAsStringSync();
        final qrFlow =
            File(
              'lib/features/attendance_qr/qr_attendance_flow.dart',
            ).readAsStringSync();
        final publicFlow =
            File(
              'lib/features/attendance_public/public_attendance_screen.dart',
            ).readAsStringSync();

        expect(repository, contains('/api/public/attendance/identify'));
        expect(repository, isNot(contains('/api/public/attendance/employee')));
        expect(repository, contains('attendanceVerificationToken'));
        expect(qrFlow, contains('fetchAttendanceEmployeeByQr'));
        expect(qrFlow, contains('locationCapturedAt'));
        expect(qrFlow, contains('photoStoragePath'));
        expect(qrFlow, contains('attendanceAttemptId'));
        expect(publicFlow, contains('sourceCollection'));
        expect(publicFlow, contains('locationCapturedAt'));
        expect(publicFlow, contains('photoStoragePath'));
        expect(publicFlow, contains('attendanceAttemptId'));
      },
    );

    test(
      'field-officer patrol route is shared with scoped backend authorization',
      () {
        final repository =
            File('lib/core/network/mobile_repository.dart').readAsStringSync();
        final parentRoute =
            File(
              '../CISS/src/app/api/admin/patrol-activities/route.ts',
            ).readAsStringSync();

        expect(repository, contains("'/api/admin/patrol-activities'"));
        expect(parentRoute, contains('requireActiveFieldOfficerProfile'));
        expect(parentRoute, contains('districtMatches'));
        expect(parentRoute, contains('getAssignedDistricts'));
        expect(parentRoute, isNot(contains('requireAdmin(request)')));
      },
    );

    test('guard attendance range uses the single aggregated endpoint', () {
      final repository =
          File('lib/core/network/mobile_repository.dart').readAsStringSync();
      expect(repository, contains("/api/field-officer/guard-attendance/range"));
      expect(repository, isNot(contains('days.length < 62')));
      expect(repository, isNot(contains('offset += 6')));
    });
  });

  group('Guard document upload contract', () {
    final repository =
        File('lib/core/network/mobile_repository.dart').readAsStringSync();

    test('uses the documented document upload endpoint', () {
      expect(repository, contains("/api/guard/profile/documents"));
      expect(
        repository,
        isNot(contains('/api/guard/profile/documents/upload/')),
      );
    });

    test('submits Aadhaar consent version and fields before upload', () {
      expect(repository, contains("consentAccepted"));
      expect(repository, contains("consentVersion"));
      expect(repository, contains("aadhaarNumber"));
      expect(repository, contains("aadhaar-esic-epf-v1"));
      expect(repository, contains("category"));
    });

    test('aadhaar correction uses the supported endpoint with a reason', () {
      expect(repository, contains("/api/guard/profile/aadhaar-correction"));
      expect(repository, contains("{'reason': reason}"));
    });
  });

  group('Guard training leaderboard contract', () {
    test('uses the supported guard leaderboard endpoint', () {
      final repository =
          File('lib/core/network/mobile_repository.dart').readAsStringSync();
      expect(repository, contains("'/api/guard/leaderboard'"));
    });

    test('training and evaluations retain leaderboard links', () {
      for (final path in <String>[
        'lib/features/guard/presentation/screens/guard_training_screen.dart',
        'lib/features/guard/presentation/screens/guard_evaluations_screen.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('GuardTrainingLeaderboardScreen'),
        );
      }
    });
  });

  group('Guard upload UI wiring', () {
    final profileScreen =
        File(
          'lib/features/guard/presentation/screens/guard_profile_screen.dart',
        ).readAsStringSync();

    test('profile exposes upload + correction entries', () {
      expect(profileScreen, contains('GuardDocumentUploadScreen'));
      expect(profileScreen, contains('GuardAadhaarCorrectionScreen'));
      expect(profileScreen, contains("profile.anyMissingDocuments"));
    });
  });
}
