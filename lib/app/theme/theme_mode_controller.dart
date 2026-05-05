import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppSettingsState {
  const AppSettingsState({
    required this.themeMode,
    required this.biometricsEnabled,
  });

  final ThemeMode themeMode;
  final bool biometricsEnabled;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    bool? biometricsEnabled,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController()
      : super(const AppSettingsState(
          themeMode: ThemeMode.system,
          biometricsEnabled: false,
        )) {
    if (Hive.isBoxOpen(boxName)) {
      state = _readSettings();
    }
  }

  static const String boxName = 'app_settings';
  static const String themeKey = 'theme_mode';
  static const String biometricsKey = 'biometrics_enabled';

  AppSettingsState _readSettings() {
    final box = Hive.box(boxName);
    final themeValue = box.get(themeKey);
    final biometricsValue = box.get(biometricsKey, defaultValue: false);
    
    return AppSettingsState(
      themeMode: _decodeTheme(themeValue),
      biometricsEnabled: biometricsValue as bool,
    );
  }

  static ThemeMode _decodeTheme(Object? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).put(themeKey, _encodeTheme(mode));
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    state = state.copyWith(biometricsEnabled: enabled);
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).put(biometricsKey, enabled);
    }
  }

  Future<void> init(HiveAesCipher? cipher) async {
    await Hive.openBox(boxName, encryptionCipher: cipher);
    state = _readSettings();
  }

  static String _encodeTheme(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

final StateNotifierProvider<AppSettingsController, AppSettingsState>
    appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>(
  (Ref ref) => AppSettingsController(),
);
