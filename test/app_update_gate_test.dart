import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:ciss_mobile/core/settings/remote_config_provider.dart';
import 'package:ciss_mobile/core/update/app_update_gate.dart';
import 'package:ciss_mobile/core/update/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedConfigNotifier extends RemoteConfigNotifier {
  _FixedConfigNotifier(this.config);
  final RemoteConfig config;

  @override
  RemoteConfig build() => config;
}

AndroidUpdateInfo _update({required int minSupported}) => AndroidUpdateInfo(
      latestVersionName: '1.0.99',
      latestVersionCode: 99,
      minimumSupportedVersionCode: minSupported,
      apkUrl: 'https://example.test/app.apk',
      sha256: '',
      sizeBytes: 1,
      releaseNotes: const [],
      mandatory: false,
    );

void main() {
  testWidgets('maintenance mode blocks the app with a dialog', (tester) async {
    final config = RemoteConfig.fromJson(<String, dynamic>{
      'app': <String, dynamic>{'maintenance': true},
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          remoteConfigProvider.overrideWith(() => _FixedConfigNotifier(config)),
        ],
        child: const MaterialApp(
          home: AppUpdateGate(child: Text('HOME')),
        ),
      ),
    );
    await tester.pump(); // let the post-frame check run
    await tester.pumpAndSettle();

    expect(find.text('Under maintenance'), findsOneWidget);
  });

  test('forceUpdate makes an available update mandatory', () {
    final current = AppUpdateCheckResult(
      currentVersionName: '1.0.17',
      currentVersionCode: 17,
      update: _update(minSupported: 1), // not mandatory by version alone
    );

    final defaults = RemoteConfig.defaults();
    expect(updateIsMandatory(current, defaults), isFalse);

    final forced = RemoteConfig.fromJson(<String, dynamic>{
      'app': <String, dynamic>{'forceUpdate': true},
    });
    expect(updateIsMandatory(current, forced), isTrue);
  });
}
