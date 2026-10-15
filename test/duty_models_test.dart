import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';

void main() {
  group('GuardDuty.fromJson', () {
    test('parses an assigned shift', () {
      final duty = GuardDuty.fromJson(<String, dynamic>{
        'id': 'a1',
        'kind': 'assigned',
        'clientName': 'TCS',
        'siteName': 'Govt HSS Ernakulam',
        'date': '2026-10-20',
        'shiftLabel': 'Day',
        'type': 'relieving',
      });

      expect(duty.id, 'a1');
      expect(duty.kind, DutyKind.assigned);
      expect(duty.isExam, isFalse);
      expect(duty.relieving, isTrue);
      expect(duty.willingness, isNull);
    });

    test('parses an exam duty with a willingness response', () {
      final duty = GuardDuty.fromJson(<String, dynamic>{
        'id': 'e9',
        'kind': 'exam',
        'clientName': 'TCS',
        'siteName': 'St. Xaviers',
        'dateLabel': '21 Oct 2026',
        'examName': 'BITSAT',
        'willingness': 'willing',
      });

      expect(duty.kind, DutyKind.exam);
      expect(duty.isExam, isTrue);
      expect(duty.examName, 'BITSAT');
      expect(duty.date, '21 Oct 2026');
      expect(duty.willingness, WillingnessStatus.willing);
    });

    test('defaults safely on missing fields', () {
      final duty = GuardDuty.fromJson(const <String, dynamic>{});

      expect(duty.id, '');
      expect(duty.kind, DutyKind.assigned);
      expect(duty.relieving, isFalse);
      expect(duty.willingness, isNull);
    });

    test('recognises an unavailable response', () {
      final duty = GuardDuty.fromJson(<String, dynamic>{
        'kind': 'exam',
        'willingness': 'unavailable',
      });
      expect(duty.willingness, WillingnessStatus.unavailable);
    });
  });

  test('withWillingness keeps identity and updates the response', () {
    final duty = GuardDuty.fromJson(<String, dynamic>{
      'id': 'e1',
      'kind': 'exam',
      'siteName': 'St. Xaviers',
    });

    final updated = duty.withWillingness(WillingnessStatus.willing);

    expect(updated.id, 'e1');
    expect(updated.siteName, 'St. Xaviers');
    expect(updated.willingness, WillingnessStatus.willing);
    expect(duty.willingness, isNull);
  });
}
