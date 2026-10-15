import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/permissions/device_readiness.dart';
import 'package:ciss_mobile/features/auth/presentation/permission_onboarding_screen.dart';
import 'package:ciss_mobile/features/shared/device_readiness_screen.dart';
import 'package:ciss_mobile/features/shared/readiness_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/readiness_fixtures.dart';

final AppStrings english = AppStrings.forLanguage(AppLanguage.english);

/// A source whose read fails, to check what a guard sees when the platform
/// probe itself throws.
class _FailingReadiness extends FakeReadiness {
  _FailingReadiness() : super(readinessSnapshot());

  @override
  Future<ReadinessSnapshot> read() async => throw StateError('probe exploded');
}

Future<void> _pumpChecklist(
  WidgetTester tester,
  ReadinessSource source, {
  double width = 411,
  double textScale = 1.0,
  AppLanguage language = AppLanguage.english,
  VoidCallback? onFinish,
  Future<void> Function()? onStartService,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        readinessSourceProvider.overrideWithValue(source),
        readinessServiceStartProvider.overrideWithValue(
          onStartService ?? () async {},
        ),
      ],
      child: MaterialApp(
        theme: buildCissTheme(Brightness.light),
        builder:
            (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: AppStringsScope(
          strings: AppStrings.forLanguage(language),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: ReadinessChecklist(
                onFinish: onFinish ?? () {},
                onLater: onFinish ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpBanner(WidgetTester tester, ReadinessSnapshot? snapshot) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(411, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        readinessCacheProvider.overrideWith(
          (ref) => SeededReadinessCache(snapshot),
        ),
      ],
      child: MaterialApp(
        theme: buildCissTheme(Brightness.light),
        home: Scaffold(
          body: AppStringsScope(
            strings: english,
            child: ReadinessBanner(onTap: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final Map<String, ReadinessSnapshot> states = <String, ReadinessSnapshot>{
    'never asked': readinessSnapshot(
      const <ReadinessItem, ReadinessState>{
        ReadinessItem.notifications: ReadinessState.notRequested,
        ReadinessItem.location: ReadinessState.notRequested,
        ReadinessItem.backgroundLocation: ReadinessState.notRequested,
        ReadinessItem.camera: ReadinessState.notRequested,
        ReadinessItem.activityRecognition: ReadinessState.notRequested,
        ReadinessItem.batteryExemption: ReadinessState.denied,
        ReadinessItem.autostart: ReadinessState.notRequested,
      },
    ),
    'denied': readinessSnapshot(const <ReadinessItem, ReadinessState>{
      ReadinessItem.location: ReadinessState.denied,
    }),
    'permanently denied': readinessSnapshot(
      const <ReadinessItem, ReadinessState>{
        ReadinessItem.camera: ReadinessState.permanentlyDenied,
      },
    ),
    'all granted': readinessSnapshot(),
  };

  group('readiness checklist layout', () {
    for (final MapEntry<String, ReadinessSnapshot> entry in states.entries) {
      for (final double width in <double>[320, 411]) {
        for (final double scale in <double>[1.0, 1.8]) {
          testWidgets('${entry.key} renders at ${width.toInt()} dp and '
              '${scale}x text', (tester) async {
            await _pumpChecklist(
              tester,
              FakeReadiness(entry.value),
              width: width,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(find.text(english.readinessNotifications), findsOneWidget);
            expect(find.text(english.readinessAutostart), findsOneWidget);
          });
        }
      }
    }

    testWidgets('summarises progress without leaving placeholders behind', (
      tester,
    ) async {
      await _pumpChecklist(
        tester,
        FakeReadiness(
          readinessSnapshot(const <ReadinessItem, ReadinessState>{
            ReadinessItem.location: ReadinessState.denied,
            ReadinessItem.camera: ReadinessState.denied,
          }),
        ),
      );
      expect(find.text('3 of 5 steps ready'), findsOneWidget);
      // Outstanding work must never be summarised as "nothing to do".
      expect(find.text(english.readinessBannerBody), findsOneWidget);
      expect(find.text(english.readinessAllGood), findsNothing);
    });

    testWidgets('reports a fully prepared device', (tester) async {
      await _pumpChecklist(tester, FakeReadiness(readinessSnapshot()));
      expect(find.text('5 of 5 steps ready'), findsOneWidget);
      expect(find.text(english.readinessAllGood), findsOneWidget);
      expect(find.text(english.readinessAllow), findsNothing);
      expect(find.text(english.readinessOpenSettings), findsNothing);
    });
  });

  group('readiness checklist actions', () {
    testWidgets('a row CTA requests exactly the row the guard tapped', (
      tester,
    ) async {
      final source = FakeReadiness(
        readinessSnapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.camera: ReadinessState.denied,
        }),
      );
      await _pumpChecklist(tester, source);

      final allow = find.widgetWithText(FilledButton, english.readinessAllow);
      expect(allow, findsOneWidget);
      await tester.ensureVisible(allow);
      await tester.pumpAndSettle();
      await tester.tap(allow);
      await tester.pumpAndSettle();

      expect(source.requested, <ReadinessItem>[ReadinessItem.camera]);
      expect(find.text(english.readinessAllow), findsNothing);
    });

    testWidgets('a permanently denied row opens settings instead of asking', (
      tester,
    ) async {
      final source = FakeReadiness(
        readinessSnapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.backgroundLocation: ReadinessState.permanentlyDenied,
        }),
      );
      await _pumpChecklist(tester, source);

      final open = find.widgetWithText(
        FilledButton,
        english.readinessOpenSettings,
      );
      expect(open, findsOneWidget);
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();

      expect(source.settingsOpened, 1);
      expect(source.requested, isEmpty);
    });

    testWidgets('every action carries its own semantic label', (tester) async {
      await _pumpChecklist(
        tester,
        FakeReadiness(
          readinessSnapshot(const <ReadinessItem, ReadinessState>{
            ReadinessItem.notifications: ReadinessState.denied,
            ReadinessItem.camera: ReadinessState.denied,
            ReadinessItem.activityRecognition: ReadinessState.denied,
          }),
        ),
      );
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((Semantics widget) => widget.properties.label)
          .whereType<String>()
          .where((String label) => label.contains('. '))
          .toList();
      expect(labels.length, 3);
      expect(labels.toSet().length, labels.length);
    });

    testWidgets('battery and auto-start open their own settings', (
      tester,
    ) async {
      final source = FakeReadiness(
        readinessSnapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.batteryExemption: ReadinessState.denied,
          ReadinessItem.autostart: ReadinessState.notRequested,
        }),
      );
      await _pumpChecklist(tester, source);

      final battery = find.widgetWithText(
        FilledButton,
        english.readinessOpenBatterySettings,
      );
      expect(battery, findsNWidgets(2));
      await tester.ensureVisible(battery.first);
      await tester.pumpAndSettle();
      await tester.tap(battery.first);
      await tester.pumpAndSettle();
      expect(source.batteryOpened, 1);

      final autostart = find.widgetWithText(
        FilledButton,
        english.readinessOpenAutostart,
      );
      expect(autostart, findsWidgets);
      await tester.ensureVisible(autostart.first);
      await tester.pumpAndSettle();
      await tester.tap(autostart.first);
      await tester.pumpAndSettle();
      expect(source.autostartOpened, 1);
    });

    testWidgets('the vendor guide appears while the exemption is missing', (
      tester,
    ) async {
      await _pumpChecklist(tester, FakeReadiness(readinessSnapshot()));
      expect(find.textContaining('Keep CISS running'), findsNothing);

      await _pumpChecklist(
        tester,
        FakeReadiness(
          readinessSnapshot(const <ReadinessItem, ReadinessState>{
            ReadinessItem.batteryExemption: ReadinessState.denied,
          }),
        ),
      );
      expect(
        find.textContaining('Keep CISS running on Xiaomi'),
        findsOneWidget,
      );
      expect(find.text(english.label('readinessOemPathXiaomi')), findsOneWidget);
    });

    testWidgets('the vendor guide also appears for an outstanding auto-start', (
      tester,
    ) async {
      await _pumpChecklist(
        tester,
        FakeReadiness(
          readinessSnapshot(const <ReadinessItem, ReadinessState>{
            ReadinessItem.autostart: ReadinessState.notRequested,
          }),
        ),
      );
      expect(
        find.textContaining('Keep CISS running on Xiaomi'),
        findsOneWidget,
      );
      expect(find.text(english.readinessOpenAutostart), findsWidgets);
    });

    testWidgets('a vendor without its own page gets the generic recipe', (
      tester,
    ) async {
      await _pumpChecklist(
        tester,
        FakeReadiness(
          plainAndroidSnapshot(const <ReadinessItem, ReadinessState>{
            ReadinessItem.batteryExemption: ReadinessState.denied,
          }),
        ),
      );
      expect(
        find.textContaining('Keep CISS running on Android'),
        findsOneWidget,
      );
      expect(
        find.text(english.label('readinessOemPathGeneric')),
        findsOneWidget,
      );
    });

    testWidgets('the tracking service starts once, after the grant', (
      tester,
    ) async {
      var starts = 0;
      final source = FakeReadiness(
        readinessSnapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.notifications: ReadinessState.denied,
          ReadinessItem.batteryExemption: ReadinessState.denied,
        }),
      );
      await _pumpChecklist(
        tester,
        source,
        onStartService: () async => starts++,
      );

      final allow = find.widgetWithText(FilledButton, english.readinessAllow);
      await tester.ensureVisible(allow);
      await tester.pumpAndSettle();
      await tester.tap(allow);
      await tester.pumpAndSettle();
      expect(starts, 1);

      // A later settings visit must not start a second service.
      final battery = find.widgetWithText(
        FilledButton,
        english.readinessOpenBatterySettings,
      );
      await tester.ensureVisible(battery.first);
      await tester.pumpAndSettle();
      await tester.tap(battery.first);
      await tester.pumpAndSettle();
      expect(source.batteryOpened, 1);
      expect(starts, 1);
    });
  });

  group('readiness banner', () {
    testWidgets('lists the outstanding permissions', (tester) async {
      await _pumpBanner(
        tester,
        readinessSnapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.location: ReadinessState.denied,
        }),
      );
      expect(find.text(english.readinessBannerTitle), findsOneWidget);
      expect(find.textContaining(english.readinessLocationItem), findsOneWidget);
    });

    testWidgets('stays hidden when nothing blocks a punch', (tester) async {
      await _pumpBanner(tester, readinessSnapshot());
      expect(find.text(english.readinessBannerTitle), findsNothing);

      // Advisory items alone never raise the banner.
      await _pumpBanner(
        tester,
        readinessSnapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.batteryExemption: ReadinessState.denied,
        }),
      );
      expect(find.text(english.readinessBannerTitle), findsNothing);
    });

    testWidgets('stays hidden before the device has ever been checked', (
      tester,
    ) async {
      await _pumpBanner(tester, null);
      expect(find.text(english.readinessBannerTitle), findsNothing);
    });
  });

  group('onboarding', () {
    testWidgets('Later enters the app without granting anything', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 900);
      addTearDown(tester.view.reset);
      final source = FakeReadiness(
        readinessSnapshot(const <ReadinessItem, ReadinessState>{
          ReadinessItem.location: ReadinessState.denied,
        }),
      );
      final router = GoRouter(
        initialLocation: '/permissions',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('guard workspace')),
          ),
          GoRoute(
            path: '/permissions',
            builder: (_, _) => const PermissionOnboardingScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            readinessSourceProvider.overrideWithValue(source),
            readinessServiceStartProvider.overrideWithValue(() async {}),
          ],
          child: MaterialApp.router(
            theme: buildCissTheme(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(english.readinessLater), findsOneWidget);
      await tester.ensureVisible(find.text(english.readinessLater));
      await tester.pumpAndSettle();
      await tester.tap(find.text(english.readinessLater));
      await tester.pumpAndSettle();

      expect(find.text('guard workspace'), findsOneWidget);
      expect(source.requested, isEmpty);
    });
  });

  group('device setup screen', () {
    testWidgets('renders the same checklist outside onboarding', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            readinessSourceProvider.overrideWithValue(
              FakeReadiness(readinessSnapshot()),
            ),
            readinessServiceStartProvider.overrideWithValue(() async {}),
          ],
          child: MaterialApp(
            theme: buildCissTheme(Brightness.light),
            home: const DeviceReadinessScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(english.readinessNotifications), findsOneWidget);
      expect(find.text(english.readinessAllGood), findsOneWidget);
    });
  });

  group('device read failures', () {
    testWidgets('a failed probe shows recoverable copy, not the exception', (
      tester,
    ) async {
      await _pumpChecklist(tester, _FailingReadiness());

      expect(find.text(english.readinessBannerBody), findsOneWidget);
      expect(find.textContaining('probe exploded'), findsNothing);

      final retry = find.widgetWithText(
        FilledButton,
        english.readinessRecheck,
      );
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text(english.readinessBannerBody), findsOneWidget);
    });
  });
}
