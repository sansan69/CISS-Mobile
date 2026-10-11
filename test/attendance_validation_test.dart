import 'package:ciss_mobile/core/attendance/attendance_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses allowed/reason and blocks when not allowed', () {
    final r = AttendanceValidationResult.fromJson({
      'allowed': false,
      'reason': 'Outside site geofence (145 m of 100 m)',
      'checks': {
        'geoFence': {'ok': false},
      },
    });
    expect(r.allowed, isFalse);
    expect(r.reason, contains('geofence'));
    expect(r.blocksSubmit, isTrue);
  });

  test('allowed result does not block', () {
    final r = AttendanceValidationResult.fromJson({'allowed': true});
    expect(r.blocksSubmit, isFalse);
  });
}
