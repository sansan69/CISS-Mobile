import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/app/theme/app_tokens.dart';
import 'package:ciss_mobile/shared/widgets/modern_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/guard_redesign_fixtures.dart';

void main() {
  setUpAll(loadInterFont);

  for (final brightness in Brightness.values) {
    testWidgets(
      'shared FO hero keeps identity readable beside utilities in $brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCissTheme(brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(1.8),
              ),
              child: Scaffold(
                body: ListView(
                  children: <Widget>[
                    ModernHero(
                      eyebrow: 'Field Officer',
                      title:
                          'Good morning, Alexandria Rajalakshmi Krishnamurthy',
                      subtitle:
                          'Thiruvananthapuram • Kollam • Pathanamthitta extended districts',
                      avatarText: 'AR',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final title = tester.widget<Text>(find.textContaining('Good morning'));
        expect(title.maxLines, 2);
        expect(
          tester.getSize(find.textContaining('Good morning')).width,
          greaterThan(160),
        );
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.text('AR'), findsOneWidget);
        final fill =
            CissThemeTokens.of(tester.element(find.byType(ModernHero))).primary;
        for (final finder in <Finder>[
          find.textContaining('Good morning'),
          find.text('Field Officer'),
          find.textContaining('Thiruvananthapuram'),
          find.text('AR'),
        ]) {
          final foreground = tester.widget<Text>(finder).style!.color!;
          final actual = Color.alphaBlend(foreground, fill);
          final lighter =
              actual.computeLuminance() > fill.computeLuminance()
                  ? actual.computeLuminance()
                  : fill.computeLuminance();
          final darker =
              actual.computeLuminance() < fill.computeLuminance()
                  ? actual.computeLuminance()
                  : fill.computeLuminance();
          expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));
        }
      },
    );
  }

  // Device QA at 1.8 text: the hero subtitle needs more than the two lines it
  // gets at 1.0, so it was cut off ("Scan the duty QR at you…").
  testWidgets('hero subtitle is not ellipsized at 1.8 text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCissTheme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: ModernHero(
              eyebrow: 'Field Officer',
              title: 'Good morning',
              subtitle: 'Thiruvananthapuram • Kollam • Pathanamthitta',
              avatarText: 'AR',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expectRenderedInFull(tester, find.textContaining('Thiruvananthapuram'));
  });
}
