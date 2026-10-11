import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:ciss_mobile/app/router/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('remoteConfigProvider is safe before the store is initialized', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Store box is not open — must fall back to defaults, never throw.
    final config = container.read(remoteConfigProvider);
    expect(config.version, 0);
    expect(config.modules.qrAttendance, isTrue);
  });

  test('routerProvider builds a GoRouter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(routerProvider), isA<GoRouter>());
  });
}
