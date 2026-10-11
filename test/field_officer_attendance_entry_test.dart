import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses flag/evidence fields, defaults when absent', () {
    final e = FieldOfficerAttendanceEntry.fromJson(const {
      'id': '1', 'guardName': 'A', 'guardId': 'g1', 'employeeId': 'e1',
      'siteName': 'S', 'clientName': 'C', 'district': 'D', 'date': '2026-10-11',
      'dutyPointName': 'P', 'shiftLabel': 'Day', 'status': 'in',
      'distanceMeters': 45.2, 'gpsAccuracyMeters': 8, 'geofenceRadiusAtTime': 100,
      'isMockLocationSuspected': true, 'mockLocationReason': 'Mock app detected',
      'reviewStatus': 'pending', 'requiresAdminReview': true,
    });
    expect(e.distanceMeters, 45.2);
    expect(e.gpsAccuracyMeters, 8);
    expect(e.geofenceRadiusAtTime, 100);
    expect(e.isMockLocationSuspected, isTrue);
    expect(e.mockLocationReason, 'Mock app detected');
    expect(e.reviewStatus, 'pending');
    expect(e.requiresAdminReview, isTrue);

    final empty = FieldOfficerAttendanceEntry.fromJson(const {});
    expect(empty.distanceMeters, isNull);
    expect(empty.isMockLocationSuspected, isFalse);
    expect(empty.requiresAdminReview, isFalse);
    expect(empty.mockLocationReason, isNull);
  });
}
