import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/region/region_service.dart';

const String _savedRegionConfigKey = 'ciss_selected_region_config';

const RegionInfo _tamilNadu = RegionInfo(
  code: 'TN',
  name: 'Tamil Nadu',
  apiUrl: 'https://tn.ciss.example.test',
  androidConfig: RegionFirebaseConfig(
    apiKey: 'tn-api-key',
    appId: '1:2:android:3',
    projectId: 'ciss-tn',
    messagingSenderId: '2',
    storageBucket: 'ciss-tn.appspot.com',
  ),
);

void main() {
  group('saved region config (F-23)', () {
    late _MemorySecureStorage storage;

    setUp(() {
      storage = _MemorySecureStorage();
    });

    test('saveRegionPreference persists the full config and reads it back',
        () async {
      final service = _TestRegionService(storage: storage);
      await service.saveRegionPreference('TN', region: _tamilNadu);

      final cached = await service.getSavedRegionConfig();
      expect(cached, isNotNull);
      expect(cached!.code, 'TN');
      expect(cached.apiUrl, 'https://tn.ciss.example.test');
      expect(cached.androidConfig?.projectId, 'ciss-tn');
      expect(cached.androidConfig?.storageBucket, 'ciss-tn.appspot.com');
    });

    test('clearRegionPreference removes the cached config', () async {
      final service = _TestRegionService(storage: storage);
      await service.saveRegionPreference('TN', region: _tamilNadu);
      await service.clearRegionPreference();
      expect(await service.getSavedRegionConfig(), isNull);
    });

    test('remote config is preferred when it is reachable', () async {
      final service = _TestRegionService(
        storage: storage,
        remote: const RegionInfo(
          code: 'TN',
          name: 'Tamil Nadu',
          apiUrl: 'https://rotated.tn.example.test',
        ),
      );
      await service.saveRegionPreference('TN', region: _tamilNadu);

      final resolved = await service.resolveRegionConfig('TN');
      expect(resolved?.apiUrl, 'https://rotated.tn.example.test');
    });

    test('falls back to the cached config when the fetch fails', () async {
      final service = _TestRegionService(storage: storage, remote: null);
      await service.saveRegionPreference('TN', region: _tamilNadu);

      final resolved = await service.resolveRegionConfig('TN');
      expect(resolved, isNotNull);
      expect(resolved!.code, 'TN');
      expect(resolved.apiUrl, 'https://tn.ciss.example.test');
      expect(resolved.androidConfig?.apiKey, 'tn-api-key');
    });

    test('a cached config for another region is not used', () async {
      final service = _TestRegionService(storage: storage, remote: null);
      await service.saveRegionPreference('TN', region: _tamilNadu);

      expect(await service.resolveRegionConfig('KA'), isNull);
    });

    test('missing config fails closed', () async {
      final service = _TestRegionService(storage: storage, remote: null);
      expect(await service.resolveRegionConfig('TN'), isNull);
    });

    test('malformed cached config fails closed instead of crashing', () async {
      storage.values[_savedRegionConfigKey] = '{not json';
      final service = _TestRegionService(storage: storage, remote: null);
      expect(await service.getSavedRegionConfig(), isNull);
      expect(await service.resolveRegionConfig('TN'), isNull);
    });

    test('cached config without an API URL fails closed', () async {
      storage.values[_savedRegionConfigKey] = jsonEncode(<String, dynamic>{
        'code': 'TN',
        'name': 'Tamil Nadu',
        'apiUrl': '   ',
      });
      final service = _TestRegionService(storage: storage, remote: null);
      expect(await service.getSavedRegionConfig(), isNull);
      expect(await service.resolveRegionConfig('TN'), isNull);
    });

    test('cached config without a code fails closed', () async {
      storage.values[_savedRegionConfigKey] = jsonEncode(<String, dynamic>{
        'name': 'Nowhere',
        'apiUrl': 'https://nowhere.example.test',
      });
      final service = _TestRegionService(storage: storage, remote: null);
      expect(await service.getSavedRegionConfig(), isNull);
    });

    test('a failed storage read fails closed', () async {
      storage.failReads = true;
      final service = _TestRegionService(storage: storage, remote: null);
      expect(await service.getSavedRegionConfig(), isNull);
      expect(await service.resolveRegionConfig('TN'), isNull);
    });
  });
}

class _TestRegionService extends RegionService {
  _TestRegionService({required FlutterSecureStorage storage, this.remote})
    : super.test(secureStorage: storage);

  final RegionInfo? remote;

  @override
  Future<RegionInfo?> fetchRegionConfig(String regionCode) async => remote;
}

class _MemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};
  bool failReads = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failReads) throw StateError('secure storage unavailable');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
