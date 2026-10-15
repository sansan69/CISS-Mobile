import 'dart:async';
import 'package:ciss_mobile/core/models/guard_profile.dart';
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
        role == AppRole.guard ? MutableSession.new : FoSession.new,
      ),
      mobileRepositoryProvider.overrideWith(
        (ref) => OriginRepo(ref.watch(testOrigin)),
      ),
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

final testOrigin = StateProvider<String>((ref) => 'https://a.invalid');
final readMarks = <String>[];

class OriginRepo extends repro.Repo {
  OriginRepo(this.origin);
  final String origin;
  @override
  String get dutyApiBaseUrl => origin;
  @override
  Future<void> markNotificationAsRead(String notifId) async {
    readMarks.add('$origin:$notifId');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNotifications() async => [];

  @override
  Future<int> fetchUnreadNotificationCount() async => 0;

  @override
  Future<List<GuardProfileModel>> fetchFieldOfficerGuards({
    String? district,
    bool includeInactive = false,
  }) async => [];
}

class MutableSession extends repro.Session {}

void main() {
  testWidgets(
    'pending origin A event must not migrate to origin B after unlock',
    (t) async {
      readMarks.clear();
      final b = RepeatedBiometrics();
      final c = await setup(t, b);
      c.read(notificationServiceProvider).navigateFromNotification(payload);
      c.read(testOrigin.notifier).state = 'https://b.invalid';
      c.read(regionGraphRevisionProvider.notifier).state++;
      await frames(t);
      b.prompts.last.complete(BiometricAuthOutcome.success);
      await frames(t);
      await t.pump(const Duration(seconds: 2));
      await frames(t);
      expect(find.byType(GuardDutiesScreen, skipOffstage: false), findsNothing);
      expect(readMarks, isEmpty);
    },
  );
  testWidgets('same-origin pending event routes and marks read after unlock', (
    t,
  ) async {
    readMarks.clear();
    final b = RepeatedBiometrics();
    final c = await setup(t, b);
    c.read(notificationServiceProvider).navigateFromNotification(payload);
    b.prompts[0].complete(BiometricAuthOutcome.success);
    await frames(t);
    await t.pump(const Duration(seconds: 2));
    await frames(t);
    expect(find.byType(GuardDutiesScreen, skipOffstage: false), findsOneWidget);
    expect(readMarks, ['https://a.invalid:event-1']);
  });
  for (final trigger in ['relock', 'logout', 'deployment']) {
    testWidgets('FO roster modal reached from willingness closes on $trigger', (
      t,
    ) async {
      final b = RepeatedBiometrics();
      final c = await setup(t, b, role: AppRole.fieldOfficer);
      b.prompts[0].complete(BiometricAuthOutcome.success);
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
      await t.tap(find.byType(CheckboxListTile));
      await frames(t);
      await t.tap(find.text('Review exam roster'));
      await frames(t);
      await frames(t);
      expect(find.text('ASSIGN GUARDS'), findsOneWidget);
      if (trigger == 'relock') {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await t.pump();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else if (trigger == 'logout') {
        c.read(authSessionProvider.notifier).clearSession();
      } else {
        c.read(testOrigin.notifier).state = 'https://b.invalid';
        c.read(regionGraphRevisionProvider.notifier).state++;
      }
      await frames(t);
      await frames(t);
      expect(find.text('ASSIGN GUARDS'), findsNothing);
      expect(find.text('Private FO duty site'), findsNothing);
      expect(c.read(workspaceAccessSessionKeyProvider), isNull);
    });
  }
}
