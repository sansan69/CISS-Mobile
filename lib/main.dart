import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/app.dart';
import 'core/fcm/providers.dart';
import 'core/i18n/app_language.dart';
import 'core/auth/legacy_biometric_credential_cleanup.dart';
import 'core/location/background_tracking_service.dart';
import 'core/location/address_cache.dart';
import 'core/device/device_identity.dart';
import 'core/permissions/device_readiness.dart';
import 'core/offline/offline_queue.dart';
import 'core/offline/draft_service.dart';
import 'core/sync/providers.dart';
import 'core/sync/refresh_controller.dart';
import 'core/region/region_service.dart';
import 'core/settings/remote_config_provider.dart';
import 'app/theme/theme_mode_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Crash reporting ───────────────────────────────────────────────────────
  FlutterError.onError = (details) {
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {
      FlutterError.dumpErrorToConsole(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      debugPrint('Unhandled platform error before Crashlytics init: $error');
    }
    return true;
  };

  // Edge-to-edge: required on Android 15+ and best practice for modern Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final container = ProviderContainer();
  await container
      .read(legacyBiometricCredentialCleanupProvider)
      .purgeLegacyCredentials();
  final queue = container.read(offlineQueueProvider);
  final cipher = await queue.getEncryptionCipher();

  await Hive.initFlutter();
  await Hive.openBox<Map>(OfflineQueue.boxName, encryptionCipher: cipher);
  await Hive.openBox<Map>(
    DraftService.boxName,
  ); // Non-encrypted for high-frequency drafts
  await container.read(appSettingsControllerProvider.notifier).init(cipher);
  // Interface language store: a corrupt or missing box must not blank the app.
  try {
    await container.read(appLanguageControllerProvider.notifier).init();
  } catch (e) {
    debugPrint('AppLanguage init failed — falling back to English: $e');
  }
  // These new stores must never fail-closed: a corrupt or cipher-mismatched
  // box would otherwise throw before runApp and blank the screen. Each init is
  // isolated so a failure falls back to defaults / a no-op buffer.
  try {
    await container.read(remoteConfigStoreProvider).init(cipher);
  } catch (e) {
    debugPrint('RemoteConfigStore init failed — falling back to defaults: $e');
  }
  try {
    await container.read(trackingBufferProvider).init();
  } catch (e) {
    debugPrint('TrackingBuffer init failed — offline buffering disabled: $e');
  }
  // Device-readiness cache: the readiness banner renders from this snapshot so
  // showing it never issues a permission read.
  try {
    await container.read(readinessCacheProvider.notifier).init();
  } catch (e) {
    debugPrint('ReadinessCache init failed — banner stays hidden: $e');
  }
  // Reverse-geocode cache: a corrupt box only costs an extra lookup.
  try {
    await AddressResolver().init();
  } catch (e) {
    debugPrint('Address cache init failed — addresses stay unresolved: $e');
  }
  // Device identity: without it, writes simply omit the handset header.
  try {
    await container.read(deviceIdentityProvider).init();
  } catch (e) {
    debugPrint('Device identity init failed — punches omit the device id: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // If a region was previously selected, initialize the regional Firebase app
    try {
      final savedRegion =
          await container.read(regionServiceProvider).getSavedRegion();
      if (savedRegion != null && savedRegion != 'KL') {
        final config = await container
            .read(regionServiceProvider)
            .fetchRegionConfig(savedRegion);
        if (config == null) {
          throw StateError('Saved regional configuration is unavailable.');
        }
        await container
            .read(regionActivationServiceProvider)
            .activateRegion(config);
      }
    } catch (e) {
      debugPrint('Regional Firebase init error: $e');
    }

    // Android 14+ (API 34): startForeground() hard-crashes if POST_NOTIFICATIONS
    // is not granted. Skip background service initialization here on Android — it
    // is initialized from permission_onboarding_screen.dart after the user grants
    // the permission. On subsequent launches (permission already granted) we init
    // here normally. On iOS there is no such restriction.
    final bool canInitTracking =
        defaultTargetPlatform != TargetPlatform.android ||
        await Permission.notification.isGranted;

    if (canInitTracking) {
      await BackgroundTrackingService.initialize();
    }

    container.read(syncServiceProvider).start();
    container.read(refreshControllerProvider).start();
    await container
        .read(notificationServiceProvider)
        .init()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => debugPrint('Notification initialization timed out'),
        );
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CissMobileApp(),
    ),
  );
}
