import 'package:ciss_mobile/core/submission_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps a key for retries, changes it for edits, and resets on completion',
    () {
      var nextId = 0;
      final identity = SubmissionIdentity(newId: () => 'request-${++nextId}');
      final payload = {'description': 'Gate damaged', 'siteId': 'site-1'};

      expect(identity.forPayload(payload), 'request-1');
      expect(
        identity.forPayload({
          'siteId': 'site-1',
          'description': 'Gate damaged',
        }),
        'request-1',
      );
      expect(
        identity.forPayload({...payload, 'description': 'Fence damaged'}),
        'request-2',
      );
      identity.complete();
      expect(
        identity.forPayload({...payload, 'description': 'Fence damaged'}),
        'request-3',
      );
    },
  );

  test('keeps captured time stable when retrying unchanged content', () {
    var nextId = 0;
    final identity = SubmissionIdentity(newId: () => 'request-${++nextId}');
    final firstId = identity.forPayload(
      {'description': 'Gate damaged', 'reportedAt': 'first'},
      ignoredKeys: {'reportedAt'},
    );
    final firstTime = identity.capture('reportedAt', 'first');
    final retryId = identity.forPayload(
      {'description': 'Gate damaged', 'reportedAt': 'later'},
      ignoredKeys: {'reportedAt'},
    );

    expect(retryId, firstId);
    expect(identity.capture('reportedAt', 'later'), firstTime);
  });
}
