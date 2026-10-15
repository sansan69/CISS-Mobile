import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Languages the field workforce actually reads. English stays the fallback so
/// every existing screen keeps its current wording.
enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'हिन्दी', 'Hindi'),
  malayalam('ml', 'മലയാളം', 'Malayalam');

  const AppLanguage(this.code, this.label, this.englishLabel);

  final String code;

  /// Endonym shown in the language picker.
  final String label;
  final String englishLabel;

  static AppLanguage fromCode(Object? value) => AppLanguage.values.firstWhere(
    (language) => language.code == value,
    orElse: () => AppLanguage.english,
  );
}

/// Persists the chosen interface language in its own box so the settings schema
/// and its tests stay untouched.
class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController() : super(AppLanguage.english) {
    if (Hive.isBoxOpen(boxName)) {
      state = AppLanguage.fromCode(Hive.box(boxName).get(languageKey));
    }
  }

  static const String boxName = 'app_language';
  static const String languageKey = 'language_code';

  Future<void> init() async {
    await Hive.openBox(boxName);
    state = AppLanguage.fromCode(Hive.box(boxName).get(languageKey));
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).put(languageKey, language.code);
    }
  }
}

final appLanguageControllerProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>(
      (ref) => AppLanguageController(),
    );
