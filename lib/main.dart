import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/app.dart';
import 'core/cache/hive_read_cache_store.dart';
import 'core/fcm/providers.dart';
import 'core/auth/legacy_biometric_credential_cleanup.dart';
import 'core/location/background_tracking_service.dart';
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
  HiveAesCipher? cipher;
  try {
    cipher = await queue.getEncryptionCipher();
  } catch (error) {
    // Fail closed: without the secure-storage key the queue must stay closed
    // instead of being opened unencrypted. Enqueue then throws a typed error.
    debugPrint(
      'Offline queue disabled: encryption key unavailable '
      '(${error.runtimeType})',
    );
  }

  await Hive.initFlutter();
  if (cipher != null) {
    try {
      await Hive.openBox<Map>(OfflineQueue.boxName, encryptionCipher: cipher);
    } catch (error) {
      debugPrint(
        'Offline queue unavailable (${error.runtimeType}); offline '
        'submissions will fail closed',
      );
    }
    await _openEncryptedReadCache(cipher);
    try {
      await DraftService.openEncrypted(cipher);
    } catch (error) {
      // Drafts are a convenience; never fall back to plaintext.
      debugPrint(
        'Draft storage unavailable (${error.runtimeType}); '
        'drafts disabled for this run',
      );
    }
  } else {
    debugPrint('Secure storage unavailable; drafts disabled for this run');
  }
  await container.read(appSettingsControllerProvider.notifier).init(cipher);
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

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // If a region was previously selected, initialize the regional Firebase app
    try {
      final savedRegion =
          await container.read(regionServiceProvider).getSavedRegion();
      if (savedRegion != null && savedRegion != 'KL') {
        // Prefer the live HQ config; fall back to the persisted config for the
        // same region so a non-Kerala user can cold-start offline. A missing,
        // corrupt or mismatched config still fails closed below.
        final config = await container
            .read(regionServiceProvider)
            .resolveRegionConfig(savedRegion);
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
    // here normally. On iOS there is no such restriction. The web build has no
    // background service at all, so its bootstrap must not attempt one.
    final bool canInitTracking =
        !kIsWeb &&
        (defaultTargetPlatform != TargetPlatform.android ||
            await Permission.notification.isGranted);

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

/// Opens the disposable read cache with the offline queue's AES cipher.
///
/// Upgrading from a build that wrote the cache unencrypted leaves a box that
/// cannot be read with the cipher; because cached payloads are disposable it is
/// deleted and recreated encrypted. Every failure degrades to no persistent
/// cache (the in-memory cache keeps working for the session).
Future<void> _openEncryptedReadCache(HiveAesCipher cipher) async {
  const boxName = HiveReadCacheStore.defaultBoxName;
  try {
    final box = await Hive.openBox<dynamic>(
      boxName,
      encryptionCipher: cipher,
    );
    // A legacy plaintext box can open but throw when its frames are read.
    box.toMap();
    return;
  } catch (error) {
    debugPrint(
      'Read cache needs recreation (${error.runtimeType}); '
      'cached payloads are disposable',
    );
  }
  try {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<dynamic>(boxName).close();
    }
  } catch (_) {
    // Ignore: deleteBoxFromDisk below reports real failures.
  }
  try {
    await Hive.deleteBoxFromDisk(boxName);
  } catch (_) {
    // A missing box is fine.
  }
  try {
    final box = await Hive.openBox<dynamic>(boxName, encryptionCipher: cipher);
    box.toMap();
  } catch (error) {
    debugPrint('Read cache disabled (${error.runtimeType})');
  }
}
