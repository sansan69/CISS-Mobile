import 'package:ciss_mobile/core/attendance/attendance_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('break state machine applies server response', () {
    final s = AttendanceSession();
    s.applyBreakResponse({'onBreak': true, 'breakStartedAt': '2026-01-01T10:00:00Z',
                          'breakSeconds': 0, 'canCheckOut': false});
    expect(s.onBreak, isTrue);
    expect(s.canCheckOut, isFalse);
    expect(s.breakStartedAt, DateTime.parse('2026-01-01T10:00:00Z'));
    s.applyBreakResponse({'onBreak': false, 'breakSeconds': 900, 'canCheckOut': true});
    expect(s.onBreak, isFalse);
    expect(s.totalBreakSeconds, 900);
    expect(s.breakStartedAt, isNull);
  });
}
