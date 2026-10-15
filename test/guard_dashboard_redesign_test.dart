import 'dart:async';

import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';
import 'package:ciss_mobile/core/models/training_models.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:ciss_mobile/core/sync/providers.dart';
import 'package:ciss_mobile/core/offline/offline_queue.dart';
import 'package:ciss_mobile/core/fcm/notification_service.dart';
import 'package:ciss_mobile/features/guard/guard_tab_provider.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_dashboard_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_training_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_training_leaderboard_screen.dart';
import 'package:ciss_mobile/shared/widgets/metric_card.dart';
import 'package:ciss_mobile/shared/widgets/primary_action.dart';
import 'package:ciss_mobile/shared/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

Future<void> mount(
  WidgetTester tester, {
  GuardDashboardSnapshot? data,
  List<Override> extra = const <Override>[],
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    guardTestApp(
      screen: const GuardDashboardScreen(),
      brightness: brightness,
      scale: scale,
      overrides: <Override>[
        guardDashboardProvider.overrideWith(
          (ref) async => data ?? dashboardFixture(),
        ),
        ...extra,
      ],
    ),
  );
  await tester.pumpAndSettle();
}

class _PendingQueue extends OfflineQueue {
  @override
  int get queueSize => 100;
}

void main() {
  testWidgets('failed pull-to-refresh settles and presents a retry state', (
    tester,
  ) async {
    var attempt = 0;
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDashboardScreen(),
        overrides: <Override>[
          guardDashboardProvider.overrideWith((ref) async {
            if (attempt++ == 0) return dashboardFixture(shift: 'Day');
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
    expect(find.text('Could not load dashboard'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final site in <String?>['Central post', null, '  ']) {
    testWidgets(
      'attendance stays independent with site $site and arbitrary duty label',
      (tester) async {
        await mount(tester, data: dashboardFixture(site: site));
        expect(find.byType(PrimaryAction), findsOneWidget);
        expect(find.text('Mark attendance'), findsOneWidget);
        expect(find.text('Check out'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(GuardDashboardScreen)),
        );
        await tester.tap(find.byType(PrimaryAction));
        await tester.pump();
        expect(container.read(guardTabIndexProvider), 1);
        if (site == null || site.trim().isEmpty) {
          expect(find.textContaining('without an assigned duty'), findsWidgets);
        }
      },
    );
  }

  testWidgets(
    'unavailable duty preserves attendance and avoids empty-assignment claim',
    (tester) async {
      await mount(
        tester,
        data: dashboardFixture(site: null, unavailable: true),
      );
      expect(find.text('Mark attendance'), findsOneWidget);
      expect(find.text('Duty details are unavailable'), findsOneWidget);
      expect(find.text('No upcoming assignment'), findsNothing);
    },
  );

  testWidgets('Home duty summary opens supported duty detail', (tester) async {
    await mount(tester, data: dashboardFixture(shift: '08:00–16:00'));
    await tester.tap(find.text('Your duty'));
    await tester.pumpAndSettle();
    expect(find.byType(GuardDutiesScreen), findsOneWidget);
  });

  testWidgets(
    'all optional shortcuts follow remote module gates including patrol',
    (tester) async {
      await mount(
        tester,
        extra: <Override>[
          remoteConfigProvider.overrideWith(
            () => FixedConfig(<String, bool>{
              'payslips': false,
              'leave': false,
              'patrol': false,
              'incidents': false,
              'training': false,
            }),
          ),
        ],
      );
      for (final label in <String>[
        'Payslips',
        'Leave',
        'Patrol',
        'Incidents',
        'Training',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.textContaining('Upcoming dut'), findsOneWidget);
    },
  );

  testWidgets('Training opens assignments and keeps leaderboard access there', (
    tester,
  ) async {
    await mount(
      tester,
      extra: <Override>[
        guardTrainingProvider.overrideWith((ref) async => []),
        guardTrainingLeaderboardProvider.overrideWith(
          (ref) async => GuardTrainingLeaderboard.fromJson(<String, dynamic>{}),
        ),
      ],
    );
    await tester.scrollUntilVisible(find.text('Training'), 220);
    await tester.ensureVisible(find.text('Training'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle();
    expect(find.byType(GuardTrainingScreen), findsOneWidget);
    expect(find.text('Training Leaderboard'), findsOneWidget);
    await tester.ensureVisible(find.text('Training Leaderboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training Leaderboard'));
    await tester.pumpAndSettle();
    expect(find.byType(GuardTrainingLeaderboardScreen), findsOneWidget);
  });

  testWidgets('month counts show recorded days without absent totals', (
    tester,
  ) async {
    await mount(tester, data: dashboardFixture(absentDays: 99));
    await tester.scrollUntilVisible(find.text('Present'), 240);
    expect(find.byType(MetricCard), findsNothing);
    expect(find.text('Absent'), findsNothing);
    expect(find.text('99'), findsNothing);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final width in <double>[320, 360]) {
      testWidgets(
        'long identity and activity fit $width $brightness at large text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 800);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mount(
            tester,
            brightness: brightness,
            scale: 1.8,
            data: dashboardFixture(
              name: 'Alexandria Rajalakshmi Krishnamurthy Long Family Name',
              district: 'Thiruvananthapuram District With Extended Coverage',
              site:
                  'Central Government Examination Campus With Extended Address',
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -4000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final list = tester.widget<ListView>(find.byType(ListView).first);
          expect(
            (list.padding! as EdgeInsets).bottom,
            greaterThanOrEqualTo(112),
          );
        },
      );
    }
  }

  testWidgets(
    'pending sync and notifications fit alongside long identity at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(
        tester,
        scale: 1.8,
        data: dashboardFixture(name: 'Extended Employee Family Name'),
        extra: <Override>[
          offlineQueueProvider.overrideWith((ref) => _PendingQueue()),
          NotificationService.unreadCountProvider.overrideWith(
            (ref) => Stream.value(7),
          ),
        ],
      );
      expect(find.text('100 pending'), findsOneWidget);
      expect(
        tester.getSize(find.byType(SyncStatusBadge)).height,
        greaterThanOrEqualTo(44),
      );
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending sync utility has a usable touch target at default text size',
    (tester) async {
      await mount(
        tester,
        extra: <Override>[
          offlineQueueProvider.overrideWith((ref) => _PendingQueue()),
        ],
      );
      expect(
        tester.getSize(find.byType(SyncStatusBadge)).height,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets('whitespace name falls back to short employee id safely', (
    tester,
  ) async {
    await mount(tester, data: dashboardFixture(name: '  ', employeeId: 'Q'));
    expect(find.text('Q'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading preserves attendance and composed placeholders', (
    tester,
  ) async {
    final pending = Completer<GuardDashboardSnapshot>();
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDashboardScreen(),
        overrides: <Override>[
          guardDashboardProvider.overrideWith((ref) => pending.future),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Mark attendance'), findsOneWidget);
    expect(find.byType(PrimaryAction), findsOneWidget);
    pending.complete(dashboardFixture());
    await tester.pumpAndSettle();
  });

  testWidgets('error keeps attendance reachable and retry settles', (
    tester,
  ) async {
    var attempt = 0;
    await tester.pumpWidget(
      guardTestApp(
        screen: const GuardDashboardScreen(),
        overrides: <Override>[
          guardDashboardProvider.overrideWith((ref) async {
            if (attempt++ == 0) throw Exception('Fixture unavailable');
            return dashboardFixture();
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mark attendance'), findsOneWidget);
    expect(find.text('Could not load dashboard'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Kumar'), findsOneWidget);
  });

  testWidgets(
    'refresh future waits for server data and list supports short-content refresh',
    (tester) async {
      final pending = Completer<GuardDashboardSnapshot>();
      var attempt = 0;
      await tester.pumpWidget(
        guardTestApp(
          screen: const GuardDashboardScreen(),
          overrides: <Override>[
            guardDashboardProvider.overrideWith((ref) {
              if (attempt++ == 0) {
                return Future.value(dashboardFixture(shift: 'Day'));
              }
              return pending.future;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      var completed = false;
      final refresh = indicator.onRefresh().then((_) => completed = true);
      await tester.pump();
      expect(completed, isFalse);
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
      pending.complete(dashboardFixture(shift: 'Evening'));
      await refresh;
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(find.textContaining('Evening'), findsWidgets);
    },
  );
}
