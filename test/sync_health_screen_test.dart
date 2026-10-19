import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/features/shared/policy_links_card.dart';
import 'package:ciss_mobile/features/shared/sync_health_card.dart';
import 'package:ciss_mobile/features/shared/sensitive_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new surfaces use readable semantic foregrounds in both themes', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    for (final brightness in Brightness.values) {
      final colors = buildCissTheme(brightness).colorScheme;
      expect(
        contrast(colors.onSurface, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  testWidgets('new policy and sync surfaces translate at 1.8 scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in AppLanguage.values) {
      final strings = AppStrings.forLanguage(language);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppStringsScope(
              strings: strings,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [SyncHealthCard(), PolicyLinksCard()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(strings.label('syncHealth')), findsOneWidget);
      expect(find.text(strings.label('policies')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('health card remains readable at 1.8 scale in both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: const Scaffold(
                body: SingleChildScrollView(child: SyncHealthCard()),
              ),
            ),
          ),
        ),
      );
      expect(find.text('0 pending · 0 need review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'nested sensitive screens enable once and disable after last exit',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('screen_protector'), (
            call,
          ) async {
            calls.add(call.method);
            return true;
          });
      await tester.pumpWidget(
        const MaterialApp(
          home: SensitiveScreen(child: SensitiveScreen(child: Text('private'))),
        ),
      );
      await tester.pump();
      expect(calls, ['preventScreenshotOn']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, ['preventScreenshotOn', 'preventScreenshotOff']);
    },
  );
}
