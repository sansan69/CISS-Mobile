import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/permissions/oem_autostart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final strings = AppStrings.forLanguage(AppLanguage.english);

  group('OEM guide mapping', () {
    test('maps each vendor and its sub-brands, case-insensitively', () {
      expect(oemGuideFor('Xiaomi')?.manufacturer, 'xiaomi');
      expect(oemGuideFor('redmi')?.manufacturer, 'xiaomi');
      expect(oemGuideFor('POCO')?.manufacturer, 'xiaomi');
      expect(oemGuideFor('  OPPO ')?.manufacturer, 'oppo');
      expect(oemGuideFor('realme')?.manufacturer, 'oppo');
      expect(oemGuideFor('OnePlus')?.manufacturer, 'oneplus');
      expect(oemGuideFor('vivo')?.manufacturer, 'vivo');
      expect(oemGuideFor('iQOO')?.manufacturer, 'vivo');
      expect(oemGuideFor('HUAWEI')?.manufacturer, 'huawei');
      expect(oemGuideFor('honor')?.manufacturer, 'huawei');
      expect(oemGuideFor('Samsung')?.manufacturer, 'samsung');
    });

    test('falls back to the generic recipe for other vendors', () {
      expect(oemGuideFor('Google'), isNull);
      expect(oemGuideFor(''), isNull);
      expect(oemGuideForOrGeneric('Google').manufacturer, 'generic');
      expect(
        oemGuideForOrGeneric('Nothing Phone').pathKey,
        'readinessOemPathGeneric',
      );
    });

    test('every vendor guide names its own settings component and path', () {
      final components = oemGuides.map((guide) => guide.component).toList();
      expect(components.every((component) => component != null), isTrue);
      expect(components.toSet().length, oemGuides.length);
      expect(
        oemGuides.map((guide) => guide.pathKey).toSet().length,
        oemGuides.length,
      );
      // The generic recipe has no vendor component to open; the caller falls
      // back to the app detail screen.
      expect(genericOemGuide.hasComponent, isFalse);
    });

    test('steps lead with the vendor path and close with shared actions', () {
      final guide = oemGuideFor('Xiaomi')!;
      expect(guide.stepKeys.first, guide.pathKey);
      expect(guide.stepKeys.sublist(1), <String>[
        'readinessOemStepSelect',
        'readinessOemStepUnrestrict',
        'readinessOemStepVerify',
      ]);
    });

    test('every guide step resolves in all three languages', () {
      for (final language in AppLanguage.values) {
        final localised = AppStrings.forLanguage(language);
        expect(localised.readinessOemTitle.trim(), isNotEmpty);
        expect(localised.readinessOemBody.trim(), isNotEmpty);
        expect(localised.readinessOemOpenSettings.trim(), isNotEmpty);
        for (final guide in <OemGuide>[...oemGuides, genericOemGuide]) {
          for (final key in guide.stepKeys) {
            expect(
              localised.label(key).trim(),
              isNotEmpty,
              reason: '$key is missing for ${language.code}',
            );
          }
        }
      }
    });

    test('fills the brand placeholder and keeps unknown ones visible', () {
      expect(
        strings.fill(strings.readinessOemTitle, <String, Object>{
          'brand': 'Xiaomi',
        }),
        'Keep CISS running on Xiaomi',
      );
      expect(
        strings.fill('{ready} of {total} ready', <String, Object>{
          'ready': 2,
          'total': 5,
        }),
        '2 of 5 ready',
      );
      expect(
        strings.fill('{missing}', <String, Object>{'ready': 1}),
        '{missing}',
      );
    });
  });
}
