import 'package:ciss_mobile/core/attendance/attendance_validation.dart';
import 'package:ciss_mobile/core/settings/module_flags.dart';
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

  test('pre-check is opt-in behind ipAttendance and off by default', () {
    // geoFence defaults ON, but it must NOT enable the client pre-check on its
    // own — only ipAttendance (default OFF) does.
    expect(shouldRunAttendancePreCheck(ModuleFlags.defaults()), isFalse);
    expect(
      shouldRunAttendancePreCheck(ModuleFlags(const {'ipAttendance': true})),
      isTrue,
    );
  });
}
