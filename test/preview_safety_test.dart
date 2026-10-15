import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/dev/preview_safety.dart';
import 'package:ciss_mobile/core/sync/providers.dart';
import 'package:ciss_mobile/core/fcm/providers.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/guard/presentation/guard_shell.dart';
import 'package:ciss_mobile/features/field_officer/presentation/field_officer_shell.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_dashboard_screen.dart';
import 'package:flutter/services.dart';
import 'package:ciss_mobile/dev/preview_harness.dart';
import 'package:ciss_mobile/dev/preview_harness.dart' as preview;
import 'package:ciss_mobile/dev/mock_data.dart';
import 'package:ciss_mobile/app/theme/app_tokens.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_assignments_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_dashboard_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/widgets/duty_detail_sheet.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_training_screen.dart';
import 'package:ciss_mobile/features/shared/notification_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openPreview(
  WidgetTester tester,
  String label, {
  String group = 'Guard',
}) async {
  await tester.pumpWidget(previewHarnessApp());
  await tester.pumpAndSettle();
  final fixture = find.byKey(ValueKey('preview-$group-$label'));
  await tester.scrollUntilVisible(fixture, 200);
  await tester.ensureVisible(fixture);
  await tester.pumpAndSettle();
  await tester.tap(fixture);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'preview blocks the isolated willingness spool before storage',
    () async {
      final container = ProviderContainer(overrides: previewSafetyOverrides());
      addTearDown(container.dispose);
      await expectLater(
        Future.sync(
          () => container
              .read(willingnessQueueProvider)
              .choose(
                ownerUid: 'preview',
                apiBaseUrl: 'https://a.invalid',
                workOrderId: 'exam-a',
                response: WillingnessStatus.willing,
                expectedVersion: 0,
              ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message.toString(),
            'reason',
            contains('Preview blocks'),
          ),
        ),
      );
    },
  );
  testWidgets(
    'eligible TCS preview has real interest controls and writes fail closed',
    (tester) async {
      await openPreview(tester, 'Duty — eligible TCS');
      final dutyScreen = tester.element(find.byType(GuardDutiesScreen));
      final fixtureContainer = ProviderScope.containerOf(dutyScreen);
      final fixtureSession = await fixtureContainer.read(
        authSessionProvider.future,
      );
      expect(fixtureSession?.uid, 'mock-uid-guard');
      expect(
        fixtureContainer.read(workspaceAccessSessionKeyProvider),
        'guard:mock-uid-guard',
      );
      await tester.tap(find.text('District examination centre'));
      await tester.pumpAndSettle();
      expect(find.byType(DutyDetailSheet), findsOneWidget);
      expect(find.text('Save response'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<WillingnessStatus>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Willing').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save response'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No data was sent or saved'), findsOneWidget);
      expect(find.textContaining('Response saved:'), findsNothing);
    },
  );

  // The feed already said an administrator must set the category, but the duty
  // fixture still carried canRespond:true, so the same sheet offered a response
  // control. A real unclassified guard is not eligible to respond.
  testWidgets('unclassified preview fixture cannot respond', (tester) async {
    await openPreview(tester, 'Duty — category not set');
    expect(find.text('Responses closed'), findsOneWidget);
    await tester.tap(find.text('District examination centre'));
    await tester.pumpAndSettle();
    expect(find.text('Save response'), findsNothing);
    expect(
      find.byType(DropdownButtonFormField<WillingnessStatus>),
      findsNothing,
    );
    expect(
      find.text(
        'Your category must be set by an administrator before you can respond to exam duties.',
      ),
      findsWidgets,
    );
    expect(find.textContaining('Response saved:'), findsNothing);
  });

  testWidgets('response result fixtures stay visible without a matching duty', (
    tester,
  ) async {
    await openPreview(tester, 'Duty — rejected result, missing duty');
    expect(find.text('Response not sent'), findsOneWidget);
    expect(
      find.text(
        'Responses closed before this queued response reached the server.',
      ),
      findsOneWidget,
    );
    expect(find.text('Refresh duties'), findsOneWidget);
    expect(find.text('No upcoming assignment'), findsOneWidget);
  });

  testWidgets('pending result fixture survives a duty feed error', (
    tester,
  ) async {
    await openPreview(tester, 'Duty — pending result, feed error');
    expect(find.text('Response pending'), findsOneWidget);
    expect(find.text('Your response has not been saved yet.'), findsOneWidget);
    expect(find.text('Sync pending response'), findsOneWidget);
    expect(find.text('Refresh duties'), findsOneWidget);
    expect(find.text('Could not load duties'), findsOneWidget);
  });

  testWidgets('preview large-text control applies 1.8 scaling', (tester) async {
    await openPreview(tester, 'Duty — pending result, feed error');
    await tester.tap(find.byTooltip('Toggle large preview text'));
    await tester.pumpAndSettle();
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(GuardDutiesScreen)),
      ).scale(10),
      18,
    );
  });

  setUpAll(() async {
    // Use the bundled production font when exercising the unchanged attendance
    // tabs; the test-only Ahem font is wider than these native control labels.
    final font = FontLoader('Inter');
    for (final weight in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
    }
    await font.load();
  });
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(360, 800);
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) async =>
              call.method == 'isLocationServiceEnabled' ? false : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/geolocator'),
            null,
          ),
    );
  });
  testWidgets(
    'standalone preview enables the production edge-to-edge system mode',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await Future<void>.sync(() => preview.main());
      await tester.pumpAndSettle();
      final modeCalls = calls.where(
        (call) => call.method == 'SystemChrome.setEnabledSystemUIMode',
      );
      expect(modeCalls, hasLength(1));
      expect(modeCalls.single.arguments, 'SystemUiMode.edgeToEdge');
    },
  );

  testWidgets(
    'preview theme toggle applies matching Android navigation bar styling',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(previewHarnessApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Toggle preview theme'));
      await tester.pumpAndSettle();
      final darkStyle =
          calls
                  .lastWhere(
                    (call) =>
                        call.method == 'SystemChrome.setSystemUIOverlayStyle',
                  )
                  .arguments
              as Map;
      expect(
        darkStyle['systemNavigationBarColor'],
        CissThemeTokens.dark().canvas.toARGB32(),
      );
      expect(
        darkStyle['systemNavigationBarIconBrightness'],
        'Brightness.light',
      );
      expect(darkStyle['systemNavigationBarContrastEnforced'], isFalse);
      await tester.tap(find.byTooltip('Toggle preview theme'));
      await tester.pumpAndSettle();
      final lightStyle =
          calls
                  .lastWhere(
                    (call) =>
                        call.method == 'SystemChrome.setSystemUIOverlayStyle',
                  )
                  .arguments
              as Map;
      expect(
        lightStyle['systemNavigationBarColor'],
        CissThemeTokens.light().canvas.toARGB32(),
      );
      expect(
        lightStyle['systemNavigationBarIconBrightness'],
        'Brightness.dark',
      );
    },
  );

  testWidgets(
    'preview root installs a repository boundary before any fixture opens',
    (tester) async {
      await tester.pumpWidget(previewHarnessApp());
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PreviewHarnessScreen)),
      );
      final repository = scope.read(mobileRepositoryProvider);
      expect(
        () =>
            repository.postGeneric('/api/guard/incidents', <String, dynamic>{}),
        throwsA(
          isA<StateError>().having(
            (error) => error.message.toString(),
            'reason',
            contains('Preview blocks'),
          ),
        ),
      );
      expect(
        () => repository.fetchGuardDashboard(),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repository.markAllNotificationsAsRead(),
        throwsA(isA<StateError>()),
      );
    },
  );

  testWidgets(
    'preview sync, queue, notification and auth mutations fail closed',
    (tester) async {
      await tester.pumpWidget(previewHarnessApp());
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PreviewHarnessScreen)),
      );
      expect(
        () => scope.read(syncServiceProvider).processQueue(),
        throwsA(isA<StateError>()),
      );
      expect(
        () => scope
            .read(offlineQueueProvider)
            .enqueue(path: '/api/attendance', method: 'POST', body: {}),
        throwsA(isA<StateError>()),
      );
      expect(
        () => scope.read(notificationServiceProvider).markAllAsRead(),
        throwsA(isA<StateError>()),
      );
      expect(
        () => scope.read(authControllerProvider).signOut(),
        throwsA(isA<StateError>()),
      );
    },
  );

  testWidgets(
    'Guard shell preloads fixtures and preserves attendance tab one',
    (tester) async {
      await openPreview(tester, 'Shell (4-tab nav)');
      expect(find.byType(GuardShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mark attendance'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(GuardDashboardScreen), findsNothing);
    },
  );

  for (final label in <String>['Dashboard', 'Shell']) {
    testWidgets('FO $label retains shared-header fixture safely', (
      tester,
    ) async {
      await openPreview(tester, label, group: 'FO');
      expect(find.byType(FieldOfficerDashboardScreen), findsOneWidget);
      if (label == 'Shell') {
        expect(find.byType(FieldOfficerShell), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'role preview overrides config and retains safe scope on pushed Duties and Training',
    (tester) async {
      await openPreview(tester, 'Dashboard');
      expect(tester.takeException(), isNull);
      expect(find.byType(GuardDashboardScreen), findsOneWidget);
      await tester.tap(find.text('View duty details'));
      await tester.pumpAndSettle();
      expect(find.byType(GuardDutiesScreen), findsOneWidget);
      expect(find.textContaining('Main Branch'), findsOneWidget);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(GuardDutiesScreen)),
      );
      expect(
        () => scope.read(mobileRepositoryProvider).fetchGuardDashboard(),
        throwsA(isA<StateError>()),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Training'), 240);
      await tester.ensureVisible(find.text('Training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Training'));
      await tester.pumpAndSettle();
      expect(find.byType(GuardTrainingScreen), findsOneWidget);
      expect(find.text('Could not load training'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android hardware back returns from duty to fixture Home before closing preview',
    (tester) async {
      await openPreview(tester, 'Dashboard');
      await tester.tap(find.text('View duty details'));
      await tester.pumpAndSettle();
      expect(find.byType(GuardDutiesScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(GuardDashboardScreen), findsOneWidget);
      expect(find.byType(GuardDutiesScreen), findsNothing);
      expect(find.byTooltip('Close preview'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Design Preview'), findsOneWidget);
      await openPreview(tester, 'Dashboard');
      await tester.tap(find.text('View duty details'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(find.text('Design Preview'), findsOneWidget);
    },
  );

  testWidgets('notification inbox stays local when opened from Home', (
    tester,
  ) async {
    await openPreview(tester, 'Dashboard');
    await tester.tap(find.byIcon(Icons.notifications_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationInboxScreen), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview theme switch is available inside fixtures', (
    tester,
  ) async {
    await openPreview(tester, 'Dashboard');
    expect(find.byTooltip('Toggle preview theme'), findsOneWidget);
    await tester.tap(find.byTooltip('Toggle preview theme'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(GuardDashboardScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('FO duty preview never claims a saved assignment', (
    tester,
  ) async {
    await openPreview(tester, 'Scheduled duties', group: 'FO');
    await tester.tap(find.text('Schedule duty'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('District examination centre · $mockDistrict').last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night · 22:00–06:00').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Duty date'),
      '2026-10-20',
    );
    await tester.ensureVisible(find.text('Rahul Kumar'));
    await tester.tap(find.text('Rahul Kumar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create assignments'));
    await tester.tap(find.text('Create assignments'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No data was sent or saved'), findsWidgets);
    expect(find.textContaining(': saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview blocks every remaining duty write and scope reader', (
    tester,
  ) async {
    await openPreview(tester, 'Scheduled duties', group: 'FO');
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(FieldOfficerAssignmentsScreen)),
    );
    final repository = scope.read(mobileRepositoryProvider);
    final blocked = isA<StateError>().having(
      (error) => error.message.toString(),
      'reason',
      contains('Preview blocks'),
    );
    expect(
      () => repository.createGuardAssignment(<String, dynamic>{
        'employeeDocId': 'employee_preview',
      }),
      throwsA(blocked),
    );
    expect(
      () => repository.updateGuardAssignment(
        'assignment_preview',
        <String, dynamic>{'status': 'cancelled'},
      ),
      throwsA(blocked),
    );
    expect(
      () => repository.setDutyWillingness(
        workOrderId: 'exam_preview',
        response: WillingnessStatus.willing,
        clientRequestId: 'uuid',
        expectedVersion: 0,
      ),
      throwsA(blocked),
    );
    // Fixture reads stay local: no HTTP/Firebase client is ever built for them.
    expect((await repository.fetchGuardAssignments()).first.id, isNotEmpty);
    expect(
      (await repository.fetchWorkOrderWillingness('exam_preview')).workOrderId,
      'exam_preview',
    );
    expect(() => repository.fetchGuardDuties(), throwsA(blocked));
    expect(() => repository.fetchNotifications(), throwsA(blocked));
    expect(() => scope.read(apiClientProvider), throwsA(isA<StateError>()));
    expect(() => scope.read(firebaseAuthProvider), throwsA(isA<StateError>()));
    expect(
      () => scope.read(regionServiceProvider).fetchAvailableRegions(),
      throwsA(blocked),
    );
  });

  for (final state in <String>['pending response', 'rejected response']) {
    testWidgets('preview $state never claims a saved response', (tester) async {
      await openPreview(tester, 'Duty — $state');
      if (state == 'pending response') {
        expect(find.text('Pending — not yet saved'), findsOneWidget);
      } else {
        expect(find.textContaining('Response not sent:'), findsOneWidget);
      }
      expect(find.textContaining('Response saved:'), findsNothing);
      await tester.tap(find.text('District examination centre'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh duty details'), findsOneWidget);
      expect(find.textContaining('Response saved:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final label in <String>[
    'Home — no assignment',
    'Home — duty unavailable',
    'Home — loading',
    'Home — error',
    'Home — long content',
    'Upcoming duty',
    'Duty — no assignment',
    'Duty — unavailable',
    'Duty — loading',
    'Duty — error',
  ]) {
    testWidgets(
      'safe state fixture $label opens without actual service bootstrap',
      (tester) async {
        await openPreview(tester, label);
        expect(tester.takeException(), isNull);
        expect(
          find.byType(GuardDashboardScreen).evaluate().isNotEmpty ||
              find.byType(GuardDutiesScreen).evaluate().isNotEmpty,
          isTrue,
        );
      },
    );
  }
}
