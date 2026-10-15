import 'package:ciss_mobile/core/attendance/shift_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final businessDate = DateTime(2026, 10, 14);
  final checkIn = DateTime(2026, 10, 14, 20, 5);

  ShiftWindow window(String? label) => shiftWindowFor(
    businessDate: businessDate,
    shiftLabel: label,
    checkIn: checkIn,
  );

  group('shift window', () {
    test('parses a 24-hour roster range', () {
      final night = window('20:00-06:00');
      expect(night.start, DateTime(2026, 10, 14, 20));
      expect(night.end, DateTime(2026, 10, 15, 6));
      expect(night.crossesMidnight, isTrue);
      expect(night.length, const Duration(hours: 10));
    });

    test('parses a range written with an en dash and spaces', () {
      final night = window('20:00 – 06:00');
      expect(night.start, DateTime(2026, 10, 14, 20));
      expect(night.end, DateTime(2026, 10, 15, 6));
    });

    test('parses a 12-hour range with meridiem', () {
      final night = window('8 PM to 6 AM');
      expect(night.start, DateTime(2026, 10, 14, 20));
      expect(night.end, DateTime(2026, 10, 15, 6));
      expect(night.crossesMidnight, isTrue);
    });

    test('parses a day range without crossing midnight', () {
      final day = window('06:00-14:00');
      expect(day.start, DateTime(2026, 10, 14, 6));
      expect(day.end, DateTime(2026, 10, 14, 14));
      expect(day.crossesMidnight, isFalse);
    });

    test('reads a night keyword when no hours are given', () {
      final night = window('Night duty');
      expect(night.start, DateTime(2026, 10, 14, 20));
      expect(night.end, DateTime(2026, 10, 15, 6));
      expect(window('NIGHT SHIFT').end, DateTime(2026, 10, 15, 6));
    });

    test('falls back to twelve hours from the check-in', () {
      final unknown = window('Morning');
      expect(unknown.start, checkIn);
      expect(unknown.end, checkIn.add(defaultShiftLength));
      expect(unknown.length, const Duration(hours: 12));

      final blank = window(null);
      expect(blank.start, checkIn);
      expect(blank.end, checkIn.add(const Duration(hours: 12)));
      expect(blank.businessDate, businessDate);
    });

    test('ignores clock-like text that is not a time', () {
      // "12 hours" names a duration, not a start time, so the shift keeps the
      // check-in fallback instead of opening at noon.
      final windowed = window('12 hour shift');
      expect(windowed.start, checkIn);
    });

    test('rejects impossible clock values', () {
      expect(shiftClockFrom('25:00-26:00'), isNull);
      expect(shiftClockFrom('13 PM to 6 AM'), isNull);
      expect(shiftClockFrom(''), isNull);
    });

    test('contains only moments inside the window', () {
      final night = window('20:00-06:00');
      expect(night.contains(DateTime(2026, 10, 14, 23, 30)), isTrue);
      expect(night.contains(DateTime(2026, 10, 15, 5, 59)), isTrue);
      expect(night.contains(DateTime(2026, 10, 14, 19, 59)), isFalse);
      expect(night.contains(DateTime(2026, 10, 15, 6, 1)), isFalse);
    });

    test('reports whether the window has ended, allowing a grace period', () {
      final night = window('20:00-06:00');
      expect(night.hasEndedBy(DateTime(2026, 10, 15, 5)), isFalse);
      expect(night.hasEndedBy(DateTime(2026, 10, 15, 7)), isTrue);
      expect(
        night.hasEndedBy(
          DateTime(2026, 10, 15, 7),
          grace: const Duration(hours: 2),
        ),
        isFalse,
      );
      expect(
        night.hasEndedBy(
          DateTime(2026, 10, 15, 9),
          grace: const Duration(hours: 2),
        ),
        isTrue,
      );
    });
  });
}
