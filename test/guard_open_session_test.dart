import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/models/attendance_models.dart';
import 'package:ciss_mobile/core/time/clock.dart';
import 'package:ciss_mobile/features/guard/application/open_duty_session.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_attendance_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/widgets/open_duty_session_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final AppStrings english = AppStrings.forLanguage(AppLanguage.english);

AttendanceRecordModel record({
  required String status,
  String? time,
  String date = '2026-10-14',
  String shiftLabel = 'Night duty',
  String siteName = 'Ernakulam centre',
  String dutyPointName = 'Main Gate',
  DateTime? reportedAt,
  DateTime? shiftStartsAt,
  DateTime? shiftEndsAt,
}) => AttendanceRecordModel(
  siteName: siteName,
  dateLabel: date,
  status: status,
  dutyPointName: dutyPointName,
  shiftLabel: shiftLabel,
  time: time,
  reportedAt: reportedAt,
  shiftStartsAt: shiftStartsAt,
  shiftEndsAt: shiftEndsAt,
);

Future<void> pumpCard(
  WidgetTester tester,
  List<AttendanceRecordModel> records, {
  required DateTime now,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(411, 900);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        clockProvider.overrideWithValue(() => now),
        attendanceHistoryProvider.overrideWith((ref) async => records),
        recentAttendanceHistoryProvider.overrideWith((ref) async => records),
      ],
      child: MaterialApp(
        theme: buildCissTheme(Brightness.light),
        home: Scaffold(body: OpenDutySessionCard(onOpen: () {})),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('recent session fetch spans a month boundary', () {
    expect(attendanceHistoryMonthsFor(DateTime(2026, 11, 1, 2)), <String>[
      '2026-10',
      '2026-11',
    ]);
  });

  test('history model decodes exact timestamp and saved shift bounds', () {
    final decoded = AttendanceRecordModel.fromJson(<String, dynamic>{
      'date': '2026-10-14',
      'status': 'In',
      'time': '20:05',
      'reportedAt': '2026-10-14T14:35:00.000Z',
      'shiftStartsAt': '2026-10-14T14:30:00.000Z',
      'shiftEndsAt': '2026-10-15T02:30:00.000Z',
    });
    expect(decoded.dateLabel, '2026-10-14');
    expect(decoded.reportedAt!.toUtc(), DateTime.utc(2026, 10, 14, 14, 35));
    expect(decoded.shiftEndsAt!.toUtc(), DateTime.utc(2026, 10, 15, 2, 30));
  });

  group('open duty session', () {
    test('reports a night shift that started before midnight as on duty', () {
      final session = openDutySession(<AttendanceRecordModel>[
        record(status: 'In', time: '21:00'),
      ], now: DateTime(2026, 10, 15, 2));
      expect(session, isNotNull);
      expect(session!.status, OpenDutyStatus.open);
      expect(session.isOpen, isTrue);
      expect(session.checkInAt, DateTime(2026, 10, 14, 21));
      expect(session.startedBefore(DateTime(2026, 10, 15, 2)), isTrue);
      // The window is the night shift's, so 06:10 the next morning still
      // belongs to the same tour.
      expect(session.window.end, DateTime(2026, 10, 15, 6));
    });

    test('a closed day shift leaves no open session', () {
      expect(
        openDutySession(<AttendanceRecordModel>[
          record(status: 'In', time: '08:15', shiftLabel: 'Morning'),
          record(status: 'Out', time: '17:45', shiftLabel: 'Morning'),
        ], now: DateTime(2026, 10, 14, 20)),
        isNull,
      );
    });

    test('a shift past its window is overdue, not on duty', () {
      final session = openDutySession(<AttendanceRecordModel>[
        record(status: 'In', time: '08:00', shiftLabel: 'Morning'),
      ], now: DateTime(2026, 10, 14, 23));
      expect(session!.status, OpenDutyStatus.overdue);
      expect(session.isOpen, isFalse);
    });

    test('a second check-in supersedes the earlier one', () {
      final session = openDutySession(<AttendanceRecordModel>[
        record(status: 'In', time: '20:00'),
        record(status: 'In', time: '21:30', dutyPointName: 'ATM Lobby'),
      ], now: DateTime(2026, 10, 14, 22));
      expect(session!.checkInAt, DateTime(2026, 10, 14, 21, 30));
      expect(session.dutyPointName, 'ATM Lobby');
    });

    test('an out that arrives after the window still closes the tour', () {
      expect(
        openDutySession(<AttendanceRecordModel>[
          record(status: 'In', time: '20:05'),
          record(status: 'Out', time: '06:10', date: '2026-10-15'),
        ], now: DateTime(2026, 10, 15, 7)),
        isNull,
      );
    });

    test(
      'actual timestamps close overnight duty under the IN business date',
      () {
        final session = openDutySession(<AttendanceRecordModel>[
          record(
            status: 'Out',
            time: '06:10',
            reportedAt: DateTime.parse('2026-10-15T00:40:00Z').toLocal(),
          ),
          record(
            status: 'In',
            time: '20:05',
            reportedAt: DateTime.parse('2026-10-14T14:35:00Z').toLocal(),
            shiftStartsAt: DateTime.parse('2026-10-14T14:30:00Z').toLocal(),
            shiftEndsAt: DateTime.parse('2026-10-15T02:30:00Z').toLocal(),
          ),
        ], now: DateTime(2026, 10, 15, 7));
        expect(session, isNull);
      },
    );

    test('legacy same-date overnight OUT is placed after its IN', () {
      expect(
        openDutySession(<AttendanceRecordModel>[
          record(status: 'Out', time: '06:10'),
          record(status: 'In', time: '20:05'),
        ], now: DateTime(2026, 10, 15, 7)),
        isNull,
      );
    });

    test('saved bounds preserve a custom shift end on the open card', () {
      final session = openDutySession(<AttendanceRecordModel>[
        record(
          status: 'In',
          time: '20:05',
          reportedAt: DateTime.parse('2026-10-14T14:35:00Z').toLocal(),
          shiftStartsAt: DateTime.parse('2026-10-14T14:30:00Z').toLocal(),
          shiftEndsAt: DateTime.parse('2026-10-15T02:30:00Z').toLocal(),
        ),
      ], now: DateTime(2026, 10, 15, 4));
      expect(session!.status, OpenDutyStatus.open);
      expect(session.window.end.toUtc(), DateTime.utc(2026, 10, 15, 2, 30));
    });

    test('ignores records without a usable time or status', () {
      expect(
        openDutySession(<AttendanceRecordModel>[
          record(status: 'In'),
          record(status: 'Absent', time: '09:00'),
          record(status: 'Present', time: '09:00'),
        ], now: DateTime(2026, 10, 14, 10)),
        isNull,
      );
    });

    test('the newest tour wins when the log spans several days', () {
      final session = openDutySession(<AttendanceRecordModel>[
        record(status: 'In', time: '08:00', date: '2026-10-12'),
        record(status: 'Out', time: '17:00', date: '2026-10-12'),
        record(status: 'In', time: '20:00', date: '2026-10-14'),
      ], now: DateTime(2026, 10, 15, 1));
      expect(session!.checkInAt, DateTime(2026, 10, 14, 20));
    });
  });

  group('open duty card', () {
    testWidgets('shows the carried-over tour with its start time', (
      tester,
    ) async {
      await pumpCard(tester, <AttendanceRecordModel>[
        record(status: 'In', time: '21:00'),
      ], now: DateTime(2026, 10, 15, 2));

      expect(
        find.text(
          '${english.attendanceOnDuty} '
          '${english.fill(english.attendanceSinceYesterday, <String, Object>{'time': '21:00'})}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Ernakulam centre'), findsOneWidget);
    });

    testWidgets('flags a tour whose check-out never came', (tester) async {
      await pumpCard(tester, <AttendanceRecordModel>[
        record(status: 'In', time: '08:00', shiftLabel: 'Morning'),
      ], now: DateTime(2026, 10, 14, 23));

      expect(find.text(english.attendanceCheckOutMissing), findsOneWidget);
      expect(find.text(english.dutyCloseShiftHint), findsOneWidget);
    });

    testWidgets('stays out of the way when no tour is open', (tester) async {
      await pumpCard(tester, <AttendanceRecordModel>[
        record(status: 'In', time: '08:15', shiftLabel: 'Morning'),
        record(status: 'Out', time: '17:45', shiftLabel: 'Morning'),
      ], now: DateTime(2026, 10, 14, 20));

      expect(find.byType(Card), findsNothing);
      expect(find.text(english.attendanceOnDuty), findsNothing);
    });

    testWidgets('stays readable on a narrow screen at 1.8 text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      await pumpCard(
        tester,
        <AttendanceRecordModel>[
          record(status: 'In', time: '08:00', shiftLabel: 'Morning'),
        ],
        now: DateTime(2026, 10, 14, 23),
        textScale: 1.8,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(english.attendanceCheckOutMissing), findsOneWidget);
    });
  });
}
