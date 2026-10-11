// test/remote_config_store_test.dart
import 'package:ciss_mobile/core/settings/remote_config.dart';
import 'package:ciss_mobile/core/settings/remote_config_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('rc').path);
  });
  tearDownAll(() async => Hive.close());

  test('round-trips a RemoteConfig per region:role key', () async {
    final store = RemoteConfigStore();
    await store.init(null);
    final key = RemoteConfigStore.keyFor('KL', 'guard');
    await store.write(key, RemoteConfig.fromJson({'version': 3, 'modules': {'loan': true}}));
    final got = store.read(key)!;
    expect(got.version, 3);
    expect(got.modules.isOn('loan', fallback: false), isTrue);
    expect(store.read(RemoteConfigStore.keyFor('KL', 'fieldOfficer')), isNull);
  });
}
