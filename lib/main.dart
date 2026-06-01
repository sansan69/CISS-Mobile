import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/app.dart';
import 'core/fcm/providers.dart';
import 'core/location/background_tracking_service.dart';
import 'core/offline/offline_queue.dart';
import 'core/offline/draft_service.dart';
import 'core/offline/local_report_store.dart';
import 'core/sync/providers.dart';
import 'core/sync/refresh_controller.dart';
import 'app/theme/theme_mode_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge: required on Android 15+ and best practice for modern Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final container = ProviderContainer();

  // ── Phase 1: Storage (must complete before anything that reads/writes) ──
  final queue = container.read(offlineQueueProvider);
  final cipher = await queue.getEncryptionCipher();

  await Hive.initFlutter();
  // Open both boxes in parallel
  await Future.wait([
    Hive.openBox<Map>(OfflineQueue.boxName, encryptionCipher: cipher),
    Hive.openBox<Map>(LocalReportStore.boxName, encryptionCipher: cipher),
  ]);
  await DraftService.init(); // Encrypted box, separate cipher.
  await container.read(appSettingsControllerProvider.notifier).init(cipher);

  // ── Phase 2: Fire all remaining init in parallel ──────────────────────────
  await Future.wait([
    // 2a. Firebase init
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      // After Firebase is ready, spawn non-blocking background init
      _spawnBackgroundInit(container);
      return true;
    }).catchError((e) {
      debugPrint('Firebase init error: $e');
      return false;
    }),

    // 2b. Pre-warm permissions check (Android notification check is fast)
    _checkNotificationPermission(),
  ]);

  // 2a succeeds or not — we still launch the app
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CissMobileApp(),
    ),
  );
}

/// Fast non-blocking check for notification permission.
Future<bool> _checkNotificationPermission() async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await Permission.notification.isGranted;
  } catch (_) {
    return false;
  }
}

/// Non-blocking background initialization: runs after the app is already
/// visible so the user never sees a blank screen.
void _spawnBackgroundInit(ProviderContainer container) {
  // Tracking service init (needs notification permission on Android)
  Permission.notification.isGranted.then((granted) {
    final canInit = defaultTargetPlatform != TargetPlatform.android || granted;
    if (canInit) {
      BackgroundTrackingService.initialize();
    }
  });

  // Sync & refresh — started immediately, they don't block the UI
  container.read(syncServiceProvider).start();
  container.read(refreshControllerProvider).start();

  // FCM Notifications — with timeout to avoid hanging
  container.read(notificationServiceProvider).init().timeout(
    const Duration(seconds: 5),
    onTimeout: () => debugPrint('Notification init timed out'),
  );
}
