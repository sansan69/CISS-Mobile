import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';

void main() {
  test('duty retains server cutoff, CAS and cancellation', () {
    final dynamic duty = GuardDuty.fromJson({
      'id': 'e1',
      'kind': 'exam',
      'status': 'cancelled',
      'workOrderId': 'e1',
      'willingnessVersion': 4,
      'canRespond': false,
      'respondBy': '2026-10-13T18:30:00.000Z',
      'ineligibilityReason': 'Duty cancelled',
      'maleGuardsRequired': 2,
      'femaleGuardsRequired': 1,
    });
    expect(duty.status, 'cancelled');
    expect(duty.willingnessVersion, 4);
    expect(duty.canRespond, false);
    expect(duty.respondBy, '2026-10-13T18:30:00.000Z');
    expect(duty.maleGuardsRequired, 2);
  });
  test(
    'legacy TCS category remains unclassified; non-TCS ignores category',
    () {
      dynamic profile = GuardProfileModel.fromJson({
        'clientName': 'TCS',
        'tcsCategory': 'permanent',
      });
      expect(profile.tcsCategory, 'permanent');
      profile = GuardProfileModel.fromJson({'clientName': 'TCS'});
      expect(profile.tcsCategory, null);
      expect(profile.categoryLabel, 'Category not set');
      profile = GuardProfileModel.fromJson({
        'clientName': 'Other',
        'tcsCategory': 'adhoc',
      });
      expect(profile.tcsCategory, null);
    },
  );
  test(
    'server cutoff and eligibility are surfaced verbatim, never re-derived',
    () {
      final dynamic duty = GuardDuty.fromJson({
        'id': 'e1',
        'kind': 'exam',
        'status': 'open',
        'workOrderId': 'e1',
        'canRespond': true,
        'willingnessVersion': 2,
        'respondBy': '2020-01-01T00:00:00.000Z',
        'ineligibilityReason': null,
      });
      expect(duty.canRespond, true);
      expect(duty.respondBy, '2020-01-01T00:00:00.000Z');
      expect(duty.ineligibilityReason, null);
      final dynamic ineligible = GuardDuty.fromJson({
        'id': 'e2',
        'kind': 'exam',
        'status': 'open',
        'workOrderId': 'e2',
        'canRespond': false,
        'ineligibilityReason': 'Category not set',
        'respondBy': '2026-10-13T18:30:00.000Z',
      });
      expect(ineligible.canRespond, false);
      expect(ineligible.ineligibilityReason, 'Category not set');
    },
  );
}
