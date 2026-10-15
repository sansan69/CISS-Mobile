import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:ciss_mobile/app/router/app_router.dart';
import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/auth/biometric_service.dart';
import 'package:ciss_mobile/core/auth/app_lock_preferences.dart';
import 'package:ciss_mobile/core/fcm/providers.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/features/auth/application/auth_controller.dart';
import 'package:ciss_mobile/features/guard/application/duty_willingness_controller.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_duties_screen.dart';
import 'package:ciss_mobile/features/guard/presentation/screens/guard_profile_screen.dart';
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

class PendingBiometrics implements BiometricService {
  final result = Completer<BiometricAuthOutcome>();
  @override
  Future<BiometricAuthOutcome> authenticateFingerprint({
    required String localizedReason,
  }) => result.future;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('duty notification must wait until biometric app lock unlocks', (
    tester,
  ) async {
    FirebasePlatform.instance = FakeCore();
    final biometrics = PendingBiometrics();
    final container = ProviderContainer(
      overrides: [
        remoteConfigProvider.overrideWith(() => FixedConfig()),
        authSessionProvider.overrideWith(repro.Session.new),
        mobileRepositoryProvider.overrideWithValue(repro.Repo()),
        appLockPreferencesProvider.overrideWith(
          (ref) => AppLockPreferencesNotifier(),
        ),
        biometricServiceProvider.overrideWithValue(biometrics),
        guardProfileProvider.overrideWith(
          (ref) async => throw StateError('no profile'),
        ),
        guardDutiesProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(() {
      container.read(notificationServiceProvider).dispose();
      container.dispose();
    });
    final notifications = container.read(notificationServiceProvider);
    final session = await container.read(authSessionProvider.future);
    container.read(appLockPreferencesProvider.notifier).setFor(session!, true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildCissTheme(Brightness.light),
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(GuardDutiesScreen), findsNothing);
    container.read(routerProvider).go('/guard/duties/exam-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(GuardDutiesScreen), findsNothing);
    notifications.navigateFromNotification({
      'type': 'duty_assigned',
      'recipientUid': 'auth-a',
      'recipientRole': 'guard',
      'assignmentId': 'exam-1',
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(GuardDutiesScreen), findsNothing);
    expect(container.read(workspaceAccessSessionKeyProvider), isNull);

    // Model the existing AuthGate finishing its biometric/onboarding flow;
    // a pending notification may route only after that session is admitted.
    biometrics.result.complete(BiometricAuthOutcome.success);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    container.read(workspaceAccessSessionKeyProvider.notifier).state =
        'guard:auth-a';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(GuardDutiesScreen), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(workspaceAccessSessionKeyProvider), isNull);
    expect(find.byType(GuardDutiesScreen), findsNothing);
    notifications.dispose();
  });
}
