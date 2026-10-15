import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/cache/preload_controller.dart';
import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/location/tracking_health.dart';
import 'package:ciss_mobile/core/permissions/device_readiness.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/dev/mock_data.dart';
import 'package:ciss_mobile/dev/preview_safety.dart';
import 'package:ciss_mobile/features/field_officer/presentation/field_officer_shell.dart';
import 'package:ciss_mobile/features/field_officer/presentation/pdf/muster_roll_pdf.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_attendance_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_reports_screen.dart';
import 'package:ciss_mobile/features/shared/language_screen.dart';
import 'package:ciss_mobile/features/shared/tracking_health_card.dart';
import 'package:ciss_mobile/core/fcm/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';


class _TestLanguage extends AppLanguageController {
  _TestLanguage(AppLanguage language) {
    setLanguage(language);
  }

  void setLanguage(AppLanguage language) => state = language;
}

/// Records what the user asked to repair without touching platform channels.
class _FakeReadiness implements ReadinessSource {
  _FakeReadiness(this.snapshot);

  ReadinessSnapshot snapshot;
  final List<ReadinessItem> requests = <ReadinessItem>[];

  @override
  Future<ReadinessSnapshot> read() async => snapshot;

  @override
  Future<String> manufacturer() async => snapshot.manufacturer;

  @override
  Future<ReadinessState> request(ReadinessItem item) async {
    requests.add(item);
    final items = Map<ReadinessItem, ReadinessState>.from(snapshot.items);
    items[item] = ReadinessState.granted;
    snapshot = ReadinessSnapshot(items, manufacturer: snapshot.manufacturer);
    return ReadinessState.granted;
  }

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<bool> openBatteryOptimizationSettings() async => true;

  @override
  Future<bool> openAutostartSettings() async => true;
}

class _FakeTrackingService implements TrackingServiceProbe {
  const _FakeTrackingService(this.state);

  final TrackingServiceState state;

  @override
  Future<TrackingServiceState> read() async => state;
}

ReadinessSnapshot _readinessSnapshot(
  Map<ReadinessItem, ReadinessState> overrides,
) {
  final items = <ReadinessItem, ReadinessState>{
    for (final item in ReadinessItem.values) item: ReadinessState.granted,
  };
  items.addAll(overrides);
  return ReadinessSnapshot(items, manufacturer: 'Xiaomi');
}

class _NoopPreload implements PreloadController {
  @override
  void preloadAllGuard() {}

  @override
  void preloadAllFieldOfficer() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _shellOverrides({int unread = 0, AppLanguage? language}) {
  return <Override>[
    ...previewSafetyOverrides(),
    preloadControllerProvider.overrideWith((ref) => _NoopPreload()),
    mobileRepositoryProvider.overrideWithValue(ReadOnlyDutyPreviewRepository()),
    fieldOfficerDashboardProvider.overrideWith(
      (ref) async => mockFieldOfficerDashboard,
    ),
    fieldOfficerGuardsProvider.overrideWith(
      (ref) async => mockFieldOfficerGuards,
    ),
    fieldOfficerGuardAttendanceProvider.overrideWith(
      (ref) async => mockFieldOfficerAttendance,
    ),
    fieldOfficerGuardAttendanceHistoryProvider.overrideWith(
      (ref) async => mockFieldOfficerAttendance,
    ),
    fieldOfficerAttendanceSitesProvider.overrideWith((ref) async => const []),
    fieldOfficerVisitReportsProvider.overrideWith(
      (ref) async => mockVisitReports,
    ),
    fieldOfficerTrainingReportsProvider.overrideWith(
      (ref) async => mockTrainingReports,
    ),
    NotificationService.unreadCountProvider.overrideWith(
      (ref) => Stream<int>.value(unread),
    ),
    if (language != null)
      appLanguageControllerProvider.overrideWith(
        (ref) => _TestLanguage(language),
      ),
  ];
}

Future<void> _pumpShell(
  WidgetTester tester, {
  int unread = 0,
  AppLanguage? language,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(411, 914);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _shellOverrides(unread: unread, language: language),
      child: MaterialApp(
        theme: buildCissTheme(Brightness.light),
        // Mirrors app.dart: the scope publishes the active language to the tree.
        home: Consumer(
          builder:
              (BuildContext context, WidgetRef ref, Widget? child) =>
                  AppStringsScope(
                    strings: AppStrings.forLanguage(
                      ref.watch(appLanguageControllerProvider),
                    ),
                    child: child!,
                  ),
          child: const FieldOfficerShell(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bottom navigation follows the selected language', (
    tester,
  ) async {
    await _pumpShell(tester, language: AppLanguage.hindi);
    expect(find.text('होम'), findsOneWidget);
    expect(find.text('उपस्थिति'), findsOneWidget);
    expect(find.text('कर्मचारी'), findsOneWidget);
    expect(find.text('ड्यूटी'), findsOneWidget);
    expect(find.text('अधिक'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('language screen stores the choice', (tester) async {
    final controller = _TestLanguage(AppLanguage.english);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appLanguageControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildCissTheme(Brightness.light),
          home: const LanguageScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('മലയാളം'));
    await tester.pumpAndSettle();

    expect(controller.state, AppLanguage.malayalam);
  });

  testWidgets('tracking health reports missing preconditions and repairs them', (
    tester,
  ) async {
    final readiness = _FakeReadiness(
      _readinessSnapshot(const <ReadinessItem, ReadinessState>{
        ReadinessItem.location: ReadinessState.denied,
        ReadinessItem.batteryExemption: ReadinessState.denied,
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          readinessSourceProvider.overrideWithValue(readiness),
          trackingServiceProbeProvider.overrideWithValue(
            const _FakeTrackingService(TrackingServiceState.running),
          ),
        ],
        child: MaterialApp(
          theme: buildCissTheme(Brightness.light),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TrackingHealthCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The card reads device state only after an explicit check.
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('Action needed'), findsNWidgets(2));
    expect(find.text('Running'), findsOneWidget);

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(readiness.requests, <ReadinessItem>[ReadinessItem.location]);
    expect(find.text('Action needed'), findsOneWidget);
  });

  testWidgets('unread notifications appear on the navigation bar', (
    tester,
  ) async {
    await _pumpShell(tester, unread: 3);
    expect(find.text('3'), findsOneWidget);
  });

  test('muster roll PDF is a printable document that grows with records', () async {
    final base = MusterRollData(
      dateLabel: '15/10/2026',
      totalForce: 315,
      onDuty: 2,
      checkedOut: 1,
      siteOnDuty: const <String, int>{'Ernakulam centre': 2},
      rows: <MusterRollRow>[
        const MusterRollRow(
          name: 'Asha Nair',
          employeeId: 'CISS-100',
          site: 'Ernakulam centre',
          checkIn: '06:05',
          checkOut: '—',
          status: 'On duty',
        ),
      ],
      generatedAt: '15 Oct 2026, 12:00',
    );
    final bytes = await buildMusterRollPdf(base);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(2000));

    final bigger = await buildMusterRollPdf(
      MusterRollData(
        dateLabel: base.dateLabel,
        totalForce: base.totalForce,
        onDuty: base.onDuty,
        checkedOut: base.checkedOut,
        siteOnDuty: base.siteOnDuty,
        rows: <MusterRollRow>[
          ...base.rows,
          ...List<MusterRollRow>.generate(
            40,
            (index) => MusterRollRow(
              name: 'Guard $index',
              employeeId: 'CISS-${200 + index}',
              site: 'Site $index',
              checkIn: '06:0$index',
              checkOut: '18:0$index',
              status: 'Checked out',
            ),
          ),
        ],
        generatedAt: base.generatedAt,
      ),
    );
    expect(bigger.length, greaterThan(bytes.length));
  });
}
