import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

class CissMobileApp extends ConsumerWidget {
  const CissMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appSettingsControllerProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'CISS Workforce',
      debugShowCheckedModeBanner: false,
      theme: buildCissTheme(Brightness.light),
      darkTheme: buildCissTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
