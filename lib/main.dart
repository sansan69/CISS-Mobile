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
import 'core/sync/providers.dart';
import 'core/sync/refresh_controller.dart';
import 'core/region/region_service.dart';
import 'app/theme/theme_mode_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge: required on Android 15+ and best practice for modern Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final container = ProviderContainer();
  final queue = container.read(offlineQueueProvider);
  final cipher = await queue.getEncryptionCipher();

  await Hive.initFlutter();
  await Hive.openBox<Map>(OfflineQueue.boxName, encryptionCipher: cipher);
  await Hive.openBox<Map>(DraftService.boxName); // Non-encrypted for high-frequency drafts
  await container.read(appSettingsControllerProvider.notifier).init(cipher);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // If a region was previously selected, initialize the regional Firebase app
    try {
      final savedRegion = await container.read(regionServiceProvider).getSavedRegion();
      if (savedRegion != null && savedRegion != 'KL') {
        final config = await container.read(regionServiceProvider).fetchRegionConfig(savedRegion);
        if (config != null) {
          await container.read(regionServiceProvider).initRegionalFirebase(config);
          await container.read(regionServiceProvider).saveRegionPreference(savedRegion, region: config);
        }
      }
    } catch (e) {
      debugPrint('Regional Firebase init error: $e');
    }

    // Android 14+ (API 34): startForeground() hard-crashes if POST_NOTIFICATIONS
    // is not granted. Skip background service initialization here on Android — it
    // is initialized from permission_onboarding_screen.dart after the user grants
    // the permission. On subsequent launches (permission already granted) we init
    // here normally. On iOS there is no such restriction.
    final bool canInitTracking = defaultTargetPlatform != TargetPlatform.android
        || await Permission.notification.isGranted;

    if (canInitTracking) {
      await BackgroundTrackingService.initialize();
    }

    container.read(syncServiceProvider).start();
    container.read(refreshControllerProvider).start();
    await container.read(notificationServiceProvider).init().timeout(
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
