import 'package:ciss_mobile/core/attendance/attendance_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'break capture payload omits missing GPS and preserves operation identity',
    () {
      final payload = buildBreakPayload(
        action: 'start',
        capturedAt: DateTime.utc(2026, 10, 18, 4),
        clientRequestId: 'request-1',
        sessionId: 'session-1',
      );
      expect(payload, {
        'action': 'start',
        'capturedAt': '2026-10-18T04:00:00.000Z',
        'clientRequestId': 'request-1',
        'sessionId': 'session-1',
      });
      final session =
          AttendanceSession()
            ..applyBreakResponse({'sessionId': 'session-1', 'onBreak': true});
      expect(session.sessionId, 'session-1');
    },
  );
  test('break state machine applies server response', () {
    final s = AttendanceSession();
    s.applyBreakResponse({
      'onBreak': true,
      'breakStartedAt': '2026-01-01T10:00:00Z',
      'breakSeconds': 0,
      'canCheckOut': false,
    });
    expect(s.onBreak, isTrue);
    expect(s.canCheckOut, isFalse);
    expect(s.breakStartedAt, DateTime.parse('2026-01-01T10:00:00Z'));
    s.applyBreakResponse({
      'onBreak': false,
      'breakSeconds': 900,
      'canCheckOut': true,
    });
    expect(s.onBreak, isFalse);
    expect(s.totalBreakSeconds, 900);
    expect(s.breakStartedAt, isNull);
  });

  test('breaks follow the current IN session across OUT then IN', () {
    final session = AttendanceSession()..sessionId = 'S1';

    session.applyPunch(status: 'Out', responseId: 'out-log');
    expect(session.sessionId, isNull);

    session.applyPunch(status: 'In', responseId: 'S2');
    expect(session.sessionId, 'S2');
    expect(
      buildBreakPayload(
        action: 'start',
        capturedAt: DateTime.utc(2026, 10, 18),
        clientRequestId: 'break-1',
        sessionId: session.sessionId,
      )['sessionId'],
      'S2',
    );
  });

  test('delayed startup status cannot replace state after a newer punch', () {
    final session = AttendanceSession();
    final startupRevision = session.punchRevision;

    session.applyPunch(status: 'In', responseId: 'S2');
    final applied = session.applyTrackingStatus({
      'isClockedIn': true,
      'openSessionId': 'S1',
    }, expectedPunchRevision: startupRevision);

    expect(applied, isFalse);
    expect(session.sessionId, 'S2');
  });

  test(
    'early checkout queue retry keeps the accepted retry payload identity',
    () {
      final initial = {
        'clientRequestId': 'first-request',
        'reportedAtClient': '2026-10-18T04:00:00.000Z',
        'status': 'Out',
      };
      final retry = buildEarlyCheckoutRetryPayload(
        originalPayload: initial,
        photoUrl: 'https://storage/photo.jpg',
        photoStoragePath: 'attendance/photo.jpg',
        clientRequestId: 'reason-request',
        reason: 'Emergency',
      );

      expect(retry, {
        ...initial,
        'photoUrl': 'https://storage/photo.jpg',
        'photoStoragePath': 'attendance/photo.jpg',
        'clientRequestId': 'reason-request',
        'earlyCheckOutReason': 'Emergency',
      });
    },
  );

  test('attendance queue does not replace an already uploaded photo', () {
    final payload = buildAttendanceRetryQueuePayload(
      durablePayload: {
        'clientRequestId': 'request-1',
        'photoUrl': 'https://storage/photo.jpg',
        'photoStoragePath': 'attendance/photo.jpg',
      },
      photoDataUrl: 'data:image/jpeg;base64,changed-token-on-reupload',
    );

    expect(payload['photoUrl'], 'https://storage/photo.jpg');
    expect(payload, isNot(contains('photoDataUrl')));
  });
}
