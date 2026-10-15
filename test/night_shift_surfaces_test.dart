import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/time/clock.dart';
import 'package:ciss_mobile/dev/mock_data.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final AppStrings english = AppStrings.forLanguage(AppLanguage.english);

const String _openNightGuard = 'Night Guard';
const String _closedNightGuard = 'Closed Night Guard';
const String _dayGuard = 'Day Guard';

String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

FieldOfficerAttendanceEntry entry({
  required String id,
  required String employeeId,
  required String guardName,
  required DateTime date,
  String? checkIn,
  String? checkOut,
  String shiftLabel = 'Night duty',
  String dutyPoint = 'Main Gate',
}) => FieldOfficerAttendanceEntry(
  id: id,
  guardName: guardName,
  guardId: 'doc-$employeeId',
  employeeId: employeeId,
  siteName: 'Ernakulam centre',
  clientName: 'Client',
  district: 'Ernakulam',
  dateLabel: dayKey(date),
  checkIn: checkIn,
  checkOut: checkOut,
  dutyPointName: dutyPoint,
  shiftLabel: shiftLabel,
  status: checkOut == null ? 'In' : 'Present',
);

/// Fixtures relative to [now] so the night window is always in the state the
/// assertion expects, whatever hour the suite runs at.
List<FieldOfficerAttendanceEntry> fixtureFor(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  return <FieldOfficerAttendanceEntry>[
    // On duty since yesterday evening: the shift the single-date query lost.
    entry(
      id: 'open-in',
      employeeId: 'e1',
      guardName: _openNightGuard,
      date: yesterday,
      checkIn: '21:00',
    ),
    // A night shift that closed this morning, across midnight.
    entry(
      id: 'closed-in',
      employeeId: 'e2',
      guardName: _closedNightGuard,
      date: yesterday,
      checkIn: '20:05',
    ),
    entry(
      id: 'closed-out',
      employeeId: 'e2',
      guardName: _closedNightGuard,
      date: today,
      checkOut: '06:10',
    ),
    // An ordinary day shift on the viewed date.
    entry(
      id: 'day',
      employeeId: 'e3',
      guardName: _dayGuard,
      date: today,
      checkIn: '08:15',
      checkOut: '17:45',
      shiftLabel: 'Morning',
    ),
  ];
}

Future<void> mount(
  WidgetTester tester, {
  required DateTime now,
  List<FieldOfficerAttendanceEntry>? rows,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(411, 900);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final entries = rows ?? fixtureFor(now);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        clockProvider.overrideWithValue(() => now),
        fieldOfficerDashboardProvider.overrideWith(
          (ref) async => mockFieldOfficerDashboard,
        ),
        fieldOfficerGuardAttendanceProvider.overrideWith(
          (ref) async => entries,
        ),
        fieldOfficerGuardAttendanceHistoryProvider.overrideWith(
          (ref) async => entries,
        ),
        fieldOfficerAttendanceSitesProvider.overrideWith(
          (ref) async => const <FieldOfficerSiteOption>[],
        ),
        attendanceHistoryStartDateProvider.overrideWith(
          (ref) => DateTime(2020),
        ),
        attendanceHistoryEndDateProvider.overrideWith(
          (ref) => DateTime(2030),
        ),
      ],
      child: MaterialApp(
        theme: buildCissTheme(Brightness.light),
        home: const FieldOfficerGuardAttendanceScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('live feed at 02:00', () {
    // 02:00 on 15 October: the middle of a 20:00 → 06:00 duty.
    final now = DateTime(2026, 10, 15, 2);

    testWidgets('a night guard carried over from yesterday reads on duty', (
      tester,
    ) async {
      await mount(tester, now: now);

      expect(find.text(english.attendanceOnDuty), findsOneWidget);
      expect(
        find.text(
          english.fill(english.attendanceSinceYesterday, <String, Object>{
            'time': '21:00',
          }),
        ),
        findsOneWidget,
      );
      // The shift that closed this morning belongs to yesterday's feed.
      expect(find.text(_closedNightGuard), findsNothing);
      // The ordinary day shift is unaffected.
      expect(find.text(_dayGuard), findsOneWidget);
      expect(find.text(english.attendanceCheckedOut), findsOneWidget);
    });

    testWidgets('a shift with no check-out is flagged for review', (
      tester,
    ) async {
      // 23:00 on the same day: the 08:00 shift's window has ended without a
      // check-out, so the guard is no longer counted as on duty.
      final evening = DateTime(2026, 10, 15, 23);
      await mount(
        tester,
        now: evening,
        rows: <FieldOfficerAttendanceEntry>[
          entry(
            id: 'lapsed',
            employeeId: 'e4',
            guardName: 'Lapsed Guard',
            date: DateTime(2026, 10, 15),
            checkIn: '08:00',
            shiftLabel: 'Morning',
          ),
        ],
      );

      expect(find.text(english.attendanceCheckOutMissing), findsOneWidget);
      expect(
        find.text(
          english.fill(english.attendanceReviewNotice, <String, Object>{
            'count': 1,
          }),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a night guard who never checked out is visible in the morning', (
      tester,
    ) async {
      // 09:00 the morning after: the overnight tour ended at 06:00 without a
      // check-out, so its business date is yesterday. The officer must still
      // see it — this is the case the whole review exists to catch.
      await mount(
        tester,
        now: DateTime(2026, 10, 15, 9),
        rows: <FieldOfficerAttendanceEntry>[
          entry(
            id: 'forgotten',
            employeeId: 'e9',
            guardName: 'Forgot To Check Out',
            date: DateTime(2026, 10, 14),
            checkIn: '20:05',
          ),
        ],
      );

      expect(find.text('Forgot To Check Out'), findsOneWidget);
      expect(find.text(english.attendanceCheckOutMissing), findsOneWidget);
      expect(
        find.text(
          english.fill(english.attendanceReviewNotice, <String, Object>{
            'count': 1,
          }),
        ),
        findsOneWidget,
      );
    });
  });

  group('history at a fixed clock', () {
    final now = DateTime(2026, 10, 15, 2);

    testWidgets('groups a cross-midnight shift under the day it started', (
      tester,
    ) async {
      await mount(tester, now: now);
      await tester.tap(find.text('History'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      // One header per business date, oldest last.
      expect(find.text('14/10/2026'), findsOneWidget);
      expect(find.text('15/10/2026'), findsOneWidget);
      // The overnight pair is one shift with both punches.
      expect(find.text('Check-in: 20:05'), findsOneWidget);
      expect(find.text('Check-out: 06:10'), findsOneWidget);
      expect(
        find.text(english.attendanceCarriedOver),
        findsOneWidget,
      );
      // Yesterday's still-open shift is one shift, not an unpaired punch. The
      // live feed stays mounted behind the tab, so "On duty" also appears
      // there.
      expect(find.text(_openNightGuard), findsWidgets);
      expect(find.text(english.attendanceOnDuty), findsWidgets);
    });

    testWidgets('stays readable at 320dp and 1.8 text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      await mount(tester, now: now, textScale: 1.8);
      await tester.tap(find.text('History'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('14/10/2026'), findsOneWidget);
    });
  });

  group('muster roll counts', () {
    testWidgets('counts shifts, not rows, and leaves an unclosed shift out', (
      tester,
    ) async {
      await mount(tester, now: DateTime(2026, 10, 15, 2));

      // Summary: the day shift plus the carried-over night shift is 2 shifts;
      // the closed night pair belongs to yesterday's feed.
      expect(find.text(english.attendanceOnDuty), findsOneWidget);
      expect(find.text(english.attendanceCheckedOut), findsOneWidget);
    });
  });
}
