import 'dart:async';

import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

List<GuardDuty> dutyFeed(GuardDashboardSnapshot data) {
  if (data.nextShiftUnavailable) throw StateError('Duty service unavailable');
  if (data.nextShiftSiteName?.trim().isNotEmpty != true) return [];
  return [
    GuardDuty.fromJson({
      'id': 'assignment-a',
      'kind': 'assigned',
      'status': 'assigned',
      'siteName': data.nextShiftSiteName,
      'date': data.nextShiftDate,
      'shiftLabel': data.nextShiftLabel,
    }),
  ];
}

List<GuardDuty> feedFixture({
  String? site = 'Central post',
  String? shift = 'Night duty',
}) => dutyFeed(dashboardFixture(site: site, shift: shift));

Future<void> mountDuty(
  WidgetTester tester,
  GuardDashboardSnapshot data, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    guardTestApp(
      screen: const GuardDutiesScreen(),
      brightness: brightness,
      scale: scale,
      overrides: <Override>[
        guardDutiesProvider.overrideWith((ref) async => dutyFeed(data)),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('failed pull-to-refresh settles and presents a retry state', (
    tester,
  ) async {
    var attempt = 0;
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(),
        overrides: <Override>[
          guardDutiesProvider.overrideWith((ref) async {
            if (attempt++ == 0) return feedFixture(shift: 'Day');
            throw Exception('Refresh fixture unavailable');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final refresh =
        tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
    await expectLater(refresh, completes);
    await tester.pumpAndSettle();
    expect(find.text('Could not load duties'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'own assigned duty uses server feed and has no willingness controls',
    (tester) async {
      await mountDuty(tester, dashboardFixture(shift: '08:00–16:00'));
      expect(find.text('Central post'), findsOneWidget);
      expect(find.textContaining('14 Oct 2026'), findsOneWidget);
      expect(find.text('08:00–16:00'), findsOneWidget);
      expect(find.text('Willing'), findsNothing);
      expect(find.text('Not willing'), findsNothing);
      expect(find.textContaining('sent'), findsNothing);
    },
  );

  for (final site in <String?>[null, '   ']) {
    testWidgets(
      'missing site $site is an empty assignment with independent attendance copy',
      (tester) async {
        await mountDuty(
          tester,
          dashboardFixture(site: site, shift: '  ', date: ' '),
        );
        expect(find.text('No upcoming assignment'), findsOneWidget);
        expect(find.textContaining('without an assigned duty'), findsOneWidget);
      },
    );
  }

  testWidgets('next-shift query failure is distinct from no assignment', (
    tester,
  ) async {
    await mountDuty(tester, dashboardFixture(site: null, unavailable: true));
    expect(find.text('Could not load duties'), findsOneWidget);
    expect(find.text('No upcoming assignment'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('server display date is preserved when not ISO', (tester) async {
    await mountDuty(tester, dashboardFixture(date: 'Tomorrow, 08:00'));
    expect(find.text('Tomorrow, 08:00'), findsOneWidget);
  });

  testWidgets('error retries feed and refresh waits for replacement snapshot', (
    tester,
  ) async {
    final pending = Completer<List<GuardDuty>>();
    var attempt = 0;
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(),
        overrides: <Override>[
          guardDutiesProvider.overrideWith((ref) async {
            if (attempt++ == 0) throw Exception('Fixture duty failure');
            if (attempt == 2) return feedFixture();
            return pending.future;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load duties'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Central post'), findsOneWidget);
    var completed = false;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh()
        .then((_) => completed = true);
    await tester.pump();
    expect(completed, isFalse);
    pending.complete(feedFixture(site: 'New post'));
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('New post'), findsOneWidget);
    expect(completed, isTrue);
  });

  testWidgets('loading is scrollable and does not imply no assignment', (
    tester,
  ) async {
    final pending = Completer<List<GuardDuty>>();
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDutiesScreen(),
        overrides: <Override>[
          guardDutiesProvider.overrideWith((ref) => pending.future),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('No upcoming assignment'), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
    pending.complete(feedFixture());
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets('long duty fields fit narrow large-text $brightness', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mountDuty(
        tester,
        dashboardFixture(
          site:
              'Government Examination Campus With Extended Site Address And Name',
          shift:
              'Night duty covering the extended examination period from 08:00 to 20:00',
          date: 'Extended server date label for upcoming examination duty',
        ),
        brightness: brightness,
        scale: 1.8,
      );
      expect(find.textContaining('Government Examination'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
