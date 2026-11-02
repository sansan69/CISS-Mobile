import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';
import '../core/auth/app_lock_overlay.dart';
import '../core/update/app_update_gate.dart';

class CissMobileApp extends ConsumerWidget {
  const CissMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      appSettingsControllerProvider.select((s) => s.themeMode),
    );
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CISS Workforce',
      debugShowCheckedModeBanner: false,
      theme: buildCissTheme(Brightness.light),
      darkTheme: buildCissTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      // The app lock sits above the navigator (and above the update gate) so it
      // covers every pushed route, not just the `/` gate route.
      builder:
          (context, child) => AppLockOverlay(
            child: AppUpdateGate(child: child ?? const SizedBox.shrink()),
          ),
    );
  }
}
