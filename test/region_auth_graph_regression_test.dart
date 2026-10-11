import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ciss_mobile/core/region/region_service.dart';
import 'package:ciss_mobile/features/region/presentation/region_selector_screen.dart';

class _FakeRegionConfigService implements RegionConfigurationService {
  _FakeRegionConfigService(this.config);

  final RegionInfo? config;

  @override
  Future<RegionInfo?> fetchRegionConfig(String regionCode) async => config;
}

class _FakeRegionActivationService implements RegionActivationService {
  _FakeRegionActivationService({this.error});

  final Object? error;
  int calls = 0;

  @override
  Future<void> activateRegion(RegionInfo region) async {
    calls += 1;
    if (error != null) throw error!;
  }
}

void main() {
  const region = RegionInfo(
    code: 'TN',
    name: 'Tamil Nadu',
    apiUrl: 'https://tn.example.test',
  );

  testWidgets(
    'regional activation failure stays on the selector and is shown',
    (tester) async {
      final activation = _FakeRegionActivationService(
        error: StateError('Firebase configuration is incomplete.'),
      );
      final router = GoRouter(
        initialLocation: '/region-select',
        routes: <RouteBase>[
          GoRoute(
            path: '/region-select',
            builder: (_, __) => const RegionSelectorScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('Login')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            availableRegionsProvider.overrideWith(
              (ref) async => <RegionInfo>[region],
            ),
            regionConfigurationServiceProvider.overrideWithValue(
              _FakeRegionConfigService(region),
            ),
            regionActivationServiceProvider.overrideWithValue(activation),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tamil Nadu'));
      await tester.pumpAndSettle();

      expect(activation.calls, 1);
      expect(
        find.textContaining('Failed to initialize region'),
        findsOneWidget,
      );
      expect(router.routeInformationProvider.value.uri.path, '/region-select');
    },
  );

  test(
    'activation provider can be overridden without touching active auth',
    () async {
      final activation = _FakeRegionActivationService();
      final container = ProviderContainer(
        overrides: <Override>[
          regionActivationServiceProvider.overrideWithValue(activation),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(regionActivationServiceProvider)
          .activateRegion(region);

      expect(activation.calls, 1);
    },
  );
}
