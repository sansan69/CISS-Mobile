import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(_readInitialMode());

  static const String boxName = 'app_settings';
  static const String key = 'theme_mode';

  static ThemeMode _readInitialMode() {
    if (!Hive.isBoxOpen(boxName)) {
      return ThemeMode.system;
    }
    final value = Hive.box(boxName).get(key);
    return _decode(value);
  }

  static ThemeMode _decode(Object? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).put(key, _encode(mode));
    }
  }

  Future<void> init(HiveAesCipher? cipher) async {
    await Hive.openBox(boxName, encryptionCipher: cipher);
    state = _readInitialMode();
  }

  static String _encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

final StateNotifierProvider<ThemeModeController, ThemeMode>
    themeModeControllerProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (Ref ref) => ThemeModeController(),
);
