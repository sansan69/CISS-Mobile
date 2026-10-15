import 'package:ciss_mobile/core/attendance/attendance_pairing.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

FieldOfficerAttendanceEntry row({
  required String id,
  String employeeId = 'CISS-1042',
  String guardName = 'Rahul Kumar',
  String date = '2026-10-14',
  String? checkIn,
  String? checkOut,
  DateTime? checkInAt,
  DateTime? checkOutAt,
  DateTime? shiftStartsAt,
  DateTime? shiftEndsAt,
  String shiftLabel = 'Night duty',
  String site = 'Main Branch – MG Road',
  String dutyPoint = 'Main Gate',
}) => FieldOfficerAttendanceEntry(
  id: id,
  guardName: guardName,
  guardId: 'guard-$employeeId',
  employeeId: employeeId,
  siteName: site,
  clientName: 'CISS',
  district: 'Ernakulam',
  dateLabel: date,
  checkIn: checkIn,
  checkOut: checkOut,
  checkInAt: checkInAt,
  checkOutAt: checkOutAt,
  shiftStartsAt: shiftStartsAt,
  shiftEndsAt: shiftEndsAt,
  dutyPointName: dutyPoint,
  shiftLabel: shiftLabel,
  status: 'Recorded',
);

void main() {
  group('punch time parsing', () {
    final day = DateTime(2026, 10, 14);

    test('reads a bare clock time against the row date', () {
      expect(
        parsePunchTime('20:05', onDate: day),
        DateTime(2026, 10, 14, 20, 5),
      );
      expect(
        parsePunchTime('7:58', onDate: day),
        DateTime(2026, 10, 14, 7, 58),
      );
      expect(
        parsePunchTime('06:10:30', onDate: day),
        DateTime(2026, 10, 14, 6, 10, 30),
      );
      expect(
        parsePunchTime('7:58 PM', onDate: day),
        DateTime(2026, 10, 14, 19, 58),
      );
    });

    test('reads an absolute timestamp without the row date', () {
      expect(
        parsePunchTime('2026-10-15T06:10:00'),
        DateTime(2026, 10, 15, 6, 10),
      );
      expect(parsePunchTime('', onDate: day), isNull);
      expect(parsePunchTime('--:--', onDate: day), isNull);
      // A bare time cannot be placed without a date.
      expect(parsePunchTime('06:10'), isNull);
    });

    test('reads ISO, display and numeric row dates', () {
      expect(parseRowDate('2026-10-14'), DateTime(2026, 10, 14));
      expect(parseRowDate('14 Oct 2026'), DateTime(2026, 10, 14));
      expect(parseRowDate('14-Oct-2026'), DateTime(2026, 10, 14));
      expect(parseRowDate('14/10/2026'), DateTime(2026, 10, 14));
      expect(parseRowDate('31/07/2026'), DateTime(2026, 7, 31));
      expect(parseRowDate(''), isNull);
      expect(parseRowDate('yesterday'), isNull);
    });
  });

  group('punch pairing', () {
    test('a night shift that starts before midnight is one closed pair', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', date: '2026-10-14'),
        row(id: 'b', checkOut: '06:10', date: '2026-10-15'),
      ], now: DateTime(2026, 10, 15, 7));
      expect(pairs, hasLength(1));
      expect(pairs.single.status, PunchPairStatus.closed);
      expect(pairs.single.checkIn, DateTime(2026, 10, 14, 20, 5));
      expect(pairs.single.checkOut, DateTime(2026, 10, 15, 6, 10));
      expect(pairs.single.businessDate, DateTime(2026, 10, 14));
      expect(pairs.single.isOnDuty, isFalse);
    });

    test(
      'a row carrying both times past midnight rolls the check-out over',
      () {
        final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
          row(id: 'a', checkIn: '20:05', checkOut: '06:10'),
        ], now: DateTime(2026, 10, 15, 7));
        expect(pairs, hasLength(1));
        expect(pairs.single.status, PunchPairStatus.closed);
        expect(pairs.single.checkOut, DateTime(2026, 10, 15, 6, 10));
      },
    );

    test('same-minute legacy IN and OUT do not become a 24-hour shift', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '08:00', checkOut: '08:00', shiftLabel: 'Day'),
      ], now: DateTime(2026, 10, 14, 9));
      expect(pairs, hasLength(1));
      expect(pairs.single.status, PunchPairStatus.closed);
    });

    test('real timestamps preserve next-day order and operational date', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(
          id: 'out',
          date: '2026-10-14',
          checkOut: '06:10',
          checkOutAt: DateTime.parse('2026-10-15T00:40:00Z').toLocal(),
          shiftStartsAt: DateTime.parse('2026-10-14T14:30:00Z').toLocal(),
          shiftEndsAt: DateTime.parse('2026-10-15T02:30:00Z').toLocal(),
        ),
        row(
          id: 'in',
          date: '2026-10-14',
          checkIn: '20:05',
          checkInAt: DateTime.parse('2026-10-14T14:35:00Z').toLocal(),
          shiftStartsAt: DateTime.parse('2026-10-14T14:30:00Z').toLocal(),
          shiftEndsAt: DateTime.parse('2026-10-15T02:30:00Z').toLocal(),
        ),
      ], now: DateTime(2026, 10, 15, 7));
      expect(pairs, hasLength(1));
      expect(pairs.single.status, PunchPairStatus.closed);
      expect(pairs.single.businessDate, DateTime(2026, 10, 14));
    });

    test('saved shift bounds override inferred shift duration', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(
          id: 'a',
          checkIn: '08:00',
          shiftLabel: 'Day',
          shiftStartsAt: DateTime.parse('2026-10-14T02:30:00Z').toLocal(),
          shiftEndsAt: DateTime.parse('2026-10-14T10:30:00Z').toLocal(),
        ),
      ], now: DateTime(2026, 10, 14, 18));
      expect(pairs.single.window!.start, DateTime(2026, 10, 14, 8));
      expect(pairs.single.window!.end, DateTime(2026, 10, 14, 16));
    });

    test('a night guard is on duty at 02:00 with the business date kept', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05'),
      ], now: DateTime(2026, 10, 15, 2));
      expect(pairs.single.status, PunchPairStatus.open);
      expect(pairs.single.isOnDuty, isTrue);
      expect(pairs.single.businessDate, DateTime(2026, 10, 14));
    });

    test(
      'an unclosed punch past the window end becomes a missed check-out',
      () {
        final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
          row(id: 'a', checkIn: '20:05'),
        ], now: DateTime(2026, 10, 15, 9));
        expect(pairs.single.status, PunchPairStatus.missedCheckOut);
        expect(pairs.single.isOnDuty, isFalse);
        expect(pairs.single.needsCheckOutReview, isTrue);
      },
    );

    test('a late check-out inside the grace window still closes the pair', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', date: '2026-10-14'),
        row(id: 'b', checkOut: '06:30', date: '2026-10-15'),
      ], now: DateTime(2026, 10, 15, 9));
      expect(pairs.single.status, PunchPairStatus.closed);
    });

    test('a check-out long after the window is not paired with it', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', date: '2026-10-14'),
        row(id: 'b', checkOut: '06:30', date: '2026-10-16'),
      ], now: DateTime(2026, 10, 16, 8));
      expect(pairs.map((pair) => pair.status), <PunchPairStatus>[
        PunchPairStatus.missedCheckOut,
        PunchPairStatus.missedCheckOut,
      ]);
      // Only the unclosed check-in needs a review.
      expect(pairs.where((pair) => pair.needsCheckOutReview), hasLength(1));
      expect(pairs.any((pair) => pair.isOnDuty), isFalse);
    });

    test('a second check-in closes out the first as a duplicate', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', dutyPoint: 'Main Gate'),
        row(id: 'b', checkIn: '20:40', dutyPoint: 'ATM Lobby'),
      ], now: DateTime(2026, 10, 14, 21));
      expect(pairs.map((pair) => pair.status), <PunchPairStatus>[
        PunchPairStatus.duplicateCheckIn,
        PunchPairStatus.open,
      ]);
      expect(pairs.where((pair) => pair.isOnDuty), hasLength(1));
      expect(pairs.first.isOnDuty, isFalse);
    });

    test('a check-in after the window ended is a forgotten check-out', () {
      // Morning shift never closed, then the guard checked in for the evening.
      // That is not a double tap: the morning tour needs a check-out review.
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(
          id: 'morning',
          checkIn: '08:00',
          shiftLabel: 'Morning',
          dutyPoint: 'Main Gate',
        ),
        row(
          id: 'evening',
          checkIn: '19:30',
          shiftLabel: 'Night duty',
          dutyPoint: 'ATM Lobby',
        ),
      ], now: DateTime(2026, 10, 14, 20));
      expect(pairs.first.status, PunchPairStatus.missedCheckOut);
      expect(pairs.first.needsCheckOutReview, isTrue);
      expect(pairs.last.status, PunchPairStatus.open);
    });

    test('a check-in inside the window is still a double tap', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', dutyPoint: 'Main Gate'),
        row(id: 'b', checkIn: '20:40', dutyPoint: 'ATM Lobby'),
      ], now: DateTime(2026, 10, 14, 21));
      expect(pairs.first.status, PunchPairStatus.duplicateCheckIn);
      expect(pairs.first.needsCheckOutReview, isFalse);
    });

    test(
      'an overnight gap is reviewable the morning after, not weeks later',
      () {
        final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
          row(id: 'a', checkIn: '20:05', date: '2026-10-14'),
        ], now: DateTime(2026, 10, 15, 9));
        final pair = pairs.single;
        expect(pair.status, PunchPairStatus.missedCheckOut);
        // The morning after: the supervisor must still see it.
        expect(pair.needsReviewWithin(DateTime(2026, 10, 15, 9)), isTrue);
        expect(pair.needsReviewWithin(DateTime(2026, 10, 15, 23)), isTrue);
        // Past the lookback it is history, not today's to-do list.
        expect(pair.needsReviewWithin(DateTime(2026, 10, 16, 7)), isFalse);
        expect(pair.needsReviewWithin(DateTime(2026, 10, 20, 9)), isFalse);
      },
    );

    test('an unclosed shift is not reviewable before its window ends', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', date: '2026-10-14'),
      ], now: DateTime(2026, 10, 15, 2));
      expect(pairs.single.status, PunchPairStatus.open);
      expect(
        pairs.single.needsReviewWithin(DateTime(2026, 10, 15, 2)),
        isFalse,
      );
    });

    test('an unparseable date keeps the punch on the viewed business date', () {
      final rows = <FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', date: 'last Tuesday'),
      ];
      // Without a fallback the punch cannot be placed and quietly disappears.
      expect(pairPunches(rows, now: DateTime(2026, 10, 15, 2)), isEmpty);
      final placed = pairPunches(
        rows,
        now: DateTime(2026, 10, 15, 2),
        fallbackDate: DateTime(2026, 10, 14),
      );
      expect(placed, hasLength(1));
      expect(placed.single.businessDate, DateTime(2026, 10, 14));
      expect(placed.single.checkIn, DateTime(2026, 10, 14, 20, 5));
    });

    test('an orphan check-out reports the missing check-in', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'b', checkOut: '06:10', date: '2026-10-15'),
      ], now: DateTime(2026, 10, 15, 7));
      expect(pairs.single.status, PunchPairStatus.missedCheckOut);
      expect(pairs.single.checkIn, isNull);
      // The row still renders; only the on-duty count stays honest.
      expect(pairs.single.entry.id, 'b');
      expect(pairs.single.needsCheckOutReview, isFalse);
    });

    test('a plain day shift is unchanged', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(
          id: 'a',
          checkIn: '07:58',
          checkOut: '16:05',
          shiftLabel: 'Morning',
        ),
      ], now: DateTime(2026, 10, 14, 20));
      expect(pairs.single.status, PunchPairStatus.closed);
      expect(pairs.single.businessDate, DateTime(2026, 10, 14));
    });

    test('one guard with two sites in a day keeps both pairs', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(
          id: 'a',
          checkIn: '08:00',
          checkOut: '16:00',
          shiftLabel: 'Morning',
          dutyPoint: 'Main Gate',
        ),
        row(
          id: 'b',
          checkIn: '18:00',
          checkOut: '06:00',
          shiftLabel: 'Night duty',
          dutyPoint: 'ATM Lobby',
        ),
      ], now: DateTime(2026, 10, 15, 7));
      expect(pairs, hasLength(2));
      expect(pairs.map((pair) => pair.status), <PunchPairStatus>[
        PunchPairStatus.closed,
        PunchPairStatus.closed,
      ]);
      expect(pairs.first.entry.dutyPointName, 'Main Gate');
      expect(pairs.last.entry.dutyPointName, 'ATM Lobby');
    });

    test('separate guards pair independently', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', employeeId: 'CISS-1', checkIn: '20:05'),
        row(id: 'b', employeeId: 'CISS-2', checkIn: '20:10'),
        row(
          id: 'c',
          employeeId: 'CISS-1',
          checkOut: '06:10',
          date: '2026-10-15',
        ),
      ], now: DateTime(2026, 10, 15, 9));
      expect(pairs, hasLength(2));
      final first = pairs.firstWhere((pair) => pair.guardKey == 'emp:CISS-1');
      final second = pairs.firstWhere((pair) => pair.guardKey == 'emp:CISS-2');
      expect(first.status, PunchPairStatus.closed);
      expect(second.status, PunchPairStatus.missedCheckOut);
    });

    test('every row lands in exactly one pair', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05'),
        row(id: 'b', checkOut: '06:10', date: '2026-10-15'),
      ], now: DateTime(2026, 10, 15, 7));
      final rendered = pairs.map((pair) => pair.entry.id).toSet();
      expect(rendered, <String>{'a'});
      expect(pairs.single.checkOutEntry?.id, 'b');
    });

    test('groups pairs under the date the shift started', () {
      final pairs = pairPunches(<FieldOfficerAttendanceEntry>[
        row(id: 'a', checkIn: '20:05', date: '2026-10-14'),
        row(id: 'b', checkOut: '06:10', date: '2026-10-15'),
        row(
          id: 'c',
          checkIn: '08:00',
          checkOut: '16:00',
          date: '2026-10-15',
          shiftLabel: 'Morning',
        ),
      ], now: DateTime(2026, 10, 15, 20));
      final grouped = groupByBusinessDate(pairs);
      expect(grouped.keys.toList(), <DateTime>[
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 15),
      ]);
      expect(grouped[DateTime(2026, 10, 14)], hasLength(1));
      expect(grouped[DateTime(2026, 10, 15)], hasLength(1));
    });
  });

  group('row merging', () {
    test('de-duplicates overlapping fetches by row id', () {
      final merged = mergeAttendanceRows(<List<FieldOfficerAttendanceEntry>>[
        <FieldOfficerAttendanceEntry>[row(id: 'a', checkIn: '20:05')],
        <FieldOfficerAttendanceEntry>[
          row(id: 'a', checkIn: '20:05'),
          row(id: 'b', checkOut: '06:10', date: '2026-10-15'),
        ],
      ]);
      expect(merged.map((entry) => entry.id).toList(), <String>['a', 'b']);
    });

    test('falls back to the punch identity when the id is missing', () {
      final merged = mergeAttendanceRows(<List<FieldOfficerAttendanceEntry>>[
        <FieldOfficerAttendanceEntry>[row(id: '', checkIn: '20:05')],
        <FieldOfficerAttendanceEntry>[row(id: '', checkIn: '20:05')],
        <FieldOfficerAttendanceEntry>[row(id: '', checkIn: '20:06')],
      ]);
      expect(merged, hasLength(2));
    });
  });
}
