import 'package:ciss_mobile/app/theme/app_theme.dart';
import 'package:ciss_mobile/core/i18n/app_language.dart';
import 'package:ciss_mobile/core/i18n/app_strings.dart';
import 'package:ciss_mobile/core/location/address_cache.dart';
import 'package:ciss_mobile/core/location/navigate_action.dart';
import 'package:ciss_mobile/features/shared/navigate_button.dart';
import 'package:ciss_mobile/features/shared/policy_webview_screen.dart';
import 'package:ciss_mobile/features/shared/resolved_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final AppStrings english = AppStrings.forLanguage(AppLanguage.english);

class _RecordingLauncher implements NavigationLauncher {
  _RecordingLauncher({this.result = true});

  bool result;
  final List<String> opened = <String>[];

  @override
  Future<bool> open(double latitude, double longitude, {String? label}) async {
    opened.add('$latitude,$longitude');
    return result;
  }
}

class _FakeGeocoder implements ReverseGeocoder {
  _FakeGeocoder(this.address);

  String? address;

  @override
  Future<String?> lookup(double latitude, double longitude) async => address;
}

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: buildCissTheme(Brightness.light),
    home: Scaffold(body: child),
  ),
);

/// A phone-sized surface at 1x, so a tap lands on what the user sees.
void _phoneView(WidgetTester tester, {Size size = const Size(411, 900)}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  group('navigate action', () {
    testWidgets('offers nothing without coordinates', (tester) async {
      _phoneView(tester);
      await tester.pumpWidget(
        _wrap(
          const NavigateAction(latitude: null, longitude: null),
          <Override>[],
        ),
      );
      expect(find.text(english.navigate), findsNothing);
    });

    testWidgets('hands the destination to the launcher once', (tester) async {
      _phoneView(tester);
      final launcher = _RecordingLauncher();
      await tester.pumpWidget(
        _wrap(const NavigateAction(latitude: 9.98, longitude: 76.28), <
          Override
        >[navigationLauncherProvider.overrideWithValue(launcher)]),
      );

      await tester.tap(find.text(english.navigate));
      await tester.pumpAndSettle();

      expect(launcher.opened, <String>['9.98,76.28']);
    });

    testWidgets('says so when no map surface accepted the destination', (
      tester,
    ) async {
      _phoneView(tester);
      final launcher = _RecordingLauncher(result: false);
      await tester.pumpWidget(
        _wrap(const NavigateAction(latitude: 9.98, longitude: 76.28), <
          Override
        >[navigationLauncherProvider.overrideWithValue(launcher)]),
      );

      await tester.tap(find.text(english.navigate));
      await tester.pumpAndSettle();

      expect(find.text(english.navigateUnavailable), findsOneWidget);
    });
  });

  group('resolved address', () {
    testWidgets('shows the address when one resolves', (tester) async {
      _phoneView(tester);
      await tester.pumpWidget(
        _wrap(const ResolvedAddressLine(latitude: 9.98, longitude: 76.28), <
          Override
        >[
          addressResolverProvider.overrideWithValue(
            AddressResolver(
              geocoder: _FakeGeocoder('MG Road, Ernakulam'),
              store: MemoryAddressCacheStore(),
            ),
          ),
        ]),
      );
      // The resolver writes its cache entry before it answers, so the widget
      // settles a beat after the first frame.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('MG Road, Ernakulam'), findsOneWidget);
    });

    testWidgets('renders nothing offline instead of an error', (tester) async {
      _phoneView(tester);
      await tester.pumpWidget(
        _wrap(const ResolvedAddressLine(latitude: 9.98, longitude: 76.28), <
          Override
        >[
          addressResolverProvider.overrideWithValue(
            AddressResolver(
              geocoder: _FakeGeocoder(null),
              store: MemoryAddressCacheStore(),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ResolvedAddressLine), findsOneWidget);
      // Nothing to show, and no error about it.
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('policy reader', () {
    testWidgets('a page that cannot load offers the browser hand-off', (
      tester,
    ) async {
      Uri? launched;
      _phoneView(tester);
      await tester.pumpWidget(
        _wrap(
          PolicyWebViewScreen(
            title: 'Privacy Policy',
            url: 'https://ciss.example/privacy',
            openInBrowser: (uri) async {
              launched = uri;
              return true;
            },
          ),
          <Override>[],
        ),
      );
      // No WebView platform in a widget test, which is exactly the failure
      // path a build without the plugin would take.
      await tester.pumpAndSettle();

      expect(find.text(english.policyUnavailableTitle), findsOneWidget);
      expect(find.text(english.policyOpenInBrowser), findsOneWidget);
      expect(find.text(english.readinessRecheck), findsOneWidget);

      await tester.tap(find.text(english.policyOpenInBrowser));
      await tester.pumpAndSettle();
      expect(launched.toString(), 'https://ciss.example/privacy');
    });

    testWidgets('a bundled page has no browser escape hatch', (tester) async {
      _phoneView(tester);
      await tester.pumpWidget(
        _wrap(
          const PolicyWebViewScreen(
            title: 'Terms of Use',
            assetPath: 'assets/legal/terms.html',
          ),
          <Override>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(english.policyUnavailableTitle), findsOneWidget);
      // Nothing to open in a browser: the page ships inside the app.
      expect(find.text(english.policyOpenInBrowser), findsNothing);
    });
  });
}
