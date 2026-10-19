import 'package:ciss_mobile/features/guard/application/leave_request_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unchanged leave payload reuses its request id until reset', () {
    final identity = LeaveRequestIdentity();
    final payload = <String, dynamic>{
      'type': 'casual',
      'fromDate': '2026-10-19',
      'toDate': '2026-10-19',
      'reason': 'Personal',
    };

    final first = identity.forPayload(payload);
    final retry = identity.forPayload({...payload, 'clientRequestId': first});
    expect(retry, first);

    final edited = identity.forPayload({...payload, 'reason': 'Medical'});
    expect(edited, isNot(first));
    identity.reset();
    expect(identity.forPayload(payload), isNot(first));
  });
}
