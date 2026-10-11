import 'package:ciss_mobile/core/attendance/attendance_validation.dart';
import 'package:ciss_mobile/core/settings/module_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses canSubmit/reason and blocks when canSubmit is false', () {
    final r = AttendanceValidationResult.fromJson({
      'canSubmit': false,
      'reason': 'Outside site geofence (145 m of 100 m)',
      'checks': {
        'geoFence': {'ok': false},
      },
    });
    expect(r.canSubmit, isFalse);
    expect(r.reason, contains('geofence'));
    expect(r.blocksSubmit, isTrue);
  });

  test('canSubmit true does not block', () {
    final r = AttendanceValidationResult.fromJson({'canSubmit': true});
    expect(r.canSubmit, isTrue);
    expect(r.blocksSubmit, isFalse);
  });

  test('honours legacy allowed key for backward compatibility', () {
    final blocked = AttendanceValidationResult.fromJson({'allowed': false});
    expect(blocked.canSubmit, isFalse);
    expect(blocked.blocksSubmit, isTrue);

    final ok = AttendanceValidationResult.fromJson({'allowed': true});
    expect(ok.canSubmit, isTrue);
    expect(ok.blocksSubmit, isFalse);
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
