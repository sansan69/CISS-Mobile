import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:ciss_mobile/app/router/app_router.dart';
import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/auth/biometric_service.dart';
import 'package:ciss_mobile/core/auth/app_lock_preferences.dart';
import 'package:ciss_mobile/core/fcm/providers.dart';
import 'package:ciss_mobile/core/fcm/notification_service.dart';
import 'package:ciss_mobile/core/models/duty_models.dart';
import 'package:ciss_mobile/core/models/app_role.dart';
import 'package:ciss_mobile/core/models/auth_session.dart';
import 'package:ciss_mobile/core/models/report_models.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_profile_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/widgets/duty_detail_sheet.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_work_orders_screen.dart';
import 'package:ciss_mobile/features/field_officer/presentation/widgets/work_order_willingness_sheet.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'support/guard_redesign_fixtures.dart';
import 'support/duty_core_review_support.dart' as repro;

class FakeCore extends FirebasePlatform {
  final fake = FirebaseAppPlatform(
    '[DEFAULT]',
    const FirebaseOptions(
      apiKey: 'fake',
      appId: 'fake',
      messagingSenderId: 'fake',
      projectId: 'fake',
    ),
  );
  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) => fake;
  @override
  List<FirebaseAppPlatform> get apps => [fake];
}

class RepeatedBiometrics implements BiometricService {
  final prompts = <Completer<BiometricAuthOutcome>>[];
  @override
  Future<BiometricAuthOutcome> authenticateFingerprint({
    required String localizedReason,
  }) {
    final c = Completer<BiometricAuthOutcome>();
    prompts.add(c);
    return c.future;
  }

  @override
  Future<FingerprintSupport> checkFingerprintSupport() async =>
      FingerprintSupport.unknown;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FoSession extends AuthSessionNotifier {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    role: AppRole.fieldOfficer,
    displayName: 'FO A',
    primaryId: 'FO-A',
    uid: 'auth-a',
  );
}

const payload = {
  'type': 'duty_assigned',
  'recipientUid': 'auth-a',
  'recipientRole': 'guard',
  'assignmentId': 'exam-1',
  'notifId': 'event-1',
};
GuardDuty duty() => GuardDuty.fromJson({
  'id': 'exam-1',
  'kind': 'exam',
  'status': 'open',
  'workOrderId': 'exam-1',
  'siteName': 'Private A duty site',
  'examName': 'A exam',
  'date': '2026-10-20',
  'canRespond': true,
  'willingnessVersion': 1,
});
WorkOrderModel workOrder() => WorkOrderModel.fromJson({
  'id': 'exam-1',
  'siteId': 'site-1',
  'siteName': 'Private FO duty site',
  'clientId': 'client-1',
  'clientName': 'Private client',
  'district': 'Central',
  'examName': 'FO exam',
  'examCode': 'FO-1',
  'date': '2026-10-20',
  'totalManpower': 1,
  'assignedCount': 0,
});
Future<void> frames(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

Future<ProviderContainer> setup(
  WidgetTester t,
  RepeatedBiometrics b, {
  bool withDuty = false,
  bool permissions = true,
  bool coldTap = false,
  AppRole role = AppRole.guard,
}) async {
  FirebasePlatform.instance = FakeCore();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => permissions ? 1 : 0);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  final c = ProviderContainer(
    overrides: [
      remoteConfigProvider.overrideWith(() => FixedConfig()),
      authSessionProvider.overrideWith(
        role == AppRole.guard ? repro.Session.new : FoSession.new,
      ),
      mobileRepositoryProvider.overrideWithValue(repro.Repo()),
      appLockPreferencesProvider.overrideWith(
        (ref) => AppLockPreferencesNotifier(),
      ),
      biometricServiceProvider.overrideWithValue(b),
      guardProfileProvider.overrideWith(
        (ref) async => throw StateError('fixture profile unavailable'),
      ),
      guardDutiesProvider.overrideWith((ref) async => withDuty ? [duty()] : []),
      fieldOfficerWorkOrdersProvider.overrideWith((ref) async => [workOrder()]),
      workOrderWillingnessProvider.overrideWith(
        (ref, id) async => const WorkOrderWillingness(
          workOrderId: 'exam-1',
          willingCount: 1,
          unavailableCount: 0,
          responses: [
            {
              'employeeDocId': 'private-guard-1',
              'name': 'Private Guard Name',
              'employeeId': 'E-900',
              'gender': 'male',
              'response': 'willing',
            },
          ],
        ),
      ),
      dutyResponseHistoryProvider.overrideWith((ref) => []),
      dutyResponseProvider.overrideWith((ref, id) => null),
      NotificationService.unreadCountProvider.overrideWith(
        (ref) => Stream.value(0),
      ),
    ],
  );
  final s = await c.read(authSessionProvider.future);
  c.read(appLockPreferencesProvider.notifier).setFor(s!, true);
  addTearDown(() {
    c.read(notificationServiceProvider).dispose();
    c.read(routerProvider).dispose();
    c.dispose();
  });
  if (coldTap) {
    c.read(notificationServiceProvider).navigateFromNotification(payload);
  }
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: buildCissTheme(Brightness.light),
        routerConfig: c.read(routerProvider),
      ),
    ),
  );
  await frames(t);
  return c;
}

void main() {
  testWidgets(
    'cold navigation waits for actual biometric and permission admission',
    (t) async {
      final b = RepeatedBiometrics();
      final c = await setup(t, b, coldTap: true);
      c.read(notificationServiceProvider).navigateFromNotification(payload);
      expect(find.byType(GuardDutiesScreen), findsNothing);
      expect(c.read(workspaceAccessSessionKeyProvider), isNull);
      b.prompts[0].complete(BiometricAuthOutcome.success);
      await frames(t);
      await t.pump(const Duration(seconds: 1));
      await frames(t);
      expect(c.read(workspaceAccessSessionKeyProvider), 'guard:auth-a');
      expect(find.byType(GuardDutiesScreen), findsOneWidget);
      c.read(notificationServiceProvider).dispose();
    },
  );
  testWidgets('real notification entry rejects wrong owner and wrong role', (
    t,
  ) async {
    final b = RepeatedBiometrics();
    final c = await setup(t, b);
    b.prompts[0].complete(BiometricAuthOutcome.success);
    await frames(t);
    final n = c.read(notificationServiceProvider);
    n.navigateFromNotification({...payload, 'recipientUid': 'auth-b'});
    n.navigateFromNotification({
      'type': 'duty_willingness',
      'recipientRole': 'fieldOfficer',
      'recipientUid': 'auth-a',
      'workOrderId': 'exam-1',
    });
    await frames(t);
    expect(find.byType(GuardDutiesScreen), findsNothing);
    n.dispose();
  });

  testWidgets('late permission check cannot readmit a relocked guard', (
    t,
  ) async {
    final b = RepeatedBiometrics();
    final c = await setup(t, b);
    final held = <Completer<int>>[];
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          final d = Completer<int>();
          held.add(d);
          return d.future;
        });
    c.read(notificationServiceProvider).navigateFromNotification(payload);
    b.prompts[0].complete(BiometricAuthOutcome.success);
    await frames(t);
    expect(held.length, 3);
    expect(c.read(workspaceAccessSessionKeyProvider), isNull);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(t);
    expect(b.prompts.length, 2);
    for (final d in held) {
      d.complete(1);
    }
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await frames(t);
    c.read(notificationServiceProvider).dispose();
    expect(find.byType(GuardDutiesScreen), findsNothing);
  });

  testWidgets(
    'guard workspace access is restored after real relock and unlock',
    (t) async {
      final b = RepeatedBiometrics();
      final c = await setup(t, b);
      b.prompts[0].complete(BiometricAuthOutcome.success);
      await frames(t);
      expect(c.read(workspaceAccessSessionKeyProvider), 'guard:auth-a');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(t);
      expect(c.read(workspaceAccessSessionKeyProvider), isNull);
      expect(b.prompts.length, 2);
      b.prompts[1].complete(BiometricAuthOutcome.success);
      await frames(t);
      expect(c.read(workspaceAccessSessionKeyProvider), 'guard:auth-a');
    },
  );
  testWidgets('a notification detail sheet closes on relock', (t) async {
    final b = RepeatedBiometrics();
    final c = await setup(t, b, withDuty: true);
    b.prompts[0].complete(BiometricAuthOutcome.success);
    await frames(t);
    c.read(notificationServiceProvider).navigateFromNotification(payload);
    await frames(t);
    await frames(t);
    expect(find.byType(DutyDetailSheet), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(t);
    await frames(t);
    expect(find.byType(DutyDetailSheet), findsNothing);
    expect(find.text('Private A duty site'), findsNothing);
    expect(find.byType(GuardDutiesScreen, skipOffstage: false), findsNothing);
  });
  testWidgets('a notification detail sheet closes when account signs out', (
    t,
  ) async {
    final b = RepeatedBiometrics();
    final c = await setup(t, b, withDuty: true);
    b.prompts[0].complete(BiometricAuthOutcome.success);
    await frames(t);
    c.read(notificationServiceProvider).navigateFromNotification(payload);
    await frames(t);
    await frames(t);
    expect(find.byType(DutyDetailSheet), findsOneWidget);
    c.read(authSessionProvider.notifier).clearSession();
    await frames(t);
    await frames(t);
    expect(find.byType(DutyDetailSheet), findsNothing);
    expect(find.byType(GuardDutiesScreen, skipOffstage: false), findsNothing);
  });

  testWidgets(
    'a notification detail sheet closes when deployment graph changes',
    (t) async {
      final b = RepeatedBiometrics();
      final c = await setup(t, b, withDuty: true);
      b.prompts[0].complete(BiometricAuthOutcome.success);
      await frames(t);
      c.read(notificationServiceProvider).navigateFromNotification(payload);
      await frames(t);
      await frames(t);
      expect(find.byType(DutyDetailSheet), findsOneWidget);

      c.read(regionGraphRevisionProvider.notifier).state++;
      await frames(t);
      await frames(t);
      expect(c.read(workspaceAccessSessionKeyProvider), isNull);
      expect(find.byType(DutyDetailSheet), findsNothing);
      expect(find.text('Private A duty site'), findsNothing);
      expect(find.byType(GuardDutiesScreen, skipOffstage: false), findsNothing);
    },
  );
  testWidgets('duplicate notification tap does not stack another duty route', (
    t,
  ) async {
    final b = RepeatedBiometrics();
    final c = await setup(t, b);
    b.prompts[0].complete(BiometricAuthOutcome.success);
    await frames(t);
    final n = c.read(notificationServiceProvider);
    n.navigateFromNotification(payload);
    await frames(t);
    n.navigateFromNotification(payload);
    await frames(t);
    expect(find.byType(GuardDutiesScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'closing a destination permits intentional reopen and other records remain navigable',
    (t) async {
      final b = RepeatedBiometrics();
      final c = await setup(t, b);
      b.prompts[0].complete(BiometricAuthOutcome.success);
      await frames(t);
      final n = c.read(notificationServiceProvider);
      n.navigateFromNotification(payload);
      await frames(t);
      expect(
        find.byType(GuardDutiesScreen, skipOffstage: false),
        findsOneWidget,
      );
      c.read(routerProvider).pop();
      await frames(t);
      n.navigateFromNotification(payload);
      await frames(t);
      expect(
        find.byType(GuardDutiesScreen, skipOffstage: false),
        findsOneWidget,
      );
      n.navigateFromNotification({
        ...payload,
        'assignmentId': 'exam-2',
        'notifId': 'event-2',
      });
      await frames(t);
      expect(
        find.byType(GuardDutiesScreen, skipOffstage: false),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'field officer willingness modal hides and closes when admission is revoked',
    (t) async {
      final b = RepeatedBiometrics();
      final c = await setup(t, b, role: AppRole.fieldOfficer);
      b.prompts[0].complete(BiometricAuthOutcome.success);
      await frames(t);
      await frames(t);
      c.read(notificationServiceProvider).navigateFromNotification({
        'type': 'duty_willingness',
        'recipientUid': 'auth-a',
        'recipientRole': 'fieldOfficer',
        'workOrderId': 'exam-1',
        'notifId': 'fo-event-1',
      });
      await frames(t);
      await frames(t);
      expect(find.byType(WorkOrderWillingnessSheet), findsOneWidget);
      expect(find.text('Private Guard Name'), findsOneWidget);
      c.read(workspaceAccessSessionKeyProvider.notifier).state = null;
      await frames(t);
      await frames(t);
      expect(find.byType(WorkOrderWillingnessSheet), findsNothing);
      expect(find.text('Private Guard Name'), findsNothing);
    },
  );
  testWidgets(
    'notification waits for onboarding even after biometric succeeds',
    (t) async {
      final b = RepeatedBiometrics();
      final c = await setup(t, b, permissions: false);
      c.read(notificationServiceProvider).navigateFromNotification(payload);
      b.prompts[0].complete(BiometricAuthOutcome.success);
      await frames(t);
      await t.pump(const Duration(seconds: 2));
      await frames(t);
      expect(c.read(workspaceAccessSessionKeyProvider), isNull);
      expect(find.byType(GuardDutiesScreen), findsNothing);
      c.read(notificationServiceProvider).dispose();
    },
  );
}
