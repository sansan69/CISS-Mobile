import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/fcm/duty_notification_destination.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/models/app_role.dart';

AuthSession session(AppRole role, [String uid = 'auth-a']) => AuthSession(
  role: role,
  displayName: 'A',
  primaryId: 'CISS/A',
  uid: uid,
  employeeDocId: 'employee-doc-a',
);
void main() {
  for (final type in ['duty_assigned', 'duty_changed', 'duty_cancelled']) {
    test('$type opens matching guard record', () {
      final d = DutyNotificationDestination.resolve({
        'type': type,
        'recipientUid': 'auth-a',
        'recipientRole': 'guard',
        'assignmentId': 'assignment-a',
      }, session(AppRole.guard));
      expect(d?.role, AppRole.guard);
      expect(d?.recordId, 'assignment-a');
    });
  }
  test('willingness opens FO work order; routeKind fallback works', () {
    final d = DutyNotificationDestination.resolve({
      'routeKind': 'work_order_willingness',
      'recipientUid': 'auth-a',
      'recipientRole': 'fieldOfficer',
      'workOrderId': 'exam-a',
    }, session(AppRole.fieldOfficer));
    expect(d?.recordId, 'exam-a');
    expect(d?.role, AppRole.fieldOfficer);
  });
  test(
    'rejects unknown owner, wrong active account, wrong role and malformed record',
    () {
      final payload = {
        'type': 'duty_assigned',
        'recipientUid': 'auth-a',
        'recipientRole': 'guard',
        'workOrderId': 'exam-a',
      };
      expect(DutyNotificationDestination.resolve(payload, null), null);
      expect(
        DutyNotificationDestination.resolve(
          payload,
          session(AppRole.guard, 'auth-b'),
        ),
        null,
      );
      expect(
        DutyNotificationDestination.resolve(
          payload,
          session(AppRole.fieldOfficer),
        ),
        null,
      );
      expect(
        DutyNotificationDestination.resolve({
          ...payload,
          'recipientUid': '',
        }, session(AppRole.guard)),
        null,
      );
      expect(
        DutyNotificationDestination.resolve({
          ...payload,
          'workOrderId': '../../other',
        }, session(AppRole.guard)),
        null,
      );
    },
  );
}
