import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/haptics.dart';
import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_strings.dart';

/// Interface-language picker. The same shape as CISS-AMS `language_screen.dart`
/// but limited to the languages this workforce reads.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final selected = ref.watch(appLanguageControllerProvider);
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(title: Text(strings.language)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            Text(
              strings.languageSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.inkMuted),
            ),
            const SizedBox(height: 12),
            for (final language in AppLanguage.values)
              RadioListTile<AppLanguage>(
                value: language,
                groupValue: selected,
                activeColor: tokens.primary,
                title: Text(language.label),
                subtitle: language == AppLanguage.english
                    ? null
                    : Text(language.englishLabel),
                onChanged: (value) {
                  if (value == null || value == selected) return;
                  Haptics.selection();
                  ref.read(appLanguageControllerProvider.notifier).select(value);
                },
              ),
          ],
        ),
      ),
    );
  }
}
