import 'dart:async';

import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixtureEntries = <FieldOfficerAttendanceEntry>[
  FieldOfficerAttendanceEntry(
    id: 'status-only',
    guardName: 'Phantom Absent',
    guardId: 'g0',
    employeeId: 'e0',
    siteName: 'North Gate',
    clientName: 'Client',
    district: 'Kochi',
    dateLabel: '2026-10-12',
    dutyPointName: 'Gate',
    shiftLabel: 'Day',
    status: 'Absent',
  ),
  FieldOfficerAttendanceEntry(
    id: 'complete',
    guardName: 'Complete Session',
    guardId: 'g1',
    employeeId: 'e1',
    siteName: 'North Gate',
    clientName: 'Client',
    district: 'Kochi',
    dateLabel: '2026-10-13',
    checkIn: '08:15 AM',
    checkOut: '05:45 PM',
    dutyPointName: 'Gate',
    shiftLabel: 'Day',
    status: 'Present',
  ),
  FieldOfficerAttendanceEntry(
    id: 'out-only',
    guardName: 'OUT Only',
    guardId: 'g2',
    employeeId: 'e2',
    siteName: 'North Gate',
    clientName: 'Client',
    district: 'Kochi',
    dateLabel: '2026-10-14',
    checkOut: '06:10 PM',
    dutyPointName: 'Gate',
    shiftLabel: 'Day',
    status: 'Present',
  ),
];

Future<void> _mount(WidgetTester tester, {double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 800);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fieldOfficerDashboardProvider.overrideWith(
          (ref) => CompleterNever.dashboard,
        ),
        fieldOfficerGuardAttendanceProvider.overrideWith(
          (ref) => CompleterNever.entries,
        ),
        fieldOfficerGuardAttendanceHistoryProvider.overrideWith(
          (ref) async => _fixtureEntries,
        ),
        fieldOfficerAttendanceSitesProvider.overrideWith(
          (ref) async => const [],
        ),
      ],
      child: MaterialApp(
        theme: buildCissTheme(Brightness.light),
        home: const FieldOfficerGuardAttendanceScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('History'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('history renders only punched records and accurate summaries', (
    tester,
  ) async {
    await _mount(tester);

    expect(find.text('Phantom Absent'), findsNothing);
    expect(find.text('Absent'), findsNothing);
    expect(find.text('HISTORY SUMMARY'), findsOneWidget);
    expect(find.text('Check-ins'), findsOneWidget);
    expect(find.text('Check-outs'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('Complete Session'), findsOneWidget);
    expect(find.text('OUT Only'), findsOneWidget);
    expect(find.text('13/10/2026'), findsOneWidget);
    expect(find.text('Check-in: 08:15 AM'), findsOneWidget);
    expect(find.text('Check-out: 05:45 PM'), findsOneWidget);
    expect(find.text('Check-in: Not recorded'), findsOneWidget);
    expect(find.text('Check-out: 06:10 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history remains readable at 320dp and 1.8 text scale', (
    tester,
  ) async {
    await _mount(tester, textScale: 1.8);
    expect(find.text('Complete Session'), findsOneWidget);
    expect(find.text('OUT Only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class CompleterNever {
  static final Completer<FieldOfficerDashboardSnapshot> _dashboard =
      Completer<FieldOfficerDashboardSnapshot>();
  static final Completer<List<FieldOfficerAttendanceEntry>> _entries =
      Completer<List<FieldOfficerAttendanceEntry>>();
  static Future<FieldOfficerDashboardSnapshot> get dashboard =>
      _dashboard.future;
  static Future<List<FieldOfficerAttendanceEntry>> get entries =>
      _entries.future;
}
