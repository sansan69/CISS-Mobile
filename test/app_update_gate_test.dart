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

  @override
  Future<void> refresh({bool force = false}) async {}
}

/// Config notifier whose state the test can flip to simulate a later server
/// push of `app.maintenance` / `app.forceUpdate` (F-25).
class _MutableConfigNotifier extends RemoteConfigNotifier {
  _MutableConfigNotifier(this.initial);
  final RemoteConfig initial;

  @override
  RemoteConfig build() => initial;

  @override
  Future<void> refresh({bool force = false}) async {}
}

/// Stand-in for the platform update service so the gate never touches the
/// network, platform channels or the region service in widget tests.
class _FakeUpdateService implements AppUpdateService {
  _FakeUpdateService({this.result});

  final AppUpdateCheckResult? result;
  int checkCount = 0;

  @override
  Future<AppUpdateCheckResult?> checkForAndroidUpdate() async {
    checkCount += 1;
    return result;
  }

  @override
  Future<bool> canInstallApk() async => false;

  @override
  Future<void> openInstallSettings() async {}

  @override
  Future<ApkVerification> verifyApk(String localPath) async =>
      const ApkVerification.failed('not under test');

  @override
  Future<InstallResult> installUpdate(String localPath) async =>
      const InstallFailed('not under test');
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

RemoteConfig _config({bool maintenance = false, bool forceUpdate = false}) =>
    RemoteConfig.fromJson(<String, dynamic>{
      'app': <String, dynamic>{
        'maintenance': maintenance,
        'forceUpdate': forceUpdate,
      },
    });

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
        child: const MaterialApp(home: AppUpdateGate(child: Text('HOME'))),
      ),
    );
    await tester.pump(); // let the post-frame check run
    await tester.pumpAndSettle();

    expect(find.text('Under maintenance'), findsOneWidget);
  });

  testWidgets(
    'a maintenance flag that flips after the first frame is honoured',
    (tester) async {
      final container = ProviderContainer(
        overrides: <Override>[
          remoteConfigProvider.overrideWith(
            () => _MutableConfigNotifier(_config()),
          ),
          appUpdateServiceProvider.overrideWithValue(_FakeUpdateService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppUpdateGate(child: Text('HOME'))),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // First frame: no maintenance, the app is usable.
      expect(find.text('Under maintenance'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);

      // The server flips the kill switch while the app is already open.
      container.read(remoteConfigProvider.notifier).state = _config(
        maintenance: true,
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Under maintenance'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget); // still mounted, just blocked

      // And it is torn down again when the window ends.
      container.read(remoteConfigProvider.notifier).state = _config();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Under maintenance'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('a forceUpdate flag flipped mid-session removes "Later"', (
    tester,
  ) async {
    final result = AppUpdateCheckResult(
      currentVersionName: '1.0.17',
      currentVersionCode: 17,
      update: _update(minSupported: 1),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        remoteConfigProvider.overrideWith(
          () => _MutableConfigNotifier(_config()),
        ),
        appUpdateServiceProvider.overrideWithValue(
          _FakeUpdateService(result: result),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppUpdateGate(child: Text('HOME'))),
      ),
    );
    await tester.pump(); // post-frame check
    await tester.pump(); // check future resolves

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    // forceUpdate arriving after the first frame must make the same card
    // blocking without re-opening it.
    container.read(remoteConfigProvider.notifier).state = _config(
      forceUpdate: true,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
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
